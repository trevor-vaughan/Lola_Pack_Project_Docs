# Formatting the codebase

We use `gofumpt` (a stricter `gofmt`) to keep formatting consistent.

## Running the formatter

Install the tool once with `go install mvdan.cc/gofumpt@latest`, then format the
whole tree in place with `gofumpt -w .`. CI runs the same command with `-l` and
fails if anything would change, so run it before you push.
