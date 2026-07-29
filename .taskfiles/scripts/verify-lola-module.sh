#!/usr/bin/env bash
# Sandboxed lola install oracle.
#
# Usage: verify-lola-module.sh --name NAME [--module DIR] [--scope user|project]
#                              [--assistant KEY] [--mode human|llm]
#
# Installs $MODULE/module into a throwaway HOME and LOLA_HOME, then asserts that
# every skill and command the source declares actually landed, and that the
# module's managed-section marker was injected.
#
# Assertions are DISCOVERED from the source tree, never hardcoded. Two reasons:
# skill directories are named after the skill, not the module, so a module with
# skills that differ from its own name breaks a `skills/$NAME` assertion; and
# lola moves install destinations between releases (opencode user scope moved
# from ~/.opencode to ~/.config/opencode), so a per-assistant path table rots
# silently.
#
# This file is byte-identical in lola-mod-template and lola-mod-project-docs.
# Change it in one and copy it to the other.
set -euo pipefail
trap 'echo "verify: FAIL at line $LINENO" >&2' ERR

NAME=""; SCOPE="user"; SRC="."; ASSISTANT="claude-code"; MODE="human"

# v0.5.0 is the first tagged release with the gitignore-aware module copy.
# Earlier versions copy the whole repo, including .venv/ and .git/, which is
# slow and confuses the mod-add walker. There is no v0.4.5 despite older docs.
LOLA_MIN="0.5.0"

# gemini-cli receives commands and an instructions file but no skills, so the
# skill assertions below are skipped for it. Verified against lola v0.7.0.
NO_SKILL_ASSISTANTS="gemini-cli"

while [ $# -gt 0 ]; do
  case "$1" in
    --name)      NAME="$2"; shift 2;;
    --scope)     SCOPE="$2"; shift 2;;
    --module)    SRC="$2"; shift 2;;
    --assistant) ASSISTANT="$2"; shift 2;;
    --mode)      MODE="$2"; shift 2;;
    *) echo "verify: unknown arg: $1" >&2; exit 2;;
  esac
done

[ -n "$NAME" ] || { echo "verify: --name required" >&2; exit 2; }
case "$SCOPE" in
  user|project) ;;
  *) echo "verify: --scope must be user or project" >&2; exit 2;;
esac
case "$MODE" in
  human|llm) ;;
  *) echo "verify: --mode must be human or llm" >&2; exit 2;;
esac
[ -d "$SRC/module" ] || { echo "verify: no module/ dir under $SRC" >&2; exit 2; }
command -v lola >/dev/null 2>&1 || { echo "verify: lola not on PATH" >&2; exit 2; }

LOLA_VER="$(lola --version 2>&1 | awk '{print $NF}' | head -1)"
if [ "$(printf '%s\n%s\n' "$LOLA_MIN" "$LOLA_VER" | sort -V | head -1)" != "$LOLA_MIN" ]; then
  echo "verify: lola >= $LOLA_MIN required (found $LOLA_VER)" >&2
  echo "        uv tool install --force git+https://github.com/LobsterTrap/lola@v0.7.0" >&2
  exit 2
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
# XDG_CONFIG_HOME is pinned under the sandbox HOME, not merely unset: lola
# resolves opencode's user-scope destination from $XDG_CONFIG_HOME and only
# falls back to ~/.config when it is absent. A caller that exports it — common
# in dotfile setups — otherwise redirects the install into their real config
# dir, which both breaks the assertions below and writes outside the sandbox.
# Keeping it under $HOME reproduces the default ~/.config layout that the
# user-scope ROOT search expects.
export HOME="$SANDBOX/home" LOLA_HOME="$SANDBOX/lola"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$HOME" "$LOLA_HOME" "$XDG_CONFIG_HOME"

# Install from a copy inside the sandbox so a project-scope install, which
# writes into the current directory, can never touch the real checkout.
WORK="$SANDBOX/work"
mkdir -p "$WORK"
cp -R "$SRC/module" "$WORK/module"
cd "$WORK"

