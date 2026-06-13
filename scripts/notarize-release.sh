#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
NOTARY_PROFILE="${NOTARY_PROFILE:?Set NOTARY_PROFILE to an xcrun notarytool keychain profile.}"
ZIP_PATH="$ROOT/dist/Sorted-$MARKETING_VERSION.zip"
APP_PATH="$ROOT/dist/Sorted.app"

test -f "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
printf 'Notarized and packaged %s\n' "$ZIP_PATH"
