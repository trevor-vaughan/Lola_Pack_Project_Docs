#!/usr/bin/env bash
# Swap the palette init header on an existing .mmd file. Strips the
# current init block and any classDef lines, then re-applies via
# apply-palette.mjs against the named palette's JSON.
#
# Usage: swap-palette.sh <palette-name> <path/to/diagram.mmd>
set -euo pipefail

PALETTE="${1:?usage: swap-palette.sh <palette-name> <path/to/diagram.mmd>}"
INPUT="${2:?usage: swap-palette.sh <palette-name> <path/to/diagram.mmd>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PALETTE_DIR="$SCRIPT_DIR/../reference/palettes"
PALETTE_JSON="$PALETTE_DIR/${PALETTE}.json"

if [[ ! -f "$PALETTE_JSON" ]]; then
  AVAILABLE=()
  for p in "$PALETTE_DIR"/*.json; do
    [[ -e "$p" ]] || continue
    AVAILABLE+=("$(basename "$p" .json)")
  done
  echo "unknown palette: $PALETTE — available: $(IFS=,; echo "${AVAILABLE[*]}")" >&2
  exit 2
fi
if [[ ! -f "$INPUT" ]]; then
  echo "file not found: $INPUT" >&2
  exit 2
fi

BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT
awk '/^%%\{init:/,/\}%%/ {next} /^[[:space:]]*classDef[[:space:]]/ {next} {print}' "$INPUT" > "$BODY"
node "$SCRIPT_DIR/apply-palette.mjs" "$PALETTE_JSON" "$BODY"
