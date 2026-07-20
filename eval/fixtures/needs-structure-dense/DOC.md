# Setting up the Ledger service locally

This guide gets the Ledger service running against a local Postgres so you can
develop against it.

## Bring up the environment

First make sure you have Go 1.22 and Podman installed, then clone the repository
and change into it with `git clone https://github.com/acme/ledger && cd ledger`,
which drops you at the project root where the `Taskfile.yml` lives. Now start the
database — the compose file ships a pinned Postgres 16 image, so run
`podman-compose up -d db` and wait a few seconds for the container to report
healthy; you can confirm it is up with `podman ps` and looking for the `ledger-db`
row in the STATUS column showing `healthy`. With the database live you need to
apply the schema, and migrations are handled by the `migrate` task, so run
`task db:migrate` which walks every file under `migrations/` in order and stops on
the first error. Once the schema is in place, seed a development tenant by running
`task db:seed TENANT=dev`, which inserts an admin user and an API key printed to
stdout — copy that key, you will need it in a moment. Export the key so the
service picks it up on boot with `export LEDGER_API_KEY=<the key you copied>` and
then finally start the service itself in watch mode with `task dev`, which
compiles the binary, runs it, and rebuilds on every save. When it prints
`listening on :8080` you are ready, and you can smoke-test the whole thing from
another terminal with `curl -H "Authorization: Bearer $LEDGER_API_KEY"
localhost:8080/v1/health` which should return `{"status":"ok"}`.

## What you have now

A running Ledger service in watch mode, backed by a seeded local Postgres,
reachable on port 8080 with the API key you exported.
