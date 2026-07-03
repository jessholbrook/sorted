import AppKit
import ApplicationServices
import SortedCore

@MainActor
final class WindowManager {
    struct Window {
        let element: AXUIElement
        let ownerName: String
        let ownerPID: pid_t
    }

    func groupByApp() throws {
        let windows = try movableWindows()
        // Group by PID so two apps sharing a display name stay separate.
        let groups = Dictionary(grouping: windows, by: \.ownerPID)
            .values
            .sorted { lhs, rhs in
                let comparison = lhs[0].ownerName.localizedCaseInsensitiveCompare(rhs[0].ownerName)
                guard comparison == .orderedSame else { return comparison == .orderedAscending }
                return lhs[0].ownerPID < rhs[0].ownerPID
            }
        let layouts = LayoutEngine.grouped(
            groupSizes: groups.map(\.count),
            in: targetFrame()
        )

        for (group, frames) in zip(groups, layouts) {
            for (window, frame) in zip(group, frames) {
                set(window: window, frame: frame)
            }
        }
    }

    func tileFrontmostApp() throws {
        try requireAccessibilityPermission()
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw SortedError.noFrontmostApp
        }

        let windows = windows(for: app)
        guard !windows.isEmpty else { throw SortedError.noFrontmostApp }

        for (window, frame) in zip(windows, LayoutEngine.grid(count: windows.count, in: targetFrame())) {
            set(window: window, frame: frame)
        }
    }

    func cascadeAll() throws {
        let windows = try movableWindows()
        let frames = LayoutEngine.cascade(count: windows.count, in: targetFrame().insetBy(dx: 24, dy: 24))

        for (window, frame) in zip(windows, frames) {
            set(window: window, frame: frame)
        }
    }

    private func movableWindows() throws -> [Window] {
        try requireAccessibilityPermission()

        let windows = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .flatMap(windows(for:))

        guard !windows.isEmpty else { throw SortedError.noWindowsFound }
        return windows
    }

    private func windows(for application: NSRunningApplication) -> [Window] {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let elements: [AXUIElement] = appElement.attribute(kAXWindowsAttribute) else {
            return []
        }

        return elements.compactMap { element in
            let minimized: Bool = element.attribute(kAXMinimizedAttribute) ?? false
            let role: String = element.attribute(kAXRoleAttribute) ?? ""
            let subrole: String = element.attribute(kAXSubroleAttribute) ?? ""
            let size: CGSize? = element.attribute(kAXSizeAttribute, as: .cgSize)

            guard !minimized,
                  role == kAXWindowRole,
                  subrole != kAXUnknownSubrole,
                  let size,
                  size.width >= 120,
                  size.height >= 80 else {
                return nil
            }

            return Window(
                element: element,
                ownerName: application.localizedName ?? "Unknown App",
                ownerPID: application.processIdentifier
            )
        }
    }

    private func targetFrame() -> CGRect {
        guard let screen = NSScreen.main else {
            return CGRect(x: 0, y: 0, width: 1440, height: 900)
        }

        // Accessibility uses a top-left origin while AppKit uses a bottom-left origin.
        let visibleFrame = screen.visibleFrame
        return CGRect(
            x: visibleFrame.minX,
            y: screen.frame.maxY - visibleFrame.maxY,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }

    private func set(window: Window, frame: CGRect) {
        var position = frame.origin
        var size = frame.size

        // Position → size → position: apps that constrain the requested size
        // can shift the window while resizing, so re-anchor afterward.
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, sizeValue)
        }
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, positionValue)
        }
    }
}
