#!/usr/bin/env bash
# Module structural lint — validates the lola module layout.
# Usage: bash scripts/lint-module.sh [module-root-dir]
# Exit 0 if all checks pass, 1 if any fail.
set -euo pipefail

ROOT="${1:-.}"
errors=0
checks=0

pass() { checks=$((checks + 1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { checks=$((checks + 1)); errors=$((errors + 1)); printf "  \033[31mFAIL\033[0m %s — %s\n" "$1" "$2"; }
info() { printf "  \033[2m%s\033[0m\n" "$1"; }

echo "=== Module structure lint: $ROOT ==="

# 1. module/AGENTS.md exists and is non-empty
if [ -s "$ROOT/module/AGENTS.md" ]; then
  pass "module/AGENTS.md present (non-empty)"
else
  fail "module/AGENTS.md" "missing or empty"
fi

# 2. At least one module/skills/<name>/SKILL.md
SKILLS=()
if [ -d "$ROOT/module/skills" ]; then
  while IFS= read -r -d '' d; do SKILLS+=("$d"); done < <(find "$ROOT/module/skills" -mindepth 1 -maxdepth 1 -type d -print0)
fi
if [ "${#SKILLS[@]}" -eq 0 ]; then
  fail "module/skills/" "no skills found"
else
  info "found ${#SKILLS[@]} skill(s): $(for d in "${SKILLS[@]}"; do basename "$d"; done | tr '\n' ' ')"
fi

for sd in "${SKILLS[@]}"; do
  name=$(basename "$sd")
  skill_md="$sd/SKILL.md"
  if [ ! -f "$skill_md" ]; then
    fail "skill $name" "SKILL.md missing"
    continue
  fi

  # Frontmatter open
  if [ "$(head -1 "$skill_md")" = "---" ]; then
    pass "skill $name: frontmatter opens with ---"
  else
    fail "skill $name" "frontmatter does not open with ---"
    continue
  fi

  # Frontmatter close + extract
  fm_end=$(awk 'NR>1 && /^---$/{print NR; exit}' "$skill_md")
  if [ -z "$fm_end" ]; then
    fail "skill $name" "frontmatter has no closing ---"
    continue
  fi
  fm=$(sed -n "2,$((fm_end - 1))p" "$skill_md")

  if echo "$fm" | grep -q '^name:'; then
    pass "skill $name: frontmatter has name:"
  else
    fail "skill $name" "missing name: in frontmatter"
  fi

  if echo "$fm" | grep -q '^description:'; then
    pass "skill $name: frontmatter has description:"
  else
    fail "skill $name" "missing description: in frontmatter"
  fi

  # Body anchor check: if helpers ship next to SKILL.md, body must mention the SKILL_DIR anchor.
  # `find -L` follows symlinks (lola resolves and copies symlink targets at install time, so
  # symlinked helpers count as real helpers).
  helpers=$(find -L "$sd" -mindepth 2 -type f \( -name '*.sh' -o -name '*.py' -o -name '*.mjs' -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | wc -l)
  if [ "$helpers" -gt 0 ]; then
    if grep -qE 'SKILL_DIR|<SKILL_DIR>|skill-dir|Locate the skill|Helper paths' "$skill_md"; then
      pass "skill $name: SKILL.md has SKILL_DIR anchor instruction (ships $helpers helper file(s))"
    else
      fail "skill $name" "ships $helpers helper file(s) but SKILL.md has no SKILL_DIR anchor instruction"
    fi
  fi
done

# 3. module/commands/*.md frontmatter (if commands directory exists)
if [ -d "$ROOT/module/commands" ]; then
  COMMANDS=()
  while IFS= read -r -d '' f; do COMMANDS+=("$f"); done < <(find "$ROOT/module/commands" -maxdepth 1 -name '*.md' -print0)
  info "found ${#COMMANDS[@]} command(s)"
  for cmd in "${COMMANDS[@]}"; do
    cname=$(basename "$cmd" .md)
    if [ "$(head -1 "$cmd")" = "---" ]; then
      pass "command $cname: frontmatter opens with ---"
    else
      fail "command $cname" "frontmatter does not open with ---"
      continue
    fi
    fm_end=$(awk 'NR>1 && /^---$/{print NR; exit}' "$cmd")
    if [ -z "$fm_end" ]; then
      fail "command $cname" "frontmatter has no closing ---"
      continue
    fi
    fm=$(sed -n "2,$((fm_end - 1))p" "$cmd")
    if echo "$fm" | grep -q '^description:'; then
      pass "command $cname: frontmatter has description:"
    else
      fail "command $cname" "missing description: in frontmatter"
    fi
  done
fi

echo "---"
echo "Module lint: $checks checks, $errors errors"
[ "$errors" -eq 0 ]
