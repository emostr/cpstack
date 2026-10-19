import AppKit

/// Menu bar icon: a left click opens the history, a right click shows the menu.
final class StatusItemController: NSObject, NSMenuDelegate {
    var onTogglePanel: ((NSRect) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onClearHistory: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let settings: AppSettings
    private let menu = NSMenu()

    init(settings: AppSettings) {
        self.settings = settings
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "CPStack")
            button.target = self
            button.action = #selector(buttonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "CPStack"
        }
        menu.delegate = self
        updateAppearance()
    }

    /// Frame of the menu bar icon in screen coordinates.
    var buttonFrame: NSRect {
        guard let button = statusItem.button, let window = button.window else { return .zero }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    func setHighlighted(_ highlighted: Bool) {
        statusItem.button?.highlight(highlighted)
    }

    func updateAppearance() {
        statusItem.button?.appearsDisabled = settings.isPaused
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            onTogglePanel?(buttonFrame)
        }
    }

    private func showMenu() {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let show = NSMenuItem(
            title: String(localized: "Show History") + "  " + settings.shortcut.displayString,
            action: #selector(showHistory), keyEquivalent: ""
        )
        show.target = self
        menu.addItem(show)

        let pause = NSMenuItem(title: String(localized: "Pause Recording"), action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = settings.isPaused ? .on : .off
        menu.addItem(pause)

        let clear = NSMenuItem(title: String(localized: "Clear History…"), action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())

        let preferences = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)

        let about = NSMenuItem(title: String(localized: "About CPStack"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: String(localized: "Quit CPStack"),
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        ))
    }

    @objc private func showHistory() { onTogglePanel?(buttonFrame) }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func clearHistory() { onClearHistory?() }

    @objc private func togglePause() {
        settings.isPaused.toggle()
        updateAppearance()
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
