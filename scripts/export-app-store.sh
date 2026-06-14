#!/bin/sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ARCHIVE_DAY="$(date +%Y-%m-%d)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$HOME/Library/Developer/Xcode/Archives/$ARCHIVE_DAY/Sorted.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/dist/AppStore}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT/Xcode/ExportOptions-AppStore.plist}"

cd "$ROOT"
mkdir -p "$EXPORT_PATH"

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -allowProvisioningUpdates

printf 'Exported App Store package to %s\n' "$EXPORT_PATH"
