import AppKit
import Carbon.HIToolbox
import ServiceManagement

@main
@MainActor
final class SortedApp: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var statusItem: NSStatusItem!
    private let windowManager = WindowManager()
    private let dockSorter = DockSorter()
    private let hotKeyCenter = HotKeyCenter()
    private var dockSortTask: Task<Void, Never>?

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
        registerHotKeys()
    }

    /// Global shortcuts mirroring the menu's ⌃⌥ key equivalents.
    private func registerHotKeys() {
        let modifiers = controlKey | optionKey
        hotKeyCenter.register(keyCode: kVK_ANSI_G, modifiers: modifiers) { [weak self] in
            self?.groupByApp()
        }
        hotKeyCenter.register(keyCode: kVK_ANSI_T, modifiers: modifiers) { [weak self] in
            self?.tileFrontmostApp()
        }
        hotKeyCenter.register(keyCode: kVK_ANSI_C, modifiers: modifiers) { [weak self] in
            self?.cascadeAll()
        }
        hotKeyCenter.register(keyCode: kVK_ANSI_M, modifiers: modifiers) { [weak self] in
            self?.toggleDockSort()
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(actionItem("Group Windows by App", globalKey: "g", action: #selector(groupByApp)))
        menu.addItem(actionItem("Tile Frontmost App", globalKey: "t", action: #selector(tileFrontmostApp)))
        menu.addItem(actionItem("Cascade All Windows", globalKey: "c", action: #selector(cascadeAll)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Group Minimized Windows in Dock", globalKey: "m", action: #selector(toggleDockSort)))
        menu.addItem(actionItem("Open Accessibility Settings...", action: #selector(openAccessibilitySettings)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Launch at Login", action: #selector(toggleLaunchAtLogin)))
        menu.addItem(actionItem("About Sorted", action: #selector(showAbout)))
        menu.addItem(actionItem("Quit Sorted", key: "q", action: #selector(quit)))
        return menu
    }

    private func actionItem(
        _ title: String,
        key: String = "",
        globalKey: String = "",
        action: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: globalKey.isEmpty ? key : globalKey)
        if !globalKey.isEmpty {
            // Display the ⌃⌥ combo registered as a global hot key.
            item.keyEquivalentModifierMask = [.control, .option]
        }
        item.target = self
        return item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleDockSort):
            menuItem.title = dockSortTask == nil
                ? "Group Minimized Windows in Dock"
                : "Cancel Dock Sorting"
        case #selector(toggleLaunchAtLogin):
            menuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        default:
            break
        }
        return true
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            presentError(error)
        }
    }

    private func presentError(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = "Sorted couldn’t complete that action"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
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

    @objc private func toggleDockSort() {
        if let task = dockSortTask {
            task.cancel()
            return
        }

        guard let dock = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock"
        }) else {
            presentError(SortedError.dockNotFound)
            return
        }

        let context = DockSorter.Context(
            dockPID: dock.processIdentifier,
            screenFrames: axScreenFrames(),
            applications: NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .map { DockSorter.RunningApp(pid: $0.processIdentifier, name: $0.localizedName ?? "Unknown App") }
        )
        // groupMinimizedWindowsByApp is nonisolated async, so it runs off the
        // main actor and slow Accessibility calls to unresponsive apps can't
        // stall the menu bar. The same menu item cancels the running task.
        dockSortTask = Task { [dockSorter] in
            do {
                try await dockSorter.groupMinimizedWindowsByApp(context: context)
            } catch is CancellationError {
                // User cancelled; nothing to report.
            } catch {
                presentError(error)
            }
            dockSortTask = nil
        }
    }

    /// Screen frames converted from AppKit's bottom-left origin to the
    /// Accessibility coordinate space (top-left origin).
    private func axScreenFrames() -> [CGRect] {
        let screens = NSScreen.screens
        guard let maxY = screens.map(\.frame.maxY).max() else { return [] }

        return screens.map { screen in
            CGRect(
                x: screen.frame.minX,
                y: maxY - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
        }
    }

    @objc private func toggleLaunchAtLogin() {
        perform {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        }
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
