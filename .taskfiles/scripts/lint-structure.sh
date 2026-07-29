#!/usr/bin/env bash
# Structural lint for a lola module.
#
# Usage: lint-structure.sh [--module DIR] [--mode human|llm]
#
# Checks the minimum shape lola requires of module/, plus the authoring
# invariants the reference modules teach. Content quality (placeholder prose,
# weak descriptions) is skillsaw's job, not this script's.
#
# This file is byte-identical in lola-mod-template and lola-mod-project-docs.
# Change it in one and copy it to the other.
set -euo pipefail
trap 'echo "lint-structure: FAIL at line $LINENO" >&2' ERR

MODULE_ROOT="."
MODE="human"
# Every value-taking flag checks that its value is present: under `set -u` a
# bare `--module` would otherwise die with bash's own "$2: unbound variable"
# and exit 1, while every other usage error here exits 2 with our prefix.
while [ $# -gt 0 ]; do
  case "$1" in
    --module)
      [ $# -ge 2 ] || { echo "lint-structure: --module requires a value" >&2; exit 2; }
      MODULE_ROOT="$2"; shift 2;;
    --mode)
      [ $# -ge 2 ] || { echo "lint-structure: --mode requires a value" >&2; exit 2; }
      MODE="$2"; shift 2;;
    *) echo "lint-structure: unknown arg: $1" >&2; exit 2;;
  esac
done
case "$MODE" in
  human|llm) ;;
  *) echo "lint-structure: --mode must be human or llm" >&2; exit 2;;
esac

M="$MODULE_ROOT/module"
CHECKS=0
ERRORS=0

# Colour only on a human-mode terminal: CI logs and bats captures stay clean.
if [ "$MODE" = human ] && [ -t 1 ]; then
  C_PASS=$'\033[32m'; C_FAIL=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_PASS=""; C_FAIL=""; C_DIM=""; C_OFF=""
fi

pass() {
  CHECKS=$((CHECKS + 1))
  if [ "$MODE" = human ]; then printf "  %sPASS%s %s\n" "$C_PASS" "$C_OFF" "$1"; fi
  return 0
}
fail() {
  CHECKS=$((CHECKS + 1)); ERRORS=$((ERRORS + 1))
  printf "  %sFAIL%s %s — %s\n" "$C_FAIL" "$C_OFF" "$1" "$2" >&2
  return 0
}
info() {
  if [ "$MODE" = human ]; then printf "  %s%s%s\n" "$C_DIM" "$1" "$C_OFF"; fi
  return 0
}
warn() { printf "  WARN %s\n" "$1" >&2; return 0; }

if [ "$MODE" = human ]; then echo "=== Module structure lint: $MODULE_ROOT ==="; fi

[ -d "$M" ] || { echo "lint-structure: no module/ dir under $MODULE_ROOT" >&2; exit 1; }

# Print the frontmatter body of $1. Returns 1 if the block is missing or unclosed.
frontmatter_of() {
  local file="$1" end
  [ "$(head -1 "$file")" = "---" ] || return 1
  end="$(awk 'NR>1 && /^---[[:space:]]*$/ {print NR; exit}' "$file")"
  [ -n "$end" ] || return 1
  sed -n "2,$((end - 1))p" "$file"
}

# --- 1. at least one installable component -----------------------------------
have=0
for c in "$M"/skills/*/SKILL.md "$M"/commands/*.md "$M"/agents/*.md "$M/mcps.json" "$M/AGENTS.md"; do
  [ -e "$c" ] && have=1
done
if [ "$have" -eq 1 ]; then
  pass "module/ has at least one installable component"
else
  fail "module/" "no installable component (skill, command, agent, mcps.json, or AGENTS.md)"
fi

# --- collect skill names once; several checks below need them ----------------
SKILL_NAMES=()
for s in "$M"/skills/*/SKILL.md; do
  [ -e "$s" ] || continue
  SKILL_NAMES+=("$(basename "$(dirname "$s")")")
done
if [ "${#SKILL_NAMES[@]}" -gt 0 ]; then
  info "found ${#SKILL_NAMES[@]} skill(s): ${SKILL_NAMES[*]}"
fi

