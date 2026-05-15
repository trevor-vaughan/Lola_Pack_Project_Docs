## Pack development notes

`Taskfile.yml` is for pack developers self-testing the pack live in their
own AI assistant. End users install via `lola install` directly and do not
need it.

- **`task install` ordering is load-bearing.** `install:scripts` must run
  *before* `install:lola`. `lola install` copies
  `module/skills/docs-organization/scripts/` verbatim into the assistant's
  skill directory, so `node_modules` must exist in the source for the
  installed location to be runnable. Reversing the order leaves dev
  self-tests missing merval — silently, with no error from `task` itself.
  End-user installs via `lola install` directly are *expected* to hit
  `MERVAL_NOT_INSTALLED` on first `/diagram-test`; dev self-tests are not.
- **`SCOPE`** (`user` default, also accepts `project`) controls
  `lola install --scope`. `task uninstall` ignores it — `lola mod rm -f`
  is a total teardown across every scope plus registry deregistration.
