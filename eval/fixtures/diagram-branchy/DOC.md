# State machine

## Lifecycle

A record begins in `pending`. From `pending` it either advances to `active`
when validation passes, or falls to `rejected` when it fails. An `active`
record can be `suspended` and later resumed back to `active`, or it can expire
to `archived`. A `suspended` record that is not resumed within the window also
expires to `archived`. From `archived` there is no return; a `rejected` record
may be resubmitted, which sends it back to `pending`.
