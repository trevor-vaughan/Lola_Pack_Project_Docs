# How to rotate your signing key

Rotate a compromised or expiring key without downtime.

**Before you begin:** you need the current key password and publish access to
the repository.

1. Generate the replacement: `app key rotate --kdf pbkdf2`.
2. Publish the new public key alongside the old one for the overlap window.
3. Re-sign the index: `app repo build`.
4. Once `app key status` shows all clients on the new key, remove the old one:
   `app key prune`.

You are done when `app key status` lists only the new key and clients sync
without warnings.
