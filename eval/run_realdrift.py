import json, subprocess, re, os
from concurrent.futures import ThreadPoolExecutor
HERE=os.path.dirname(os.path.abspath(__file__))
FIX=os.path.join(HERE,"fixtures/contradiction-trap")
T=open(os.path.join(HERE,"prompts/content-drift.txt")).read()
DOC=open(os.path.join(FIX,"doc.md")).read()
def call():
    prompt=T+"\n(file: doc.md)\n"+DOC+"\n--- END DOCUMENTATION ---\n"
    for _ in range(3):
        p=subprocess.run(["claude","-p",prompt,"--dangerously-skip-permissions","--output-format","json","--model","claude-sonnet-5"],
            cwd=FIX,capture_output=True,text=True,timeout=250,stdin=subprocess.DEVNULL)
        try:
            o=json.loads(p.stdout)
            if o.get("subtype")=="success" and not o.get("is_error"):
                m=re.search(r'\{.*\}',o.get("result",""),re.S)
                if m: return json.loads(m.group(0)).get("findings",[])
        except Exception: pass
    return None
K=6
with ThreadPoolExecutor(max_workers=3) as ex:
    runs=[r for r in ex.map(lambda _: call(), range(K)) if r is not None]
overframe=0; other=0; empty=0
for f in runs:
    blob=json.dumps(f).lower()
    if not f: empty+=1
    elif ("contradict" in blob or "reference.md" in blob) and ("install" in blob or "uninstall" in blob):
        overframe+=1  # strayed into cross-doc contradiction with the install rule
    else: other+=1
    print("  run findings:", [ (x.get('claim','?')[:30], x.get('code_says','')[:30]) for x in f] or "[]")
print(f"content-drift on trap: runs={len(runs)} over-framed-contradiction={overframe} other={other}")
