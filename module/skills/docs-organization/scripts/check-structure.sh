#!/usr/bin/env bash
set -euo pipefail

# Emits structural drift findings as JSON on stdout.
# Exit code: 0 = no findings, 1 = findings, 2 = internal error.

findings=()

add_finding() {
  local code="$1" severity="$2" message="$3"
  findings+=("{\"code\": \"$code\", \"severity\": \"$severity\", \"message\": \"$message\"}")
}

# Check 1: README.md present and non-empty.
if [ ! -f README.md ] || [ ! -s README.md ]; then
  add_finding "MISSING_README" "blocker" \
    "README.md is missing or empty. Run /docs-init to scaffold one."
fi

# Check 2: .gitignore contains docs/superpowers/ entry.
if [ ! -f .gitignore ] || ! grep -qE '^docs/superpowers/?$' .gitignore; then
  add_finding "MISSING_GITIGNORE_SUPERPOWERS" "blocker" \
    "docs/superpowers/ must be in .gitignore. /docs-init or /docs-update can add it."
fi

# Check 3: no docs/superpowers files are tracked.
if git rev-parse --git-dir > /dev/null 2>&1; then
  if git ls-files docs/superpowers 2>/dev/null | grep -q .; then
    add_finding "SUPERPOWERS_IN_GIT" "blocker" \
      "Files under docs/superpowers/ are tracked in git. Run git rm --cached on them."
  fi
fi

# Check 4: if docs/dev/adr exists, expect an index.md.
if [ -d docs/dev/adr ] && [ ! -f docs/dev/adr/index.md ]; then
  add_finding "MISSING_ADR_INDEX" "warning" \
    "docs/dev/adr/ exists but index.md is missing. Run adr-index.sh."
fi
if [ -d docs/adr ] && [ ! -f docs/adr/index.md ]; then
  add_finding "MISSING_ADR_INDEX" "warning" \
    "docs/adr/ exists but index.md is missing. Run adr-index.sh."
fi

# Emit JSON.
if [ "${#findings[@]}" -eq 0 ]; then
  echo '{"status": "ok", "findings": []}'
  exit 0
fi

joined=$(IFS=,; echo "${findings[*]}")
echo "{\"status\": \"findings\", \"findings\": [$joined]}"
exit 1
