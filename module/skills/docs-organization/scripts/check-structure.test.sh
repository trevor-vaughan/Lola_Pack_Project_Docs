#!/usr/bin/env bash
set -euo pipefail

# Isolate from the host's git config (commit.gpgsign, core.hooksPath,
# init.defaultBranch, safe.directory, etc.) so tests run identically on
# every dev machine and CI runner. Requires git ≥ 2.32.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/check-structure.sh"

mktmp() {
  mktemp -d -t check-structure-test.XXXXXX
}

fail_count=0
pass_count=0

assert_grep() {
  local pattern="$1" haystack="$2" label="$3"
  if echo "$haystack" | grep -q "$pattern"; then
    echo "PASS: $label"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $label"
    echo "  expected pattern: $pattern"
    echo "  got: $haystack"
    fail_count=$((fail_count + 1))
  fi
}

# Test 1: empty repo flags missing README
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep '"code": *"MISSING_README"' "$out" "empty repo flags MISSING_README"
popd > /dev/null
rm -rf "$dir"

# Test 2: README present, no docs/superpowers gitignore entry
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
echo "# Test" > README.md
echo "node_modules/" > .gitignore
out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep '"code": *"MISSING_GITIGNORE_SUPERPOWERS"' "$out" "missing superpowers gitignore"
popd > /dev/null
rm -rf "$dir"

# Test 3: everything good
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
echo "# Test" > README.md
echo "docs/superpowers/" > .gitignore
out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep '"status": *"ok"' "$out" "clean repo returns ok"
popd > /dev/null
rm -rf "$dir"

# Test 4: superpowers tracked accidentally.
# This test deliberately simulates the broken state where someone committed
# a file under docs/superpowers/ — the check we expect SUPERPOWERS_IN_GIT
# to catch. Two things to handle:
#   1. The repo's local .gitignore omits the docs/superpowers/ entry on
#      purpose, BUT the user running this test may have docs/superpowers/
#      in their global gitignore (~/.config/git/ignore) because they
#      adopted this skill's convention. We bypass with `git add -f`.
#   2. A fresh tempdir repo has no committer identity, so set one locally.
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
git config user.email "test@test.invalid"
git config user.name  "test"
echo "# Test" > README.md
mkdir -p docs/superpowers
echo "leaked" > docs/superpowers/spec.md
echo "node_modules/" > .gitignore  # deliberately missing the entry
git add README.md .gitignore
git add -f docs/superpowers/spec.md  # force past any global gitignore
git commit -q -m "oops"
out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep '"code": *"SUPERPOWERS_IN_GIT"' "$out" "tracked superpowers files flagged"
popd > /dev/null
rm -rf "$dir"

echo ""
echo "Results: $pass_count passed, $fail_count failed"
if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
