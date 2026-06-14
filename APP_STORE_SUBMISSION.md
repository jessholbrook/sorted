# Sorted App Store Submission

This document contains draft metadata and the submission checklist for Sorted.

## App Information

- **Name:** Sorted
- **Bundle ID:** `com.jessholbrook.Sorted`
- **Primary category:** Utilities
- **Secondary category:** Productivity
- **Copyright:** 2026 Jess Holbrook
- **Privacy policy:** https://github.com/jessholbrook/sorted/blob/main/PRIVACY.md
- **Support URL:** https://github.com/jessholbrook/sorted/issues
- **Marketing URL:** https://github.com/jessholbrook/sorted

## Subtitle

Group and arrange Mac windows

## Promotional Text

Bring order to your Mac with one-click window arrangements and live grouping
of minimized Dock thumbnails by app.

## Description

Sorted is a focused menu-bar utility for arranging open windows and grouping
minimized Dock thumbnails by app.

macOS can place minimized windows individually in the Dock, but it does not
provide a built-in way to regroup those thumbnails later. Sorted fills that
gap with a live, one-click sorter.

Features:

- Group minimized Dock thumbnails into contiguous app groups
- Preserve the existing order within each app group
- Group visible windows by app
- Tile windows from the frontmost app
- Cascade all visible windows
- Run quietly from the menu bar
- Process everything locally with no analytics or network requests

Sorted requires Accessibility permission to identify and arrange windows. Dock
sorting happens only when you explicitly select the command and briefly uses
the pointer to perform the requested Dock moves.

## Keywords

windows, dock, organize, arrange, tile, minimize, productivity, menu bar

## App Review Notes

Sorted is a menu-bar-only utility, so it does not display a Dock icon or main
window.

To test the primary feature:

1. Open System Settings → Desktop & Dock.
2. Turn off **Minimize windows into application icon**.
3. Minimize multiple windows from at least two apps.
4. Keep the Dock visible.
5. Click the Sorted menu-bar icon.
6. Select **Group Minimized Windows in Dock**.

Sorted uses the macOS Accessibility API to identify minimized Dock thumbnails
and their owning applications. Because the Dock does not expose a reorder API,
Sorted performs verified drag events only after the user explicitly selects
the menu command. The pointer is restored to its original position afterward.

The app makes no network requests and does not retain or transmit window titles
or positions.

## Privacy Answers

- **Data collected:** None
- **Tracking:** No
- **Third-party analytics:** None
- **Third-party advertising:** None
- **Network access:** None

## Screenshots Needed

Mac App Store screenshots should clearly show:

1. Interleaved minimized Dock thumbnails before sorting.
2. Grouped minimized Dock thumbnails after sorting.
3. The Sorted menu-bar menu and available arrangement actions.
4. Accessibility permission setup.

Mac screenshots must use one of the current App Store Connect-supported
resolutions. Capture them on a clean desktop without private window titles or
personal information.

## Submission Checklist

- [x] Xcode app target
- [x] Stable bundle identifier
- [x] App Sandbox enabled
- [x] Hardened Runtime enabled
- [x] Menu-bar-only `LSUIElement` configuration
- [x] App icon asset catalog
- [x] Privacy policy
- [x] Draft App Store metadata and review notes
- [x] Accept the latest Apple Developer Program License Agreement
- [x] Create/download Mac Development and App Store distribution signing assets
- [x] Verify the Dock sorter works in the signed sandboxed build
- [x] Create signed Release archive
- [x] Export App Store package
- [ ] Create the App Store Connect app record
- [ ] Capture App Store screenshots
- [ ] Upload build to App Store Connect
- [ ] Complete pricing, availability, and age rating
- [ ] Submit for App Review
