import json, subprocess, re, os, sys
from concurrent.futures import ThreadPoolExecutor
HERE=os.path.dirname(os.path.abspath(__file__))
DOCS=open(os.path.join(HERE,"fixtures/contradiction-trap/doc.md")).read()+"\n\n=== reference.md ===\n"+open(os.path.join(HERE,"fixtures/contradiction-trap/reference.md")).read()
def call(promptfile):
    T=open(os.path.join(HERE,"prompts",promptfile)).read()
    prompt=T+DOCS+"\n--- END ---\n"
    for _ in range(3):
        p=subprocess.run(["claude","-p",prompt,"--dangerously-skip-permissions","--output-format","json","--model","claude-sonnet-5"],
            capture_output=True,text=True,timeout=200,stdin=subprocess.DEVNULL)
        try:
            o=json.loads(p.stdout)
            if o.get("subtype")=="success" and not o.get("is_error"):
                m=re.search(r'\{.*\}',o.get("result",""),re.S)
                if m: return json.loads(m.group(0)).get("findings",[])
        except Exception: pass
    return None
def classify(promptfile,K=5):
    with ThreadPoolExecutor(max_workers=3) as ex:
        runs=[r for r in ex.map(lambda _: call(promptfile), range(K)) if r is not None]
    over=0; correct=0; missed=0
    for f in runs:
        labels=[x.get("label","") for x in f]
        text=json.dumps(f).lower()
        touches=("linter" in text or "job-runner" in text or "job runner" in text or "step 2" in text or "included" in text)
        if not touches: missed+=1
        elif "contradiction" in labels: over+=1     # over-framed it as a contradiction
        else: correct+=1                            # flagged the real issue, not as contradiction
    print(f"{promptfile:26} runs={len(runs)} | over-framed(contradiction)={over} correct(unsupported/other)={correct} missed={missed}")
classify("consistency-base.txt")
classify("consistency-guard.txt")
