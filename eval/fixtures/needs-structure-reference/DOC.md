# Retry semantics

This document explains how the client decides whether and when to retry a failed
request. It is background for understanding the knobs in `RetryPolicy`; it is not
a step-by-step procedure.

## Classification

A request outcome is classified before any retry decision is made. The transport
distinguishes three families: a connection-level failure (the request never
reached the server, e.g. DNS resolution failed, the TCP handshake was refused, or
the socket was reset before any response byte arrived), a response-level failure
that the server itself reports (any `5xx`, plus `429 Too Many Requests`), and a
terminal outcome that is never retried (any `4xx` other than `429`, because those
signal a defect in the request that a retry cannot fix). Connection-level and
response-level failures are the only two families eligible for a retry; a
terminal outcome short-circuits the whole policy and surfaces immediately to the
caller with the original status attached.

## Backoff

For an eligible failure the client waits before retrying, and the wait grows with
each successive attempt. The base delay is 100ms and each attempt multiplies the
previous delay by a factor of two, so the nominal schedule is 100ms, 200ms,
400ms, and so on up to a ceiling of 30 seconds, beyond which the delay is clamped.
Full jitter is then applied: the actual wait is a uniform random value between
zero and the nominal delay, which spreads a thundering herd of clients that all
failed at the same instant across the whole interval rather than having them all
wake and retry in lockstep. A `429` carrying a `Retry-After` header is a special
case — the header value overrides the computed backoff entirely, because the
server has told us exactly how long to wait and second-guessing it only makes the
overload worse.

## Budget

Retries are bounded twice over, by count and by time. The count bound is the
`MaxAttempts` field and includes the original attempt, so `MaxAttempts: 3` means
one try plus two retries. The time bound is the request context deadline: if the
next computed backoff would sleep past the caller's deadline, the client does not
sleep and does not retry — it returns the last error immediately, because burning
the caller's remaining budget on a sleep it cannot afford helps no one.