EXPECT_SKILLS=(); EXPECT_COMMANDS=()
for d in "$WORK"/module/skills/*/; do
  [ -e "$d/SKILL.md" ] || continue
  EXPECT_SKILLS+=("$(basename "$d")")
done
for f in "$WORK"/module/commands/*.md; do
  [ -e "$f" ] || continue
  EXPECT_COMMANDS+=("$(basename "$f" .md)")
done

lola mod add -n "$NAME" ./ >/dev/null
lola install "$NAME" -a "$ASSISTANT" --scope "$SCOPE" -f >/dev/null

case "$SCOPE" in
  user)    ROOT="$HOME";;
  project) ROOT="$WORK";;
esac

FAILED=0
ok()  { if [ "$MODE" = human ]; then printf "  OK      %s\n" "$1"; fi; return 0; }
bad() { FAILED=1; printf "  MISSING %s\n" "$1" >&2; return 0; }

# Search the scope root, skipping the module source copy and lola's own
# registry cache — both contain the files we are looking for, which would
# make every assertion pass vacuously.
find_installed() {
  find "$ROOT" \
    -path "$WORK/module" -prune -o \
    -path '*/.lola/*' -prune -o \
    -type f -path "$1" -print 2>/dev/null | head -1
}
find_installed_named() {
  find "$ROOT" \
    -path "$WORK/module" -prune -o \
    -path '*/.lola/*' -prune -o \
    -type f -name "$1" -print 2>/dev/null | head -1
}

# Mirrors lola's own ALWAYS_IGNORE. A skill may legitimately ship any other
# directory — vendored dependencies, fixtures, reference material — and this
# script's job is to prove that it arrives.
IGNORED_DIRS='.git|.svn|.hg|.venv|venv|.env|__pycache__|.pytest_cache|.mypy_cache|.tox|.ruff_cache|node_modules|.lola|.test-output'

if ! echo "$NO_SKILL_ASSISTANTS" | grep -qw "$ASSISTANT"; then
  for s in ${EXPECT_SKILLS[@]+"${EXPECT_SKILLS[@]}"}; do
    hit="$(find_installed "*/skills/$s/SKILL.md")"
    if [ -z "$hit" ]; then
      bad "skill $s (no */skills/$s/SKILL.md under $ROOT)"
      continue
    fi
    ok "skill $s -> ${hit#"$ROOT"/}"

    # Every file the source ships must arrive. A skill that shells out to a
    # vendored helper is broken, not degraded, if that helper is filtered out
    # in transit — and lola's ignore rules are the kind of thing that widens
    # without warning.
    installed_dir="$(dirname "$hit")"
    missing=0
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      if [ ! -e "$installed_dir/$rel" ]; then
        bad "skill $s: file dropped in transit: $rel"
        missing=$((missing + 1))
      fi
    done < <(cd "$WORK/module/skills/$s" && find . -type f \
               | sed 's|^\./||' \
               | grep -Ev "(^|/)($IGNORED_DIRS)(/|$)")
    if [ "$missing" -eq 0 ]; then ok "skill $s: every source file arrived"; fi
  done
fi

for c in ${EXPECT_COMMANDS[@]+"${EXPECT_COMMANDS[@]}"}; do
  hit="$(find_installed_named "$c.md")"
  if [ -n "$hit" ]; then ok "command $c -> ${hit#"$ROOT"/}"; else bad "command $c (no $c.md under $ROOT)"; fi
done

if [ -e "$WORK/module/AGENTS.md" ]; then
  if grep -rlF --exclude-dir=.lola --exclude-dir=module \
       -- "lola:module:$NAME" "$ROOT" >/dev/null 2>&1; then
    ok "managed-section marker lola:module:$NAME injected"
  else
    bad "managed-section marker lola:module:$NAME (not found in any context file)"
  fi
fi

if [ "$FAILED" -ne 0 ]; then
  echo "verify: FAILED ($NAME @ $ASSISTANT/$SCOPE) — sandbox contents follow:" >&2
  find "$ROOT" -type f 2>/dev/null | sed "s|$ROOT|<root>|" >&2
  exit 1
fi

if [ "$MODE" = human ]; then
  echo "verify: OK ($NAME @ $ASSISTANT/$SCOPE)"
else
  echo "verify: OK $NAME $ASSISTANT/$SCOPE"
fi
exit 0
