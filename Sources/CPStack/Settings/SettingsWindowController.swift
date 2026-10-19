import AppKit
import SwiftUI

/// While Settings is open CPStack becomes a regular app (Dock icon, ⌘⇥);
/// afterwards it returns to living only in the menu bar.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: AppSettings
    private let store: HistoryStore
    private var window: NSWindow?
    private var previousApp: NSRunningApplication?

    init(settings: AppSettings, store: HistoryStore) {
        self.settings = settings
        self.store = store
    }

    func show() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = frontmost
        }

        let window = window ?? makeWindow()
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(rootView: SettingsView(settings: settings, store: store))
        controller.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: controller)
        window.title = String(localized: "CPStack Settings")
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        previousApp?.activate()
        previousApp = nil
    }
}
