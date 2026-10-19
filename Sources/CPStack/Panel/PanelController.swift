import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Borderless floating panel that takes keyboard focus without activating CPStack,
/// so the app you were typing in stays frontmost and receives the paste.
final class ClipboardPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: PanelMetrics.size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject, NSWindowDelegate {
    enum Anchor {
        /// Placement from Settings: text cursor, mouse pointer or screen center.
        case automatic
        /// Right under the menu bar icon.
        case statusItem(NSRect)
    }

    let model: PanelViewModel
    var onOpenSettings: (() -> Void)?
    var onVisibilityChange: ((Bool) -> Void)?

    private let panel = ClipboardPanel()
    private let settings: AppSettings
    private let pasteService: PasteService
    private var keyMonitor: Any?
    private var lastHideDate = Date.distantPast

    init(store: HistoryStore, settings: AppSettings, pasteService: PasteService) {
        self.settings = settings
        self.pasteService = pasteService
        model = PanelViewModel(store: store, settings: settings)
        super.init()

        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: PanelMetrics.size))
        glass.cornerRadius = PanelMetrics.cornerRadius
        glass.style = .regular
        glass.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: PanelView(model: model))
        hosting.frame = glass.bounds
        hosting.autoresizingMask = [.width, .height]
        glass.contentView = hosting

        panel.contentView = glass
        panel.delegate = self

        store.onChange = { [weak model] in model?.refresh() }

        model.onPaste = { [weak self] item, plainText in
            self?.hide()
            self?.pasteService.paste(item, plainText: plainText)
        }
        model.onCopy = { [weak self] item in
            self?.hide()
            self?.pasteService.copy(item)
        }
        model.onOpenSettings = { [weak self] in
            self?.hide()
            self?.onOpenSettings?()
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(_ anchor: Anchor) {
        if panel.isVisible {
            hide()
            return
        }
        // Clicking the menu bar icon while the panel is open first makes the panel
        // lose focus and hide; that click must not reopen it.
        if case .statusItem = anchor, Date.now.timeIntervalSince(lastHideDate) < 0.3 { return }
        show(anchor)
    }

    func show(_ anchor: Anchor) {
        // Read the caret position before the panel takes keyboard focus.
        let origin = origin(for: anchor)
        model.prepareForShow()

        panel.setFrame(NSRect(origin: origin, size: PanelMetrics.size), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }
        startKeyMonitor()
        onVisibilityChange?(true)
    }

    func hide() {
        guard panel.isVisible else { return }
        stopKeyMonitor()
        panel.orderOut(nil)
        lastHideDate = .now
        onVisibilityChange?(false)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: Keyboard

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private static let digitKeys: [Int: Int] = [
        kVK_ANSI_1: 0, kVK_ANSI_2: 1, kVK_ANSI_3: 2, kVK_ANSI_4: 3, kVK_ANSI_5: 4,
        kVK_ANSI_6: 5, kVK_ANSI_7: 6, kVK_ANSI_8: 7, kVK_ANSI_9: 8,
    ]

    /// Returns `true` when the key was handled; other keys go to the search field.
    /// Key codes are physical positions, so shortcuts work with any keyboard layout.
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let keyCode = Int(event.keyCode)

        if command, let index = Self.digitKeys[keyCode] {
            model.paste(at: index)
            return true
        }

        switch keyCode {
        case kVK_DownArrow:
            command ? model.moveSelectionToEdge(top: false) : model.moveSelection(by: 1)
        case kVK_UpArrow:
            command ? model.moveSelectionToEdge(top: true) : model.moveSelection(by: -1)
        case kVK_PageDown:
            model.moveSelection(by: 6)
        case kVK_PageUp:
            model.moveSelection(by: -6)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            model.paste(plainText: flags.contains(.shift))
        case kVK_Escape:
            if model.query.isEmpty { hide() } else { model.query = "" }
        case kVK_Tab:
            model.pinnedOnly.toggle()
        case kVK_Delete where command, kVK_ForwardDelete where command:
            model.delete()
        case kVK_ANSI_P where command:
            model.togglePin()
        case kVK_ANSI_C where command && flags.contains(.shift) == false && hasNoSearchSelection:
            model.copy()
        case kVK_ANSI_Comma where command:
            model.openSettings()
        case kVK_ANSI_W where command:
            hide()
        default:
            return false
        }
        return true
    }

    /// ⌘C copies the selected clip unless the user selected text in the search field.
    private var hasNoSearchSelection: Bool {
        guard let editor = panel.firstResponder as? NSTextView else { return true }
        return editor.selectedRange().length == 0
    }

    // MARK: Placement

    private func origin(for anchor: Anchor) -> NSPoint {
        let size = PanelMetrics.size
        switch anchor {
        case .statusItem(let rect):
            let screen = NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main
            let origin = NSPoint(x: rect.midX - size.width / 2, y: rect.minY - 6 - size.height)
            return clamp(origin, to: screen)

        case .automatic:
            switch settings.panelPosition {
            case .caret:
                if let caret = CaretLocator.caretRect() { return origin(below: caret) }
                return originNearMouse()
            case .mouse:
                return originNearMouse()
            case .center:
                let screen = screenWithMouse()
                let frame = screen?.visibleFrame ?? .zero
                let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2 + frame.height * 0.08)
                return clamp(origin, to: screen)
            }
        }
    }

    private func origin(below caret: NSRect) -> NSPoint {
        let size = PanelMetrics.size
        let screen = NSScreen.screens.first { $0.frame.intersects(caret) } ?? NSScreen.main
        var origin = NSPoint(x: caret.minX - 18, y: caret.minY - 8 - size.height)
        if let frame = screen?.visibleFrame, origin.y < frame.minY {
            origin.y = caret.maxY + 8
        }
        return clamp(origin, to: screen)
    }

    private func originNearMouse() -> NSPoint {
        let size = PanelMetrics.size
        let mouse = NSEvent.mouseLocation
        let screen = screenWithMouse()
        var origin = NSPoint(x: mouse.x + 4, y: mouse.y - 4 - size.height)
        if let frame = screen?.visibleFrame, origin.y < frame.minY {
            origin.y = mouse.y + 4
        }
        return clamp(origin, to: screen)
    }

    private func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    private func clamp(_ origin: NSPoint, to screen: NSScreen?) -> NSPoint {
        guard let frame = screen?.visibleFrame else { return origin }
        let size = PanelMetrics.size
        let margin: CGFloat = 8
        return NSPoint(
            x: min(max(origin.x, frame.minX + margin), frame.maxX - size.width - margin),
            y: min(max(origin.y, frame.minY + margin), frame.maxY - size.height - margin)
        )
    }
}
