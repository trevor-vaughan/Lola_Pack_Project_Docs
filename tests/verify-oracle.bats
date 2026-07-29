# Copied from lola-mod-template. The only intended difference is the module
# name passed to the oracle (docs-discipline rather than example).

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  ORACLE="$REPO/.taskfiles/scripts/verify-lola-module.sh"
}

# The oracle reports precisely why it exited (lola missing, lola too old, a file
# dropped in transit). Asserting bare status throws that away and leaves the
# operator with `[ "$status" -eq 0 ]' failed' and nothing to act on.
assert_ok() {
  if [ "$status" -ne 0 ]; then
    echo "oracle exited $status:" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "missing --name is rejected" {
  run "$ORACLE" --module "$REPO"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--name required"* ]]
}
@test "an invalid scope is rejected" {
  run "$ORACLE" --name docs-discipline --module "$REPO" --scope global
  [ "$status" -eq 2 ]
  [[ "$output" == *"--scope must be user or project"* ]]
}
@test "an invalid mode is rejected" {
  run "$ORACLE" --name docs-discipline --module "$REPO" --mode shouty
  [ "$status" -eq 2 ]
  [[ "$output" == *"--mode must be human or llm"* ]]
}
@test "a source tree with no module/ is rejected" {
  run "$ORACLE" --name docs-discipline --module "$BATS_TEST_DIRNAME/fixtures"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no module/ dir"* ]]
}
@test "user-scope install of the real module succeeds" {
  run "$ORACLE" --name docs-discipline --module "$REPO" --scope user
  assert_ok
}
@test "project-scope install of the real module succeeds" {
  run "$ORACLE" --name docs-discipline --module "$REPO" --scope project
  assert_ok
}
@test "llm mode is quiet on success" {
  run "$ORACLE" --name docs-discipline --module "$REPO" --scope user --mode llm
  assert_ok
  [[ "$output" != *"OK  "* ]]
}
# lola resolves opencode's user-scope destination from XDG_CONFIG_HOME
# (lola/config.py get_user_config_dir), not from HOME. Sandboxing HOME alone let
# an install escape into the caller's real ~/.config/opencode: the assertions
# failed *and* the developer's config was written to.
@test "an exported XDG_CONFIG_HOME cannot redirect the install out of the sandbox" {
  local leak_dir leaked
  leak_dir="$(mktemp -d)"
  XDG_CONFIG_HOME="$leak_dir" run "$ORACLE" --name docs-discipline \
    --module "$REPO" --assistant opencode --scope user
  leaked="$(find "$leak_dir" -type f 2>/dev/null | head -5)"
  rm -rf "$leak_dir"
  if [ -n "$leaked" ]; then
    echo "install escaped the sandbox into \$XDG_CONFIG_HOME:" >&2
    echo "$leaked" >&2
    return 1
  fi
  assert_ok
}
