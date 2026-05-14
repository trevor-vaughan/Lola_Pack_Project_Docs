#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/check-staleness.sh"

mktmp() { mktemp -d -t check-staleness-test.XXXXXX; }

fail_count=0; pass_count=0
assert_grep() {
  local pattern="$1" haystack="$2" label="$3"
  if echo "$haystack" | grep -q "$pattern"; then
    echo "PASS: $label"; pass_count=$((pass_count + 1))
  else
    echo "FAIL: $label"; echo "  pattern: $pattern"; echo "  got: $haystack"
    fail_count=$((fail_count + 1))
  fi
}

# Helper: make a commit with a fake date.
commit_with_date() {
  local date="$1" message="$2"
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    git commit -q --allow-empty -m "$message"
}

# Test 1: code recently changed, README old → flagged.
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
git config user.email "t@t"; git config user.name "t"

echo "# old" > README.md
mkdir src
git add README.md
commit_with_date "2026-01-01T12:00:00" "initial docs"

echo "function f() {}" > src/main.js
git add src/main.js
commit_with_date "2026-05-01T12:00:00" "code change"

out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep '"code": *"STALE_README"' "$out" "old README flagged when code is newer"
popd > /dev/null; rm -rf "$dir"

# Test 2: code and docs in step → ok.
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
git config user.email "t@t"; git config user.name "t"
echo "# doc" > README.md
mkdir src
echo "function f() {}" > src/main.js
git add README.md src/main.js
commit_with_date "2026-05-01T12:00:00" "init"
out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep '"status": *"ok"' "$out" "synced repo returns ok"
popd > /dev/null; rm -rf "$dir"

# Test 3: no source dir → script should not crash.
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
git config user.email "t@t"; git config user.name "t"
echo "# only docs" > README.md
git add README.md
commit_with_date "2026-05-01T12:00:00" "docs only"
out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep '"status": *"ok"' "$out" "no source dir returns ok"
popd > /dev/null; rm -rf "$dir"

# Test 4: docs under a dot-directory are excluded from staleness scanning.
# Per docs-organization SKILL.md ("Scope of audit"), any directory whose
# name begins with `.` is an agent-runtime space and is never audited.
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p docs/.hidden src
echo "# old hidden" > docs/.hidden/legacy.md
echo "# old regular" > docs/regular.md
git add docs/.hidden/legacy.md docs/regular.md
commit_with_date "2026-01-01T12:00:00" "initial docs"
echo "function f() {}" > src/main.js
git add src/main.js
commit_with_date "2026-05-01T12:00:00" "code change"
out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep 'docs/regular.md' "$out" "regular doc flagged stale"
if echo "$out" | grep -q 'docs/.hidden/legacy.md'; then
  echo "FAIL: docs/.hidden/legacy.md must be excluded by dot-directory rule"
  echo "  got: $out"
  fail_count=$((fail_count + 1))
else
  echo "PASS: dot-directory excluded from staleness scan"
  pass_count=$((pass_count + 1))
fi
popd > /dev/null; rm -rf "$dir"

# Test 5: LLM-configuration files inside docs/ are excluded.
# CLAUDE.md, AGENTS.md, GEMINI.md, and .cursorrules describe agent
# behavior, not the project, and must never be flagged as stale.
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir docs src
echo "# regular" > docs/guide.md
echo "# claude" > docs/CLAUDE.md
echo "# agents" > docs/AGENTS.md
echo "# gemini" > docs/GEMINI.md
git add docs/guide.md docs/CLAUDE.md docs/AGENTS.md docs/GEMINI.md
commit_with_date "2026-01-01T12:00:00" "initial docs"
echo "function f() {}" > src/main.js
git add src/main.js
commit_with_date "2026-05-01T12:00:00" "code change"
out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep 'docs/guide.md' "$out" "regular doc flagged stale"
for f in docs/CLAUDE.md docs/AGENTS.md docs/GEMINI.md; do
  if echo "$out" | grep -q "$f"; then
    echo "FAIL: $f must be excluded by LLM-config rule"
    echo "  got: $out"
    fail_count=$((fail_count + 1))
  else
    echo "PASS: $f excluded from staleness scan"
    pass_count=$((pass_count + 1))
  fi
done
popd > /dev/null; rm -rf "$dir"

# Test 6: gitignored docs files are excluded (via switch to git ls-files).
# A file gitignored after a previous commit history would still have a
# git history; we rely on git ls-files only returning tracked files.
# Untracked files (not in git ls-files) are skipped automatically.
dir=$(mktmp); pushd "$dir" > /dev/null
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir docs src
echo "# tracked" > docs/tracked.md
echo "# untracked" > docs/untracked.md
echo "docs/untracked.md" > .gitignore
git add docs/tracked.md .gitignore
commit_with_date "2026-01-01T12:00:00" "initial docs"
echo "function f() {}" > src/main.js
git add src/main.js
commit_with_date "2026-05-01T12:00:00" "code change"
out=$(bash "$SCRIPT" 2>&1 || true)
assert_grep 'docs/tracked.md' "$out" "tracked doc flagged stale"
if echo "$out" | grep -q 'docs/untracked.md'; then
  echo "FAIL: docs/untracked.md (gitignored) must be excluded"
  echo "  got: $out"
  fail_count=$((fail_count + 1))
else
  echo "PASS: gitignored/untracked doc excluded from staleness scan"
  pass_count=$((pass_count + 1))
fi
popd > /dev/null; rm -rf "$dir"

echo ""
echo "Results: $pass_count passed, $fail_count failed"
[ "$fail_count" -eq 0 ]
