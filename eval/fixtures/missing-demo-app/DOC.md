# lazypods

A terminal UI for managing Kubernetes pods — browse namespaces, tail logs, exec
into containers, and delete stuck pods, all without leaving the keyboard.

## Features

- Vim-style navigation across namespaces, pods, and containers
- Live log tailing with search and filtering
- One-keystroke exec, port-forward, and delete
- Reads your existing `~/.kube/config` — no extra setup

## Install

```
brew install acme/tap/lazypods
```

## Usage

Run `lazypods` in any shell with a configured kube context. Use `j`/`k` to move,
`Enter` to drill in, `l` to tail logs, `s` to shell into a container, and `?` for
the full keymap.

## License

MIT
