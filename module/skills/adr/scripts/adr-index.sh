#!/usr/bin/env bash
set -euo pipefail

# Regenerates the ADR index at <adr-dir>/index.md.
# Usage: adr-index.sh <adr-dir>

dir="${1:-}"
if [ -z "$dir" ] || [ ! -d "$dir" ]; then
  echo "usage: adr-index.sh <adr-dir>" >&2
  exit 2
fi

out="$dir/index.md"

read_field() {
  local file="$1" field="$2"
  awk -v key="$field:" '
    /^---/ { if (in_fm) exit; in_fm=1; next }
    in_fm {
      if ($1 == key) {
        sub(/^[^:]+:[[:space:]]*/, "")
        print
        exit
      }
    }
  ' "$file"
}

read_title() {
  local file="$1"
  awk '
    /^---/ { if (in_fm) { in_fm=0; next }; in_fm=1; next }
    !in_fm && /^# / {
      sub(/^# /, "")
      print
      exit
    }
  ' "$file"
}

shopt -s nullglob
adr_glob=("$dir"/[0-9][0-9][0-9][0-9]-*.md)
shopt -u nullglob
mapfile -t files < <(printf "%s\n" "${adr_glob[@]}" | sort)

if [ "${#adr_glob[@]}" -eq 0 ]; then
  cat > "$out" <<'INDEX_EOF'
# Architectural Decision Records

No ADRs yet. Use /adr-new to create one.
INDEX_EOF
  exit 0
fi

{
  echo "# Architectural Decision Records"
  echo ""
  echo "| ID | Title | Status | Date |"
  echo "|----|-------|--------|------|"
  for f in "${files[@]}"; do
    base=$(basename "$f")
    id="${base:0:4}"
    title=$(read_title "$f")
    [ -z "$title" ] && title="(no title)"
    status=$(read_field "$f" status)
    [ -z "$status" ] && status="unknown"
    date=$(read_field "$f" date)
    [ -z "$date" ] && date="unknown"
    echo "| [$id]($base) | $title | $status | $date |"
  done
} > "$out"
