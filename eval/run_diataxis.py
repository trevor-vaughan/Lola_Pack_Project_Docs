import json, subprocess, sys, re, os
from concurrent.futures import ThreadPoolExecutor
HERE=os.path.dirname(os.path.abspath(__file__))
T=open(os.path.join(HERE,"prompts/diataxis.txt")).read()
def call(text):
    prompt=T+text+"\n--- END ---\n"
    for _ in range(3):
        p=subprocess.run(["claude","-p",prompt,"--dangerously-skip-permissions","--output-format","json","--model","claude-sonnet-5"],
            capture_output=True,text=True,timeout=300,stdin=subprocess.DEVNULL)
        try:
            o=json.loads(p.stdout)
            if o.get("subtype")=="success" and not o.get("is_error"):
                m=re.search(r'\{.*\}',o.get("result",""),re.S)
                if m: return json.loads(m.group(0))
        except Exception: pass
    return None
def run(fix,K):
    exp=json.load(open(os.path.join(HERE,"fixtures",fix,"expected.json")))
    text=open(os.path.join(HERE,"fixtures",fix,"DOC.md")).read()
    with ThreadPoolExecutor(max_workers=3) as ex:
        res=[r for r in ex.map(lambda _: call(text), range(K)) if r]
    modes=[r.get("primary_mode") for r in res]
    mix=[bool(r.get("mode_mixing")) for r in res]
    exp_mix=exp["expect_mode_mixing"]
    correct=sum(1 for m in mix if m==exp_mix)
    print(f"{fix:22} expect_mix={exp_mix!s:5} | modes={modes} | mixing={mix} | correct={correct}/{len(res)}")
for fix in ["diataxis-mixed","diataxis-clean","diataxis-landing"]:
    run(fix,5)
