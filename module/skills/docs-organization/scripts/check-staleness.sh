#!/usr/bin/env bash
set -euo pipefail

# Emits staleness findings as JSON on stdout.
# Compares last-modified commits between README.md / docs/ and likely
# source paths (src/, lib/, cmd/, app/, internal/, pkg/).
# A doc is stale if its last commit is older than the latest source commit.

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo '{"status": "error", "message": "not a git repo"}'
  exit 2
fi

last_commit_for() {
  local path="$1"
  git log -n 1 --format=%ct -- "$path" 2>/dev/null || true
}

SOURCE_PATHS=(src lib cmd app internal pkg)
latest_source=""
for p in "${SOURCE_PATHS[@]}"; do
  if [ -e "$p" ]; then
    ts=$(last_commit_for "$p")
    if [ -n "$ts" ] && { [ -z "$latest_source" ] || [ "$ts" -gt "$latest_source" ]; }; then
      latest_source="$ts"
    fi
  fi
done

findings=()
add_finding() {
  local code="$1" severity="$2" message="$3"
  findings+=("{\"code\": \"$code\", \"severity\": \"$severity\", \"message\": \"$message\"}")
}

if [ -z "$latest_source" ]; then
  echo '{"status": "ok", "findings": [], "note": "no recognized source paths"}'
  exit 0
fi

# Check README.
if [ -f README.md ]; then
  readme_ts=$(last_commit_for README.md)
  if [ -n "$readme_ts" ] && [ "$readme_ts" -lt "$latest_source" ]; then
    add_finding "STALE_README" "warning" \
      "README.md last touched before latest source change. Re-read for drift."
  fi
fi

# Check each docs/ markdown file, scoped per docs-organization SKILL.md
# ("Scope of audit"): use `git ls-files` so .gitignore is honored, then
# filter out dot-directory components and LLM-configuration filenames.
if [ -d docs ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in docs/superpowers/*) continue;; esac
    case "$f" in */.*/*) continue;; esac
    case "$(basename "$f")" in CLAUDE.md|AGENTS.md|GEMINI.md|.cursorrules) continue;; esac
    f_ts=$(last_commit_for "$f")
    if [ -n "$f_ts" ] && [ "$f_ts" -lt "$latest_source" ]; then
      msg="$f last touched before latest source change. Re-read for drift."
      add_finding "STALE_DOC" "info" "$msg"
    fi
  done < <(git ls-files -- docs/ 2>/dev/null | grep -E '\.md$' || true)
fi

if [ "${#findings[@]}" -eq 0 ]; then
  echo '{"status": "ok", "findings": []}'
  exit 0
fi
joined=$(IFS=,; echo "${findings[*]}")
echo "{\"status\": \"findings\", \"findings\": [$joined]}"
exit 1
