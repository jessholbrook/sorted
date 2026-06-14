#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/SortedDerivedData}"
ARCHIVE_DAY="$(date +%Y-%m-%d)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$HOME/Library/Developer/Xcode/Archives/$ARCHIVE_DAY/Sorted.xcarchive}"

cd "$ROOT"
mkdir -p "$ROOT/dist"
xattr -cr "$ROOT/Sources" "$ROOT/Xcode" "$ROOT/assets" "$ROOT/Packaging" 2>/dev/null || true

"$ROOT/scripts/generate-xcode-project.sh"

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
    -project Sorted.xcodeproj \
    -scheme Sorted \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    clean archive

printf 'Archived %s\n' "$ARCHIVE_PATH"
printf 'Open Xcode Organizer to validate and upload the archive to App Store Connect.\n'
