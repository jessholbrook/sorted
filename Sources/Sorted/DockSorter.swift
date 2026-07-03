import AppKit
import ApplicationServices

/// Reorders minimized-window thumbnails in the Dock by synthesizing drag
/// input. Sorting runs off the main actor with async waits so the app stays
/// responsive, and it can be cancelled between moves.
final class DockSorter: Sendable {
    struct RunningApp: Sendable {
        let pid: pid_t
        let name: String
    }

    /// Main-actor state captured before the sort starts, so the sort itself
    /// never has to touch main-actor-bound AppKit API (NSScreen, NSWorkspace).
    struct Context: Sendable {
        let dockPID: pid_t
        /// Screen frames already converted to the Accessibility coordinate
        /// space (top-left origin).
        let screenFrames: [CGRect]
        let applications: [RunningApp]
    }

    private struct DockItem {
        let title: String
        let frame: CGRect
        let ownerName: String

        var center: CGPoint {
            CGPoint(x: frame.midX, y: frame.midY)
        }
    }

    func groupMinimizedWindowsByApp(context: Context) async throws {
        try requireAccessibilityPermission()
        guard !dockWindowGroupingEnabled else {
            throw SortedError.minimizeIntoApplicationEnabled
        }

        var items = try minimizedDockItems(context: context)
        guard items.count > 1 else { throw SortedError.noMinimizedWindows }
        guard items.allSatisfy({ isVisible($0, on: context.screenFrames) }) else {
            throw SortedError.dockMustBeVisible
        }

        let originalPointerLocation = CGEvent(source: nil)?.location
        defer {
            if let originalPointerLocation {
                CGWarpMouseCursorPosition(originalPointerLocation)
            }
        }

        var attemptsRemaining = items.count * items.count * 3
        var consecutiveRejectedMoves = 0

        while attemptsRemaining > 0 {
            try Task.checkCancellation()

            items = try minimizedDockItems(context: context)
            let currentOwners = items.map(\.ownerName)
            // Recompute the target order every pass so windows minimized or
            // restored mid-sort change the goal instead of leaving the two
            // arrays with mismatched lengths.
            let desiredOwners = groupedOrder(of: currentOwners)
            guard currentOwners != desiredOwners else { return }
            guard let targetIndex = currentOwners.indices.first(where: {
                currentOwners[$0] != desiredOwners[$0]
            }),
            let sourceIndex = currentOwners[targetIndex...].firstIndex(of: desiredOwners[targetIndex]) else {
                break
            }

            let before = currentOwners
            let destination = insertionPoint(before: items[targetIndex], in: items)

            try await drag(from: items[sourceIndex].center, to: destination)
            await sleep(seconds: 0.32)

            var afterItems = try minimizedDockItems(context: context)
            var after = afterItems.map(\.ownerName)
            if after == before, sourceIndex > targetIndex, sourceIndex < afterItems.count {
                let adjacentDestination = insertionPoint(
                    before: afterItems[sourceIndex - 1],
                    in: afterItems
                )
                try await drag(from: afterItems[sourceIndex].center, to: adjacentDestination)
                await sleep(seconds: 0.32)
                afterItems = try minimizedDockItems(context: context)
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

        let remaining = groupingMovesRemaining(in: try minimizedDockItems(context: context))
        if remaining > 0 {
            throw SortedError.partiallySorted(remaining: remaining)
        }
    }

    private var dockWindowGroupingEnabled: Bool {
        UserDefaults(suiteName: "com.apple.dock")?.bool(forKey: "minimize-to-application") ?? false
    }

    /// Groups each owner's entries together at the position of the owner's
    /// first appearance, preserving order within groups.
    private func groupedOrder(of owners: [String]) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []

        for owner in owners {
            if counts[owner] == nil {
                order.append(owner)
            }
            counts[owner, default: 0] += 1
        }

        return order.flatMap { Array(repeating: $0, count: counts[$0] ?? 0) }
    }

    private func minimizedDockItems(context: Context) throws -> [DockItem] {
        let ownersByTitle = minimizedWindowOwners(in: context.applications)
        let dockElement = AXUIElementCreateApplication(context.dockPID)
        let elements = descendants(of: dockElement)

        let items = elements.compactMap { element -> DockItem? in
            let subrole: String = element.attribute(kAXSubroleAttribute) ?? ""
            guard subrole == kAXMinimizedWindowDockItemSubrole else { return nil }

            let title: String = element.attribute(kAXTitleAttribute)
                ?? element.attribute(kAXDescriptionAttribute)
                ?? "Untitled"
            guard let position: CGPoint = element.attribute(kAXPositionAttribute, as: .cgPoint),
                  let size: CGSize = element.attribute(kAXSizeAttribute, as: .cgSize) else {
                return nil
            }

            // Thumbnails whose owning app can't be determined unambiguously
            // are left in place rather than guessed at and mis-grouped.
            guard let owner = owner(forDockItemTitled: title, in: ownersByTitle) else {
                return nil
            }

            return DockItem(
                title: title,
                frame: CGRect(origin: position, size: size),
                ownerName: owner
            )
        }

        return items.sorted(by: visualOrder)
    }

    private func minimizedWindowOwners(in applications: [RunningApp]) -> [String: Set<String>] {
        var owners: [String: Set<String>] = [:]

        for application in applications {
            let appElement = AXUIElementCreateApplication(application.pid)
            let windows: [AXUIElement] = appElement.attribute(kAXWindowsAttribute) ?? []

            for window in windows {
                let minimized: Bool = window.attribute(kAXMinimizedAttribute) ?? false
                let title: String = window.attribute(kAXTitleAttribute) ?? ""
                if minimized && !title.isEmpty {
                    owners[title, default: []].insert(application.name)
                }
            }
        }

        return owners
    }

    private func owner(forDockItemTitled title: String, in ownersByTitle: [String: Set<String>]) -> String? {
        if let exact = ownersByTitle[title] {
            return exact.count == 1 ? exact.first : nil
        }

        let fuzzyCandidates = Set(
            ownersByTitle
                .filter { title.contains($0.key) || $0.key.contains(title) }
                .flatMap(\.value)
        )
        return fuzzyCandidates.count == 1 ? fuzzyCandidates.first : nil
    }

    private func descendants(of root: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue: [AXUIElement] = [root]

        while !queue.isEmpty {
            let element = queue.removeFirst()
            let children: [AXUIElement] = element.attribute(kAXChildrenAttribute) ?? []
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

    private func insertionPoint(before target: DockItem, in items: [DockItem]) -> CGPoint {
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
        let xs = items.map(\.frame.midX)
        let ys = items.map(\.frame.midY)
        let xSpread = (xs.max() ?? 0) - (xs.min() ?? 0)
        let ySpread = (ys.max() ?? 0) - (ys.min() ?? 0)
        return xSpread >= ySpread || items.allSatisfy { abs($0.frame.midY - first.frame.midY) < first.frame.height }
    }

    private func isVisible(_ item: DockItem, on screenFrames: [CGRect]) -> Bool {
        screenFrames.contains { $0.intersects(item.frame) }
    }

    private func drag(from start: CGPoint, to end: CGPoint) async throws {
        guard let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: start, mouseButton: .left),
              let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left) else {
            throw SortedError.partiallySorted(remaining: 1)
        }

        // Once the button is down the sequence must run to the mouse-up —
        // aborting mid-drag would leave a phantom pressed button — so the
        // waits here ignore cancellation; the sort loop checks between moves.
        move.post(tap: .cghidEventTap)
        await sleep(seconds: 0.06)
        down.post(tap: .cghidEventTap)
        await sleep(seconds: 0.16)

        for step in 1...8 {
            let progress = CGFloat(step) / 8
            let point = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            guard let dragEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: point,
                mouseButton: .left
            ) else {
                up.post(tap: .cghidEventTap)
                throw SortedError.partiallySorted(remaining: 1)
            }
            dragEvent.post(tap: .cghidEventTap)
            await sleep(seconds: 0.02)
        }

        await sleep(seconds: 0.1)
        up.post(tap: .cghidEventTap)
    }

    private func sleep(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
