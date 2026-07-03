import ApplicationServices
import Foundation

enum SortedError: LocalizedError {
    case accessibilityPermissionRequired
    case noWindowsFound
    case noFrontmostApp
    case minimizeIntoApplicationEnabled
    case dockNotFound
    case noMinimizedWindows
    case dockMustBeVisible
    case partiallySorted(remaining: Int)

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Accessibility permission is required. Enable Sorted in System Settings → Privacy & Security → Accessibility."
        case .noWindowsFound:
            return "No movable windows were found."
        case .noFrontmostApp:
            return "The frontmost app has no movable windows."
        case .minimizeIntoApplicationEnabled:
            return "“Minimize windows into application icon” is currently enabled. Turn it off in System Settings → Desktop & Dock, then minimize windows as individual Dock thumbnails before sorting."
        case .dockNotFound:
            return "Sorted could not find the Dock."
        case .noMinimizedWindows:
            return "No individual minimized-window thumbnails with an identifiable owning app were found in the Dock."
        case .dockMustBeVisible:
            return "The Dock must be visible while Sorted sorts its minimized windows."
        case .partiallySorted(let remaining):
            return "Sorted grouped most thumbnails, but the Dock rejected \(remaining) remaining move\(remaining == 1 ? "" : "s"). Try the action again to finish."
        }
    }
}

func requireAccessibilityPermission() throws {
    // Literal spelling of kAXTrustedCheckOptionPrompt: the SDK exposes that
    // constant as a global `var`, which Swift 6 strict concurrency rejects.
    let promptKey = "AXTrustedCheckOptionPrompt"
    guard AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) else {
        throw SortedError.accessibilityPermissionRequired
    }
}

extension AXUIElement {
    func attribute<T>(_ name: String) -> T? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &rawValue) == .success else {
            return nil
        }
        return rawValue as? T
    }

    func attribute<T>(_ name: String, as type: AXValueType) -> T? {
        guard let rawValue: AXValue = attribute(name),
              AXValueGetType(rawValue) == type else {
            return nil
        }

        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AXValueGetValue(rawValue, type, pointer) else { return nil }
        return pointer.pointee
    }
}
