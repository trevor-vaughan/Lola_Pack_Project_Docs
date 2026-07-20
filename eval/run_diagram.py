import json, subprocess, sys, re, os
from concurrent.futures import ThreadPoolExecutor
HERE=os.path.dirname(os.path.abspath(__file__))
T=open(os.path.join(HERE,"prompts/diagram.txt")).read()
def call(cwd, text):
    prompt=T+text+"\n--- END ---\n"
    for _ in range(3):
        p=subprocess.run(["claude","-p",prompt,"--dangerously-skip-permissions","--output-format","json","--model","claude-sonnet-5"],
            cwd=cwd,capture_output=True,text=True,timeout=300,stdin=subprocess.DEVNULL)
        try:
            o=json.loads(p.stdout)
            if o.get("subtype")=="success" and not o.get("is_error"):
                m=re.search(r'\{.*\}',o.get("result",""),re.S)
                if m: return json.loads(m.group(0))
        except Exception: pass
    return None
fix=sys.argv[1]; K=int(sys.argv[2])
text=open(os.path.join(fix,"DOC.md")).read()
with ThreadPoolExecutor(max_workers=3) as ex:
    res=list(ex.map(lambda _: call(fix,text), range(K)))
vals=[r.get("missing_diagram") if r else None for r in res]
print(fix, "->", vals)
