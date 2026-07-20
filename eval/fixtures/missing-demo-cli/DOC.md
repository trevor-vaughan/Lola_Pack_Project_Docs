# tug

A fast, dependency-free CLI for moving files between S3-compatible buckets with
resumable transfers and a live progress bar.

## Features

- Resumable multipart uploads — interrupt and restart without re-sending bytes
- Parallel transfers with a live per-file progress bar
- Dry-run mode that prints the transfer plan before touching anything
- Works with any S3-compatible endpoint (AWS, MinIO, R2, Backblaze)

## Install

```
go install github.com/acme/tug@latest
```

## Usage

Point `tug` at a source and destination:

```
tug cp s3://source-bucket/logs/ s3://backup-bucket/logs/ --parallel 8
```

Preview first with `--dry-run`, then drop the flag to run it for real. Progress
is printed live and the final line summarizes bytes moved and time taken.

## License

Apache-2.0
