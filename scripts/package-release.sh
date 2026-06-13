#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
ZIP_PATH="$ROOT/dist/Sorted-$MARKETING_VERSION.zip"

"$ROOT/scripts/build-app.sh"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$ROOT/dist/Sorted.app" "$ZIP_PATH"

printf 'Packaged %s\n' "$ZIP_PATH"
