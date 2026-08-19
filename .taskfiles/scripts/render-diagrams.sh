#!/usr/bin/env bash
# Render every .mmd file under $1 to PNG on both light and dark backgrounds,
# writing outputs and a manifest under $2. Used by the test:diagrams task.
set -euo pipefail

SRC="${1:?usage: render-diagrams.sh <src-dir> <out-dir> [css-file]}"
OUT="${2:?usage: render-diagrams.sh <src-dir> <out-dir> [css-file]}"
CSS="${3:-}"  # optional --cssFile path; pass the skill's er-overrides.css

if ! command -v mmdc >/dev/null 2>&1; then
  echo "mmdc not found on PATH — install @mermaid-js/mermaid-cli" >&2
  exit 2
fi

CSS_ARG=()
if [[ -n "$CSS" ]]; then
  if [[ ! -f "$CSS" ]]; then
    echo "css file not found: $CSS" >&2
    exit 2
  fi
  CSS_ARG=(--cssFile "$CSS")
fi

mkdir -p "$OUT"
MANIFEST="$OUT/manifest.txt"
: > "$MANIFEST"

# Some mermaid types (e.g. architecture-beta) need extra icon packs that the
# CLI lazy-loads via Puppeteer; suppress their warnings but capture exit codes.
shopt -s nullglob
fixtures=("$SRC"/*.mmd)
if [[ ${#fixtures[@]} -eq 0 ]]; then
  echo "no .mmd fixtures found under $SRC" >&2
  exit 2
fi

ok=0
fail=0
for fixture in "${fixtures[@]}"; do
  name="$(basename "${fixture%.mmd}")"

  for bg_label in light dark; do
    case "$bg_label" in
      light) bg="white" ;;
      dark)  bg="#1e1e1e" ;;
    esac
    out_png="$OUT/$name.$bg_label.png"
    log="$OUT/$name.$bg_label.log"
    if mmdc -i "$fixture" -o "$out_png" -b "$bg" "${CSS_ARG[@]}" --quiet >"$log" 2>&1; then
      printf 'OK   %-50s %s\n' "$name.$bg_label.png" "(bg=$bg)" | tee -a "$MANIFEST"
      ok=$((ok + 1))
    else
      printf 'FAIL %-50s %s\n' "$name.$bg_label.png" "(see $name.$bg_label.log)" | tee -a "$MANIFEST"
      fail=$((fail + 1))
    fi
  done
done

echo "---" | tee -a "$MANIFEST"
printf 'rendered: %d  failed: %d\n' "$ok" "$fail" | tee -a "$MANIFEST"

# Non-fatal exit: we want a report of WHICH types render and which don't,
# not a single hard failure. The Taskfile target prints the manifest and
# the caller can decide based on the counts.
exit 0
