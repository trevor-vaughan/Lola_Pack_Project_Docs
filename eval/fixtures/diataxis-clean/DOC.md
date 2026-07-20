# How to rotate your signing key

Rotate a compromised or expiring signing key without downtime.

1. Generate the replacement: `app key rotate --kdf pbkdf2`.
2. Publish the new public key alongside the old one for the overlap window.
3. Re-sign the index: `app repo build`.
4. After all clients have the new key, remove the old one: `app key prune`.

If a step fails, `app key status` shows which keys are currently trusted.
