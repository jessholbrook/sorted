import AppKit
import ApplicationServices

enum DockSortError: LocalizedError {
    case accessibilityPermissionRequired
    case minimizeIntoApplicationEnabled
    case dockNotFound
    case noMinimizedWindows
    case dockMustBeVisible
    case partiallySorted(remaining: Int)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Accessibility permission is required. Enable Sorted in System Settings → Privacy & Security → Accessibility."
        case .minimizeIntoApplicationEnabled:
            return "“Minimize windows into application icon” is currently enabled. Turn it off in System Settings → Desktop & Dock, then minimize windows as individual Dock thumbnails before sorting."
        case .dockNotFound:
            return "Sorted could not find the Dock."
        case .noMinimizedWindows:
            return "No individual minimized-window thumbnails were found in the Dock."
        case .dockMustBeVisible:
            return "The Dock must be visible while Sorted sorts its minimized windows."
        case .partiallySorted(let remaining):
            return "Sorted grouped most thumbnails, but the Dock rejected \(remaining) remaining move\(remaining == 1 ? "" : "s"). Try the action again to finish."
        }
    }
}

@MainActor
final class DockSorter {
    private struct DockItem {
        let title: String
        let frame: CGRect
        let ownerName: String

        var center: CGPoint {
            CGPoint(x: frame.midX, y: frame.midY)
        }

        var identity: String {
            "\(ownerName)\u{1f}\(title)"
        }
    }

    func groupMinimizedWindowsByApp() throws {
        try requirePermission()
        guard !dockWindowGroupingEnabled else {
            throw DockSortError.minimizeIntoApplicationEnabled
        }

        var items = try minimizedDockItems()
        guard items.count > 1 else { throw DockSortError.noMinimizedWindows }
        guard items.allSatisfy(isVisible(_:)) else { throw DockSortError.dockMustBeVisible }

        let originalPointerLocation = CGEvent(source: nil)?.location
        defer {
            if let originalPointerLocation {
                CGWarpMouseCursorPosition(originalPointerLocation)
            }
        }

        let appOrder = items.reduce(into: [String]()) { order, item in
            if !order.contains(item.ownerName) {
                order.append(item.ownerName)
            }
        }
        let desiredOwners = appOrder.flatMap { owner in
            items.lazy.filter { $0.ownerName == owner }.map(\.ownerName)
        }
        var attemptsRemaining = items.count * items.count * 3
        var consecutiveRejectedMoves = 0

        while attemptsRemaining > 0 {
            items = try minimizedDockItems()
            let currentOwners = items.map(\.ownerName)
            guard currentOwners != desiredOwners else { return }
            guard let targetIndex = currentOwners.indices.first(where: {
                currentOwners[$0] != desiredOwners[$0]
            }),
            let sourceIndex = currentOwners[targetIndex...].firstIndex(of: desiredOwners[targetIndex]) else {
                break
            }

            let before = currentOwners
            let destination = insertionPoint(
                before: items[targetIndex],
                moving: items[sourceIndex],
                in: items
            )

            try drag(from: items[sourceIndex].center, to: destination)
            Thread.sleep(forTimeInterval: 0.32)

            var afterItems = try minimizedDockItems()
            var after = afterItems.map(\.ownerName)
            if after == before, sourceIndex > targetIndex, sourceIndex < afterItems.count {
                let adjacentTarget = afterItems[sourceIndex - 1]
                let adjacentDestination = insertionPoint(
                    before: adjacentTarget,
                    moving: afterItems[sourceIndex],
                    in: afterItems
                )
                try drag(from: afterItems[sourceIndex].center, to: adjacentDestination)
                Thread.sleep(forTimeInterval: 0.32)
                afterItems = try minimizedDockItems()
                after = afterItems.map(\.ownerName)
            }

            if after == before {
                consecutiveRejectedMoves += 1
            } else {
                consecutiveRejectedMoves = 0
            }

            if consecutiveRejectedMoves >= 3 {
                break
            }
            attemptsRemaining -= 1
        }

        let remainingItems = try minimizedDockItems()
        let remaining = groupingMovesRemaining(in: remainingItems)
        if remaining > 0 {
            throw DockSortError.partiallySorted(remaining: remaining)
        }
    }

    private var dockWindowGroupingEnabled: Bool {
        UserDefaults(suiteName: "com.apple.dock")?.bool(forKey: "minimize-to-application") ?? false
    }

