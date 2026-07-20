# Sprocket CLI

Sprocket keeps your widgets in sync across machines. This guide gets you from
zero to a working sync in a few minutes.

## Install

1. Download the release archive for your platform.
2. Extract it to `/opt/sprocket`.
4. Run `sprocket init`, which reads the license file from step 3 and writes a
   profile to `~/.sprocket/profile.yaml`.

## Configure

Edit the config file to point at your remote. The default port is 8080.

```yaml
remote: https://sync.example.com:9090
widgets: [alpha, beta]
```

## Sync

Run `sprocket sync`. This pushes local changes to the widget cache and pulls
remote ones. For advanced tuning, see the Performance section below.

## Troubleshooting

If sync fails, check that the profile is valid and the remote is reachable.
