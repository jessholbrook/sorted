# Distributing Sorted

Sorted supports a reliable direct-distribution path as a Developer ID-signed
and notarized macOS menu-bar app. A Mac App Store build is also worth testing.

## Why Direct Distribution

Mac App Store apps must use App Sandbox. Accessibility-based window utilities
can be distributed through the store, but Sorted's Dock-specific synthetic drag
behavior still needs to be validated in a sandboxed Xcode build and explained
clearly to App Review.

Direct distribution still provides the standard macOS trust experience:

- A normal `Sorted.app` bundle
- Stable Accessibility permission across consistently signed releases
- Developer ID code signing
- Hardened Runtime
- Apple notarization and stapling
- A downloadable ZIP suitable for GitHub Releases or a website

## Prerequisites

1. Install the current full Xcode release and select it:

   ```sh
   sudo xcode-select --switch /Applications/Xcode.app
   ```

2. Join the Apple Developer Program.
3. Create and install a **Developer ID Application** certificate.
4. Confirm the signing identity:

   ```sh
   security find-identity -v -p codesigning
   ```

## Build a Local App

An ad-hoc signed app is useful for local testing:

```sh
sh scripts/build-app.sh
```

The result is `dist/Sorted.app`.

## Build a Developer ID Release

Use the exact certificate name shown by `security find-identity`:

```sh
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
MARKETING_VERSION="0.1.0" \
BUILD_VERSION="1" \
sh scripts/package-release.sh
```

This creates `dist/Sorted-0.1.0.zip`.

## Configure Notarization

Create an app-specific password for the Apple Account attached to the Developer
Program, then store a reusable notarytool profile:

```sh
xcrun notarytool store-credentials "sorted-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "APP-SPECIFIC-PASSWORD"
```

## Notarize

After packaging a Developer ID-signed release:

```sh
NOTARY_PROFILE="sorted-notary" \
MARKETING_VERSION="0.1.0" \
sh scripts/notarize-release.sh
```

The script submits the ZIP, waits for Apple, staples the ticket to
`Sorted.app`, validates it, and recreates the final ZIP.

## Verify Before Publishing

```sh
codesign --verify --deep --strict --verbose=2 dist/Sorted.app
spctl --assess --type execute --verbose=4 dist/Sorted.app
xcrun stapler validate dist/Sorted.app
```

Test the final ZIP on a second Mac or a clean macOS user account before
publishing it.

## Mac App Store Path

An App Store build would require:

1. A full Xcode app target and App Store provisioning profile.
2. App Sandbox enabled.
3. Validation that Accessibility inspection and synthetic Dock drags still
   work in the sandbox.
4. Accurate App Review notes explaining the cross-app behavior.
5. App Store screenshots, privacy answers, support URL, and review submission.

The key validation is whether the Dock sorter continues to work after enabling
App Sandbox. If it does, submit a clear review note explaining that Sorted only
performs drag events in direct response to the user's menu command. Keep the
Developer ID release path available in case the Dock-specific behavior does not
pass review.