# The single rule for "this command activates that skill", used in both
# directions by check 6. One definition only: this file is copied verbatim
# between repos, so two copies of the rule drift into two different rules.
#
# A command activates a skill either by sharing its name — commands/<skill>.md,
# the one-command-per-skill shape — or by naming it in a markdown code span,
# `adr`, which is how every reference command phrases the activation line.
# Matching the backticked form as a fixed string keeps incidental prose
# mentions of the word from counting as an activation path, and keeps the
# skill name out of a regex entirely.
command_activates() {  # $1 = command file, $2 = skill name
  local cmd="$1" sk="$2"
  [ "$(basename "$cmd" .md)" = "$sk" ] && return 0
  grep -qF -- "\`${sk}\`" "$cmd"
}

# --- 2. skills: frontmatter, name, description --------------------------------
for s in "$M"/skills/*/SKILL.md; do
  [ -e "$s" ] || continue
  name="$(basename "$(dirname "$s")")"
  if ! fm="$(frontmatter_of "$s")"; then
    fail "skill $name" "frontmatter missing, or has no closing ---"
    continue
  fi
  pass "skill $name: frontmatter well-formed"
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

  # --- 7. helpers require a SKILL_DIR anchor instruction ----------------------
  # find -L follows symlinks: lola resolves and copies symlink targets at
  # install time, so a symlinked helper is a real helper.
  #
  # Every shipped file except SKILL.md is a helper, including one sitting
  # beside it (skills/x/helper.sh). Excluding SKILL.md by path says that
  # directly; a `-mindepth 2` floor would say it by accident and lose every
  # depth-1 helper with it.
  #
  # Following symlinks can also fail — a loop, or a directory we cannot read.
  # find then prints a diagnostic and exits nonzero, which under
  # `set -e`/`pipefail` would abort the whole lint. Keep whatever it did find,
  # report why the count may be short, and carry on.
  sdir="$(dirname "$s")"
  find_err="$(mktemp)"
  find_rc=0
  helper_paths="$(find -L "$sdir" -type f ! -path "$sdir/SKILL.md" \
    \( -name '*.sh' -o -name '*.py' -o -name '*.mjs' -o -name '*.md' \
       -o -name '*.yml' -o -name '*.yaml' \) 2>"$find_err")" || find_rc=$?
  if [ "$find_rc" -ne 0 ]; then
    warn "skill $name: could not fully traverse $sdir (find exited $find_rc); helper count may be short"
    while IFS= read -r line; do
      # An `if`, not `[ -n "$line" ] && warn ...`: a blank line would make the
      # and-list the loop body's failing last command, and errexit would abort
      # the run — the very failure this block exists to prevent.
      if [ -n "$line" ]; then warn "skill $name: $line"; fi
    done <"$find_err"
  fi
  rm -f "$find_err"
  helpers=0
  if [ -n "$helper_paths" ]; then helpers="$(printf '%s\n' "$helper_paths" | wc -l)"; fi
  if [ "$helpers" -gt 0 ]; then
    if grep -qE 'SKILL_DIR|<SKILL_DIR>|skill-dir|Locate the skill|Helper paths' "$s"; then
      pass "skill $name: SKILL_DIR anchor present (ships $helpers helper file(s))"
    else
      fail "skill $name" "ships $helpers helper file(s) but SKILL.md has no SKILL_DIR anchor instruction"
    fi
  fi
done

# --- 3. agents: frontmatter, description --------------------------------------
for a in "$M"/agents/*.md; do
  [ -e "$a" ] || continue
  aname="$(basename "$a" .md)"
  if ! fm="$(frontmatter_of "$a")"; then
    fail "agent $aname" "frontmatter missing, or has no closing ---"
    continue
  fi
  pass "agent $aname: frontmatter well-formed"
  if echo "$fm" | grep -q '^description:'; then
    pass "agent $aname: frontmatter has description:"
  else
    fail "agent $aname" "missing description: in frontmatter"
  fi
done

# --- 4. commands: frontmatter, description ------------------------------------
for cmd in "$M"/commands/*.md; do
  [ -e "$cmd" ] || continue
  cname="$(basename "$cmd" .md)"
  if ! fm="$(frontmatter_of "$cmd")"; then
    fail "command $cname" "frontmatter missing, or has no closing ---"
    continue
  fi
  pass "command $cname: frontmatter well-formed"
  if echo "$fm" | grep -q '^description:'; then
    pass "command $cname: frontmatter has description:"
  else
    fail "command $cname" "missing description: in frontmatter"
  fi
done

# --- 5. AGENTS.md non-empty ---------------------------------------------------
if [ -e "$M/AGENTS.md" ]; then
  if [ -s "$M/AGENTS.md" ]; then
    pass "module/AGENTS.md present and non-empty"
  else
    fail "module/AGENTS.md" "present but empty"
  fi
fi

# --- 6. explicit/wrapper pairing, bound by reference --------------------------
# Only ask a command to name a skill when the module ships one. A module of
# pure prompt-commands is installable (check 1 accepts commands/*.md alone) and
# has nothing for a command to name, so this direction would be unsatisfiable.
if [ "${#SKILL_NAMES[@]}" -eq 0 ]; then
  info "no skills in module; skipping command→skill binding check"
else
  for cmd in "$M"/commands/*.md; do
    [ -e "$cmd" ] || continue
    cname="$(basename "$cmd" .md)"
    bound=0
    for sk in "${SKILL_NAMES[@]}"; do
      if command_activates "$cmd" "$sk"; then bound=1; break; fi
    done
    if [ "$bound" -eq 1 ]; then
      pass "command $cname: names an existing skill"
    else
      fail "command $cname" "names no existing skill (checked filename match and \`skill-name\` code spans)"
    fi
  done
fi

for s in "$M"/skills/*/SKILL.md; do
  [ -e "$s" ] || continue
  name="$(basename "$(dirname "$s")")"
  frontmatter_of "$s" 2>/dev/null | grep -qi 'DO NOT AUTO-INVOKE' || continue
  reachable=0
  for cmd in "$M"/commands/*.md; do
    [ -e "$cmd" ] || continue
    if command_activates "$cmd" "$name"; then reachable=1; break; fi
  done
  if [ "$reachable" -eq 1 ]; then
    pass "skill $name: explicit, reachable from a command"
  else
    fail "skill $name" "explicit (DO NOT AUTO-INVOKE) but no command names it"
  fi
done

# --- 8. mcps.json validity ----------------------------------------------------
if [ -e "$M/mcps.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    if jq -e '.mcpServers' "$M/mcps.json" >/dev/null 2>&1; then
      pass "mcps.json: has mcpServers root"
    else
      fail "mcps.json" "missing or invalid mcpServers root"
    fi
    if jq -e '.mcpServers[] | select(.type=="remote")' "$M/mcps.json" >/dev/null 2>&1; then
      fail "mcps.json" 'type:"remote" is not a transport — use http or sse'
    else
      pass "mcps.json: no invalid type:remote entries"
    fi
  else
    warn "jq not found; skipping mcps.json content checks"
  fi
fi

# --- 9. lola.yaml install hooks resolve --------------------------------------
if [ -e "$M/lola.yaml" ]; then
  while IFS= read -r hook; do
    [ -n "$hook" ] || continue
    case "$hook" in
      /*|*..*)
        fail "lola.yaml" "hook path must be relative and inside the module: $hook" ;;
      *)
        if [ -e "$M/$hook" ]; then
          pass "lola.yaml: hook $hook resolves"
        else
          fail "lola.yaml" "hook script not found: $hook"
        fi ;;
    esac
  done < <(sed -n 's/^[[:space:]]*\(pre-install\|post-install\):[[:space:]]*\(.*\)$/\2/p' \
             "$M/lola.yaml" | tr -d "\"'")
fi

# --- summary ------------------------------------------------------------------
if [ "$MODE" = human ]; then
  echo "---"
  echo "lint-structure: $CHECKS checks, $ERRORS errors"
fi
if [ "$ERRORS" -ne 0 ]; then
  if [ "$MODE" = llm ]; then echo "lint-structure: FAILED ($ERRORS of $CHECKS checks)" >&2; fi
  exit 1
fi
if [ "$MODE" = llm ]; then echo "lint-structure: OK ($CHECKS checks)"; fi
exit 0