    private func minimizedDockItems() throws -> [DockItem] {
        guard let dock = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock"
        }) else {
            throw DockSortError.dockNotFound
        }

        let ownerByTitle = minimizedWindowOwners()
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        let elements = descendants(of: dockElement)

        let items = elements.compactMap { element -> DockItem? in
            let subrole: String = value(of: kAXSubroleAttribute, from: element) ?? ""
            guard subrole == kAXMinimizedWindowDockItemSubrole else { return nil }

            let title: String = value(of: kAXTitleAttribute, from: element)
                ?? value(of: kAXDescriptionAttribute, from: element)
                ?? "Untitled"
            guard let position: CGPoint = axValue(of: kAXPositionAttribute, from: element, as: .cgPoint),
                  let size: CGSize = axValue(of: kAXSizeAttribute, from: element, as: .cgSize) else {
                return nil
            }

            let owner = ownerByTitle[title]
                ?? ownerByTitle.first(where: { title.contains($0.key) || $0.key.contains(title) })?.value
                ?? "Unknown App"
            return DockItem(
                title: title,
                frame: CGRect(origin: position, size: size),
                ownerName: owner
            )
        }

        return items.sorted(by: visualOrder)
    }

    private func minimizedWindowOwners() -> [String: String] {
        var owners: [String: String] = [:]

        for application in NSWorkspace.shared.runningApplications where application.activationPolicy == .regular {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            let windows: [AXUIElement] = value(of: kAXWindowsAttribute, from: appElement) ?? []

            for window in windows {
                let minimized: Bool = value(of: kAXMinimizedAttribute, from: window) ?? false
                let title: String = value(of: kAXTitleAttribute, from: window) ?? ""
                if minimized && !title.isEmpty {
                    owners[title] = application.localizedName ?? "Unknown App"
                }
            }
        }

        return owners
    }

    private func descendants(of root: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue: [AXUIElement] = [root]

        while !queue.isEmpty {
            let element = queue.removeFirst()
            let children: [AXUIElement] = value(of: kAXChildrenAttribute, from: element) ?? []
            result.append(contentsOf: children)
            queue.append(contentsOf: children)
        }

        return result
    }

    private func visualOrder(_ left: DockItem, _ right: DockItem) -> Bool {
        isHorizontalDock([left, right])
            ? left.frame.midX < right.frame.midX
            : left.frame.midY < right.frame.midY
    }

    private func groupingMovesRemaining(in items: [DockItem]) -> Int {
        var completedOwners = Set<String>()
        var currentOwner: String?
        var separatedItems = 0

        for item in items {
            if item.ownerName != currentOwner {
                if let currentOwner {
                    completedOwners.insert(currentOwner)
                }
                currentOwner = item.ownerName
            }
            if completedOwners.contains(item.ownerName) {
                separatedItems += 1
            }
        }
        return separatedItems
    }

    private func insertionPoint(before target: DockItem, moving: DockItem, in items: [DockItem]) -> CGPoint {
        if isHorizontalDock(items) {
            return CGPoint(
                x: target.frame.minX + min(3, target.frame.width * 0.1),
                y: target.frame.midY
            )
        }
        return CGPoint(
            x: target.frame.midX,
            y: target.frame.minY + min(3, target.frame.height * 0.1)
        )
    }

    private func isHorizontalDock(_ items: [DockItem]) -> Bool {
        guard let first = items.first else { return true }
        let xSpread = items.map(\.frame.midX).max()! - items.map(\.frame.midX).min()!
        let ySpread = items.map(\.frame.midY).max()! - items.map(\.frame.midY).min()!
        return xSpread >= ySpread || items.allSatisfy { abs($0.frame.midY - first.frame.midY) < first.frame.height }
    }

    private func isVisible(_ item: DockItem) -> Bool {
        NSScreen.screens.contains { screen in
            let axScreenFrame = CGRect(
                x: screen.frame.minX,
                y: NSScreen.screens.map(\.frame.maxY).max()! - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return axScreenFrame.intersects(item.frame)
        }
    }

    private func drag(from start: CGPoint, to end: CGPoint) throws {
        guard let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: start, mouseButton: .left),
              let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left) else {
            throw DockSortError.partiallySorted(remaining: 1)
        }

        move.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.06)
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.16)

        for step in 1...8 {
            let progress = CGFloat(step) / 8
            let point = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            guard let drag = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: point,
                mouseButton: .left
            ) else {
                throw DockSortError.partiallySorted(remaining: 1)
            }
            drag.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.02)
        }

        Thread.sleep(forTimeInterval: 0.1)
        up.post(tap: .cghidEventTap)
    }

    private func requirePermission() throws {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            throw DockSortError.accessibilityPermissionRequired
        }
    }

    private func value<T>(of attribute: String, from element: AXUIElement) -> T? {
        var rawValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue)
        guard result == .success else { return nil }
        return rawValue as? T
    }

    private func axValue<T>(
        of attribute: String,
        from element: AXUIElement,
        as type: AXValueType
    ) -> T? {
        guard let rawValue: AXValue = value(of: attribute, from: element),
              AXValueGetType(rawValue) == type else {
            return nil
        }

        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AXValueGetValue(rawValue, type, pointer) else { return nil }
        return pointer.pointee
    }
}
