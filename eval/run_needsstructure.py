import json, subprocess, re, os, sys
from concurrent.futures import ThreadPoolExecutor
HERE=os.path.dirname(os.path.abspath(__file__))
T=open(os.path.join(HERE,"prompts/needs-structure.txt")).read()
def call(text):
    prompt=T+text+"\n--- END ---\n"
    for _ in range(3):
        p=subprocess.run(["claude","-p",prompt,"--dangerously-skip-permissions","--output-format","json","--model","claude-sonnet-5"],
            capture_output=True,text=True,timeout=300,stdin=subprocess.DEVNULL)
        try:
            o=json.loads(p.stdout)
            if o.get("subtype")=="success" and not o.get("is_error"):
                m=re.search(r'\{.*\}',o.get("result",""),re.S)
                if m: return json.loads(m.group(0)).get("needs_structure",[])
        except Exception: pass
    return None
def run(fix,K=5):
    exp=json.load(open(os.path.join(HERE,"fixtures",fix,"expected.json")))
    text=open(os.path.join(HERE,"fixtures",fix,"DOC.md")).read()
    with ThreadPoolExecutor(max_workers=3) as ex:
        res=[r for r in ex.map(lambda _: call(text), range(K)) if r is not None]
    flagged=[len(r)>0 for r in res]
    want=exp["expect_flag"]
    correct=sum(1 for f in flagged if f==want)
    tag="RECALL" if want else "ANTI-NAG"
    print(f"[{tag:8}] {fix:28} expect_flag={want!s:5} flagged={flagged} correct={correct}/{len(res)}")
    return correct,len(res),want
if __name__=="__main__":
    fixtures=sys.argv[1:] or ["needs-structure-dense","needs-structure-readme",
        "needs-structure-clean","needs-structure-reference","needs-structure-short"]
    tot=ok=0
    for f in fixtures:
        c,n,_=run(f); tot+=n; ok+=c
    print(f"\nTOTAL {ok}/{tot}")
