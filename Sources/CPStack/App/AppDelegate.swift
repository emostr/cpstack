import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: AppSettings!
    private var store: HistoryStore!
    private var monitor: ClipboardMonitor!
    private var panel: PanelController!
    private var statusItem: StatusItemController!
    private var settingsWindow: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if terminateIfAlreadyRunning() { return }

        settings = AppSettings()
        store = HistoryStore(settings: settings)
        monitor = ClipboardMonitor(store: store, settings: settings)
        let pasteService = PasteService(store: store, settings: settings, monitor: monitor)
        panel = PanelController(store: store, settings: settings, pasteService: pasteService)
        statusItem = StatusItemController(settings: settings)
        settingsWindow = SettingsWindowController(settings: settings, store: store)

        NSApp.mainMenu = MainMenu.make(target: self)

        HotKeyCenter.shared.onPress = { [weak self] in self?.panel.toggle(.automatic) }
        settings.shortcutIsAvailable = HotKeyCenter.shared.register(settings.shortcut)

        statusItem.onTogglePanel = { [weak self] frame in self?.panel.toggle(.statusItem(frame)) }
        statusItem.onOpenSettings = { [weak self] in self?.openSettings() }
        statusItem.onClearHistory = { [weak self] in self?.confirmClearHistory() }
        panel.onOpenSettings = { [weak self] in self?.openSettings() }
        panel.onVisibilityChange = { [weak self] visible in
            self?.statusItem.setHighlighted(visible)
            self?.statusItem.updateAppearance()
        }

        monitor.start()

        if !settings.hasLaunchedBefore {
            settings.hasLaunchedBefore = true
            // Introduce the app on first launch by opening the panel under the menu bar icon.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                panel.show(.statusItem(statusItem.buttonFrame))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.flush()
    }

    /// Opening CPStack again from Finder or Launchpad shows Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    @objc func openSettings() {
        panel.hide()
        settingsWindow.show()
    }

    private func confirmClearHistory() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear clipboard history?")
        alert.informativeText = String(localized: "Pinned items will be kept.")
        alert.addButton(withTitle: String(localized: "Clear"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            store.clear()
        }
    }

    private func terminateIfAlreadyRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard !others.isEmpty else { return false }
        NSApp.terminate(nil)
        return true
    }
}

/// Hidden for a menu bar app, but needed for ⌘C/⌘V/⌘A in text fields
/// and visible while the Settings window is open.
enum MainMenu {
    static func make(target: AppDelegate) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "About CPStack"),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = appMenu.addItem(withTitle: String(localized: "Settings…"),
                                           action: #selector(AppDelegate.openSettings), keyEquivalent: ",")
        settingsItem.target = target
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Hide CPStack"),
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: String(localized: "Quit CPStack"),
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(submenu(appMenu))

        let editMenu = NSMenu(title: String(localized: "Edit"))
        editMenu.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(submenu(editMenu))

        let windowMenu = NSMenu(title: String(localized: "Window"))
        windowMenu.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: String(localized: "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        mainMenu.addItem(submenu(windowMenu))
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}
