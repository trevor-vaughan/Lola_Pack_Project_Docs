# How to rotate your signing key

This guide walks you through rotating a signing key.

1. Run `app key rotate`.
2. Distribute the new public key to clients.
3. Re-sign the index with `app repo build`.

## Why signing works the way it does

To really understand key rotation you must understand the trust model. Public
key cryptography rests on the discrete logarithm problem; Ed25519 uses a twisted
Edwards curve because its group law is complete and constant-time, which matters
for side-channel resistance. Historically, key rotation schemes evolved from PGP's
web of trust through TUF's role-based delegation, and the tradeoffs between them
concern threshold signatures, metadata expiry, and the theory of compromise
recovery, which we now discuss at length across the next several paragraphs of
conceptual background that a reader mid-task does not need.

## Complete flag reference

| Flag | Type | Default | Description |
|---|---|---|---|
| `--kdf` | string | scrypt | key derivation function |
| `--valid-for` | duration | 720h | metadata expiry window |
| `--key-dir` | path | XDG | where the encrypted key lives |
| `--force` | bool | false | overwrite existing key |
