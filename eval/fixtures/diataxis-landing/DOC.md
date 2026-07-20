# app

`app` keeps your packages in sync across machines, declaratively.

## Install

```
brew install app
```

## Quickstart

```
app init
app add hello
app sync
```

## How it works

Each sync creates an immutable generation, so you can roll back with one command.
This is the same content-addressed model git uses for commits.

## Commands

| Command | Description |
|---|---|
| `init` | create a profile |
| `add` | add a package |
| `sync` | apply the profile |
