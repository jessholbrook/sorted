#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/dist/Sorted.xcarchive}"

cd "$ROOT"
mkdir -p "$ROOT/dist"

"$ROOT/scripts/generate-xcode-project.sh"

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
    -project Sorted.xcodeproj \
    -scheme Sorted \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    clean archive

printf 'Archived %s\n' "$ARCHIVE_PATH"
printf 'Open Xcode Organizer to validate and upload the archive to App Store Connect.\n'
