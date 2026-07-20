# Setting up the Ledger service locally

This guide gets the Ledger service running against a local Postgres so you can
develop against it.

## Prerequisites

- Go 1.22
- Podman (with `podman-compose`)

## Bring up the environment

1. **Clone and enter the repo.** This drops you at the project root where
   `Taskfile.yml` lives.

   ```
   git clone https://github.com/acme/ledger && cd ledger
   ```

2. **Start the database.** The compose file ships a pinned Postgres 16 image.
   Wait for the `ledger-db` row in `podman ps` to show `healthy`.

   ```
   podman-compose up -d db
   ```

3. **Apply the schema.** The `migrate` task walks every file under `migrations/`
   in order and stops on the first error.

   ```
   task db:migrate
   ```

4. **Seed a development tenant.** This inserts an admin user and prints an API
   key to stdout — copy it.

   ```
   task db:seed TENANT=dev
   ```

5. **Export the key and start the service.** `task dev` compiles, runs, and
   rebuilds on every save. Wait for `listening on :8080`.

   ```
   export LEDGER_API_KEY=<the key you copied>
   task dev
   ```

## Verify

From another terminal:

```
curl -H "Authorization: Bearer $LEDGER_API_KEY" localhost:8080/v1/health
```

It should return `{"status":"ok"}`.
