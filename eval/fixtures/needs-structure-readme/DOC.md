# sprocket

A tiny CLI for syncing sprocket inventory between warehouses.

## Features

- One-shot and watch-mode sync
- Dry-run diffing before any write
- Structured JSON logs

## Install

Sprocket is distributed as a single static binary. Grab the latest release for
your platform with `curl -sSL https://get.sprocket.dev/install.sh | sh`, which
drops the binary at `~/.local/bin/sprocket`; make sure that directory is on your
`PATH` or the shell will not find it. Verify the install printed the version you
expect by running `sprocket --version` and checking it matches the release you
pulled. Sprocket needs a config file before it will do anything, so generate a
starter one with `sprocket init`, which writes `~/.config/sprocket/config.yaml`
with commented defaults. Open that file and set `warehouse.token` to your API
token, then confirm the daemon can reach the API with `sprocket auth check`,
which round-trips a request and prints the authenticated account. Finally run
your first sync in dry-run mode with `sprocket sync --dry-run` to see the diff
without writing anything, and when it looks right drop the flag and run
`sprocket sync` for real.

## License

MIT
