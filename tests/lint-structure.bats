setup() { REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"; LINT="$REPO/.taskfiles/scripts/lint-structure.sh"; }

@test "valid fixture passes" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/valid"
  [ "$status" -eq 0 ]
}
@test "missing description fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/missing-desc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"description"* ]]
}
@test "explicit skill without wrapper fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/explicit-no-wrapper"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no command names it"* ]]
}
@test "the real module passes" {
  run "$LINT" --module "$REPO"
  [ "$status" -eq 0 ]
}
@test "one skill fronted by several differently-named commands passes" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/multi-command"
  [ "$status" -eq 0 ]
  # Both directions of check 6 must actually have run: a bare exit-0 assertion
  # cannot tell "the binding check passed" from "the binding check was skipped".
  [[ "$output" == *"command draft: names an existing skill"* ]]
  [[ "$output" == *"skill writer: explicit, reachable from a command"* ]]
}
@test "a command naming no existing skill fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/orphan-command"
  [ "$status" -ne 0 ]
  [[ "$output" == *"names no existing skill"* ]]
}
@test "llm mode prints no PASS lines on success" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/valid" --mode llm
  [ "$status" -eq 0 ]
  [[ "$output" != *"PASS"* ]]
  [[ "$output" == *"lint-structure: OK"* ]]
}
@test "human mode prints PASS lines on success" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/valid" --mode human
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}
@test "llm mode still reports failures" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/missing-desc" --mode llm
  [ "$status" -ne 0 ]
  [[ "$output" == *"description"* ]]
}
@test "an invalid mode is rejected" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/valid" --mode shouty
  [ "$status" -eq 2 ]
}
@test "--module with no value is a usage error, not a bash error" {
  run "$LINT" --module
  [ "$status" -eq 2 ]
  [[ "$output" == *"lint-structure: --module requires a value"* ]]
  [[ "$output" != *"unbound variable"* ]]
}
@test "--mode with no value is a usage error, not a bash error" {
  run "$LINT" --mode
  [ "$status" -eq 2 ]
  [[ "$output" == *"lint-structure: --mode requires a value"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

# --- check 6: command → skill binding ----------------------------------------
@test "a commands-only module with no skills passes" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/commands-only"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no skills in module"* ]]
}
@test "a command naming its skill in prose only fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/prose-mention-only"
  [ "$status" -ne 0 ]
  [[ "$output" == *"command stuff"* ]]
  [[ "$output" == *"names no existing skill"* ]]
}

# --- checks 2 and 4: frontmatter ----------------------------------------------
@test "a skill missing name: fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/skill-missing-name"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing name: in frontmatter"* ]]
}
@test "a skill with unclosed frontmatter fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/skill-unclosed-frontmatter"
  [ "$status" -ne 0 ]
  [[ "$output" == *"skill bad"* ]]
  [[ "$output" == *"no closing ---"* ]]
}
@test "a command with no frontmatter fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/command-no-frontmatter"
  [ "$status" -ne 0 ]
  [[ "$output" == *"command bare"* ]]
  [[ "$output" == *"frontmatter missing"* ]]
}

# --- check 5: AGENTS.md --------------------------------------------------------
@test "an empty module/AGENTS.md fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/empty-agents"
  [ "$status" -ne 0 ]
  [[ "$output" == *"module/AGENTS.md"* ]]
  [[ "$output" == *"present but empty"* ]]
}

# --- check 7: helpers need a SKILL_DIR anchor ---------------------------------
@test "a helper beside SKILL.md with no SKILL_DIR anchor fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/helper-no-anchor"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ships 1 helper file(s)"* ]]
  [[ "$output" == *"no SKILL_DIR anchor"* ]]
}
@test "a symlink loop under a skill warns instead of aborting the run" {
  # Built at run time, not committed: a looping symlink in the repo would send
  # every recursive tool that touches tests/fixtures into the same loop.
  mod="$BATS_TEST_TMPDIR/loop-module"
  mkdir -p "$mod/module/skills/x"
  cat >"$mod/module/skills/x/SKILL.md" <<'EOF'
---
name: x
description: Use when verifying that an untraversable skill directory does not abort the lint.
---

# x

Resolve helper paths from SKILL_DIR, the directory this file was loaded from.
EOF
  ln -s . "$mod/module/skills/x/loop"
  run "$LINT" --module "$mod"
  [ "$status" -eq 0 ]
  [[ "$output" == *"could not fully traverse"* ]]
  [[ "$output" == *"loop"* ]]
  [[ "$output" != *"FAIL at line"* ]]
}

# --- check 8: mcps.json --------------------------------------------------------
@test "a valid mcps.json passes" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed; the linter warns and skips these checks"
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/mcps-valid"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mcps.json: has mcpServers root"* ]]
  [[ "$output" == *"mcps.json: no invalid type:remote entries"* ]]
}
@test "mcps.json with type:remote fails" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed; the linter warns and skips these checks"
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/mcps-remote-type"
  [ "$status" -ne 0 ]
  [[ "$output" == *'type:"remote" is not a transport'* ]]
}
@test "mcps.json without an mcpServers root fails" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed; the linter warns and skips these checks"
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/mcps-no-root"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing or invalid mcpServers root"* ]]
}

# --- check 9: lola.yaml install hooks -----------------------------------------
@test "a lola.yaml hook that exists passes" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/lola-hook-ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lola.yaml: hook hooks/post-install.sh resolves"* ]]
}
@test "a lola.yaml hook that does not exist fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/lola-hook-missing"
  [ "$status" -ne 0 ]
  [[ "$output" == *"hook script not found: hooks/post-install.sh"* ]]
}
@test "a lola.yaml hook escaping the module fails" {
  run "$LINT" --module "$BATS_TEST_DIRNAME/fixtures/lola-hook-escape"
  [ "$status" -ne 0 ]
  [[ "$output" == *"hook path must be relative and inside the module: ../evil.sh"* ]]
}
