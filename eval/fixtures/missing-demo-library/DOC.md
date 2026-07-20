# retry-go

A small, generic retry library for Go with pluggable backoff and jitter.

## Install

```
go get github.com/acme/retry-go
```

## Usage

Wrap any fallible call. The library retries on the errors you mark retryable and
backs off between attempts:

```go
err := retry.Do(ctx, func() error {
    return callFlakyAPI()
}, retry.WithMaxAttempts(3), retry.WithBackoff(retry.Exponential(100*time.Millisecond)))
if err != nil {
    log.Fatal(err)
}
```

Classify which errors are worth retrying with `retry.RetryIf`:

```go
retry.Do(ctx, fn, retry.RetryIf(func(err error) bool {
    return errors.Is(err, io.ErrUnexpectedEOF)
}))
```

## License

BSD-3-Clause
