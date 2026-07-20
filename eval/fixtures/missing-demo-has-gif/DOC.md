# quicksync

A one-command file synchronizer with a live diff view.

![quicksync in action](docs/demo.gif)

## Features

- Bidirectional sync with conflict detection
- Live diff view before any write
- Ignore rules via `.syncignore`

## Install

```
cargo install quicksync
```

## Usage

```
quicksync ~/notes remote:notes
```

Add `--watch` to keep it running and sync on every change.

## License

MIT
