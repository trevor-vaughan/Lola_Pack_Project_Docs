import json, subprocess, sys, re, os
from concurrent.futures import ThreadPoolExecutor
HERE=os.path.dirname(os.path.abspath(__file__))
BASE=open(os.path.join(HERE,"prompts/cold-read.txt")).read()
GROUND=("GROUNDING: this document is a first-time-user QUICKSTART for the Sprocket "
        "CLI; after reading, a brand-new user should be able to install it and run "
        "their first sync. Read strictly as that audience.\n\n")
def call(cwd, text, grounded):
    prompt=(GROUND if grounded else "")+BASE+text+"\n--- END ---\n"
    for _ in range(3):
        p=subprocess.run(["claude","-p",prompt,"--dangerously-skip-permissions","--output-format","json","--model","claude-sonnet-5"],
            cwd=cwd,capture_output=True,text=True,timeout=300,stdin=subprocess.DEVNULL)
        try:
            o=json.loads(p.stdout)
            if o.get("subtype")=="success" and not o.get("is_error"):
                m=re.search(r'\{.*\}',o.get("result",""),re.S)
                if m: return json.loads(m.group(0)).get("issues",[])
        except Exception: pass
    return None
def matches(issue, tid):
    t=" ".join(str(v) for v in issue.values()).lower()
    if tid=="missing-step":  return "step 3" in t or ("step" in t and "3" in t)
    if tid=="jargon-widget": return "widget" in t and ("defin" in t or "undefined-term" in t or "jargon" in t or "never" in t)
    if tid=="dangling-ref":  return "performance" in t
    if tid=="prose-example-contradiction": return "8080" in t and "9090" in t
    if tid=="terminology-drift": return "profile" in t and "config" in t
    return False
def main():
    fix=sys.argv[1]; grounded=sys.argv[2]=="grounded"; K=int(sys.argv[3])
    exp=json.load(open(os.path.join(fix,"expected.json")))
    text=open(os.path.join(fix,"DOC.md")).read()
    with ThreadPoolExecutor(max_workers=3) as ex:
        runs=list(ex.map(lambda _: call(fix,text,grounded), range(K)))
    runs=[r for r in runs if r is not None]
    tids=[p["id"] for p in exp["planted"]]
    recall={t: sum(1 for r in runs if any(matches(i,t) for i in r))/len(runs) for t in tids}
    # spurious per run = issues matching no planted trap
    spur=[sum(1 for i in r if not any(matches(i,t) for t in tids)) for r in runs]
    # intersection: traps found in >= ceil(K/2) runs
    thr=(len(runs)+1)//2
    robust=[t for t in tids if sum(1 for r in runs if any(matches(i,t) for i in r))>=thr]
    print(json.dumps({"mode":"grounded" if grounded else "ungrounded","runs":len(runs),
        "recall_per_trap":recall,"mean_recall":sum(recall.values())/len(tids),
        "mean_spurious_per_run":sum(spur)/len(runs),"robust_traps":len(robust),"of":len(tids)},indent=1))
main()
