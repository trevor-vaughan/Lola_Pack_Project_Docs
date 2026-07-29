---
name: x
description: DO NOT AUTO-INVOKE. This skill runs only via its /x command wrapper; activating it without that explicit trigger is a usage error.
---

# An explicit fixture skill missing its command wrapper

This skill's description begins with `DO NOT AUTO-INVOKE.`, marking it as
explicit-only. It deliberately has no `module/commands/x.md` wrapper, so it
exercises the linter's "explicit skill without a command wrapper" failure
path.
