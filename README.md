# Sorted

![Sorted groups scattered minimized Dock windows into contiguous app groups](assets/sorted-hero.png)

**Sorted** is a small native macOS menu-bar utility for arranging open windows
and grouping minimized Dock thumbnails by app.

macOS can place minimized windows individually in the Dock, but it does not
provide a built-in way to regroup those thumbnails later. Sorted fills that
gap with a one-click, live Dock sorter.

## Features

- **Group Minimized Windows in Dock** makes each app's minimized thumbnails
  contiguous while preserving their existing order.
- **Group Windows by App** places visible windows from each app together.
- **Tile Frontmost App** fills the main display with the active app's windows.
- **Cascade All Windows** creates an easy-to-scan stack.
- Runs entirely as a menu-bar utility with no Dock icon.
- Performs all work locally. No analytics, network requests, or cloud services.

## How Dock Sorting Works

Apple does not expose a supported API for changing minimized-thumbnail order.
Sorted uses the macOS Accessibility API to identify Dock thumbnails and their
owning apps, then performs verified drag moves to group them.

Because the Dock only accepts reordering through drag input:

- Sorted briefly uses the pointer while sorting.
- The pointer returns to its original position afterward.
- The Dock must be visible.
- **Minimize windows into application icon** must be turned off.
- A second click may occasionally be needed if the Dock rejects a move.

## Requirements

- macOS 13 or later
- Accessibility permission for Sorted
- Swift 6-compatible toolchain to build from source

## Run From Source

Clone the repository, then run:

```sh
sh run.sh
```

The first arrangement action prompts for Accessibility access. Enable Sorted
under:

**System Settings → Privacy & Security → Accessibility**

For live Dock sorting, also turn off:

**System Settings → Desktop & Dock → Minimize windows into application icon**

## Use

1. Minimize several windows from multiple apps so their thumbnails appear in
   the Dock.
2. Keep the Dock visible.
3. Click the Sorted menu-bar icon.
4. Select **Group Minimized Windows in Dock**.

Sorted groups each app's thumbnails together based on the first appearance of
that app. It preserves thumbnail order within each group and avoids moving
windows that are already grouped.

## Verify

Build the app:

```sh
HOME="$PWD/.local-home" \
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" \
swift build
```

Run the layout checks:

```sh
HOME="$PWD/.local-home" \
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" \
swift run SortedChecks
```

The explicit SDK path works around a compiler/SDK patch mismatch on the machine
where Sorted was created. With a matching Xcode installation, regular
`swift build` and `swift run SortedChecks` commands should work.

## Project Structure

```text
Sources/
  Sorted/        Menu-bar app, Accessibility integration, and Dock sorting
  SortedCore/    Testable window-layout geometry
  SortedChecks/  Standalone layout verification
```

## Known Limitations

- Dock sorting depends on Accessibility behavior that may change between macOS
  releases.
- Some apps opt out of Accessibility window movement.
- Some fixed-size windows may reject requested sizes.
- Visible-window arrangements currently target the main display.
- Sorted currently runs from source rather than as a signed downloadable app.

## Privacy

Sorted inspects window titles and positions through macOS Accessibility solely
to perform the requested local arrangement. It does not store or transmit that
information.

## Contributing

Issues and pull requests are welcome. Useful areas for improvement include
multi-display layouts, configurable grouping rules, keyboard shortcuts, and a
signed `.app` release workflow.

## License

Sorted is available under the [MIT License](LICENSE).
