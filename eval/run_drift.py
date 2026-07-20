#!/usr/bin/env python3
import json, subprocess, sys, re, os, argparse
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = open(os.path.join(HERE, "prompts/content-drift.txt")).read()

def split_sections(text, nchunks):
    lines = text.split("\n")
    # chunk by H2 boundaries, then coalesce into ~nchunks groups of whole sections
    idxs = [i for i,l in enumerate(lines) if l.startswith("## ")]
    if not idxs:
        return [text]
    segs = []
    bounds = idxs + [len(lines)]
    # keep any preamble with the first section
    start = 0
    sections = []
    for b in idxs:
        pass
    # build section slices
    slices = []
    prev = 0
    for i, b in enumerate(idxs):
        if i == 0:
            prev = 0
        slices.append((prev, b))
        prev = b
    slices.append((prev, len(lines)))
    # first slice is preamble+nothing; drop empty
    secs = ["\n".join(lines[a:b]) for a,b in slices if b> a]
    # coalesce into nchunks groups
    if nchunks <= 1 or len(secs) <= nchunks:
        return secs
    per = (len(secs)+nchunks-1)//nchunks
    return ["\n".join(secs[i:i+per]) for i in range(0, len(secs), per)]

def call_claude(cwd, doc_text, doc_name):
    prompt = TEMPLATE + f"\n(file: {doc_name})\n" + doc_text + "\n--- END DOCUMENTATION ---\n"
    p = subprocess.run(
        ["claude","-p",prompt,"--dangerously-skip-permissions","--output-format","json","--model","claude-sonnet-5"],
        cwd=cwd, capture_output=True, text=True, timeout=400, stdin=subprocess.DEVNULL)
    if os.environ.get("DRIFT_DEBUG"):
        import sys as _s
        _s.stderr.write(f"[dbg] rc={p.returncode} stdout_len={len(p.stdout)} stderr={p.stderr[:200]!r}\n")
        _s.stderr.write("[dbg] stdout_head=" + p.stdout[:300] + "\n")
    try:
        outer = json.loads(p.stdout)
        result = outer.get("result","")
    except Exception:
        result = p.stdout
    m = re.search(r'\{.*\}', result, re.S)
    if not m: return []
    try:
        return json.loads(m.group(0)).get("findings",[])
    except Exception:
        return []

def one_run(fixture, mode, nchunks):
    doc = os.path.join(fixture, "README.md")
    text = open(doc).read()
    segs = [text] if mode=="whole" else split_sections(text, nchunks)
    findings = []
    for s in segs:
        findings += call_claude(fixture, s, "README.md")
    return findings

def score(findings, expected):
    tokmap = {d["id"]:(str(d["tok"][0]).lower(), str(d["tok"][1]).lower()) for d in expected["planted_drift"]}
    blob = [ " ".join(str(v) for v in f.values()).lower() for f in findings ]
    found = {}
    for d in expected["planted_drift"]:
        a,b = tokmap[d["id"]]
        found[d["id"]] = any(a in t and b in t for t in blob)
    matched_any = sum(1 for t in blob if any(a in t and b in t for a,b in tokmap.values()))
    fp = len(blob) - matched_any
    return found, fp, len(blob)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fixture", required=True)
    ap.add_argument("--mode", choices=["whole","chunk"], required=True)
    ap.add_argument("--runs", type=int, default=4)
    ap.add_argument("--chunks", type=int, default=4)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    expected = json.load(open(os.path.join(a.fixture,"expected.json")))
    with ThreadPoolExecutor(max_workers=min(3,a.runs)) as ex:
        runs = list(ex.map(lambda _: one_run(a.fixture, a.mode, a.chunks), range(a.runs)))
    rows = []
    for r in runs:
        found, fp, n = score(r, expected)
        rows.append({"found":found,"fp":fp,"n_findings":n})
    # aggregate
    ids = [d["id"] for d in expected["planted_drift"]]
    recall_per = {i: sum(1 for row in rows if row["found"][i])/len(rows) for i in ids}
    all_found_sets = [tuple(sorted(i for i in ids if row["found"][i])) for row in rows]
    consistent = len(set(all_found_sets))==1
    summary = {"mode":a.mode,"runs":a.runs,"recall_per_drift":recall_per,
               "mean_recall":sum(recall_per.values())/len(ids),
               "consistent_across_runs":consistent,
               "found_sets":all_found_sets,
               "mean_fp":sum(row["fp"] for row in rows)/len(rows),
               "detail":rows}
    json.dump(summary, open(a.out,"w"), indent=2)
    print(json.dumps({k:summary[k] for k in ["mode","recall_per_drift","mean_recall","consistent_across_runs","mean_fp"]}, indent=2))

if __name__=="__main__": main()
