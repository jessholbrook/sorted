import AppKit
import ApplicationServices
import SortedCore

enum SortedError: LocalizedError {
    case accessibilityPermissionRequired
    case noWindowsFound
    case noFrontmostApp
    case dockSettingFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Accessibility permission is required. Enable Sorted in System Settings → Privacy & Security → Accessibility."
        case .noWindowsFound:
            return "No movable windows were found."
        case .noFrontmostApp:
            return "The frontmost app has no movable windows."
        case .dockSettingFailed:
            return "The Dock setting could not be changed."
        }
    }
}

@MainActor
final class WindowManager {
    struct Window {
        let element: AXUIElement
        let ownerName: String
        let ownerPID: pid_t
        let title: String
    }

    func groupByApp() throws {
        let windows = try movableWindows()
        let groups = Dictionary(grouping: windows, by: \.ownerName)
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        let layouts = LayoutEngine.grouped(
            groupSizes: groups.map(\.value.count),
            in: targetFrame()
        )

        for (group, frames) in zip(groups, layouts) {
            for (window, frame) in zip(group.value, frames) {
                set(window: window, frame: frame)
            }
        }
    }

    func tileFrontmostApp() throws {
        try requirePermission()
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

    private func requirePermission() throws {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            throw SortedError.accessibilityPermissionRequired
        }
    }

    private func movableWindows() throws -> [Window] {
        try requirePermission()

        let windows = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .flatMap(windows(for:))

        guard !windows.isEmpty else { throw SortedError.noWindowsFound }
        return windows
    }

    private func windows(for application: NSRunningApplication) -> [Window] {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let elements: [AXUIElement] = value(of: kAXWindowsAttribute, from: appElement) else {
            return []
        }

        return elements.compactMap { element in
            let minimized: Bool = value(of: kAXMinimizedAttribute, from: element) ?? false
            let role: String = value(of: kAXRoleAttribute, from: element) ?? ""
            let subrole: String = value(of: kAXSubroleAttribute, from: element) ?? ""
            let title: String = value(of: kAXTitleAttribute, from: element) ?? "Untitled"
            let size: CGSize? = axValue(of: kAXSizeAttribute, from: element, as: .cgSize)

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
                ownerPID: application.processIdentifier,
                title: title
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

        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, sizeValue)
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
