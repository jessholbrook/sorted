import AppKit

@main
@MainActor
final class SortedApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let windowManager = WindowManager()
    private let dockSorter = DockSorter()

    static func main() {
        let app = NSApplication.shared
        let delegate = SortedApp()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.3.group",
            accessibilityDescription: "Sorted"
        )
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(actionItem("Group Windows by App", key: "g", action: #selector(groupByApp)))
        menu.addItem(actionItem("Tile Frontmost App", key: "t", action: #selector(tileFrontmostApp)))
        menu.addItem(actionItem("Cascade All Windows", key: "c", action: #selector(cascadeAll)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Group Minimized Windows in Dock", action: #selector(groupDockWindows)))
        menu.addItem(actionItem("Open Accessibility Settings...", action: #selector(openAccessibilitySettings)))
        menu.addItem(.separator())
        menu.addItem(actionItem("About Sorted", action: #selector(showAbout)))
        menu.addItem(actionItem("Quit Sorted", key: "q", action: #selector(quit)))
        return menu
    }

    private func actionItem(_ title: String, key: String = "", action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Sorted couldn’t complete that action"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func groupByApp() {
        perform { try windowManager.groupByApp() }
    }

    @objc private func tileFrontmostApp() {
        perform { try windowManager.tileFrontmostApp() }
    }

    @objc private func cascadeAll() {
        perform { try windowManager.cascadeAll() }
    }

    @objc private func groupDockWindows() {
        perform { try dockSorter.groupMinimizedWindowsByApp() }
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
