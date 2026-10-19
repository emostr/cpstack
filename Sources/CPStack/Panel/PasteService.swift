import AppKit
import Carbon.HIToolbox

/// Puts an item on the pasteboard and, if allowed, pastes it into the frontmost app.
final class PasteService {
    private let store: HistoryStore
    private let settings: AppSettings
    private let monitor: ClipboardMonitor
    private var didPromptForAccess = false

    init(store: HistoryStore, settings: AppSettings, monitor: ClipboardMonitor) {
        self.store = store
        self.settings = settings
        self.monitor = monitor
    }

    func copy(_ item: ClipItem, plainText: Bool = false) {
        Pasteboard.write(item, plainText: plainText, storage: store.storage)
        monitor.skipCurrentChange()
        store.touch(item)
    }

    /// Call after the panel is hidden: the previous app gets keyboard focus back
    /// and receives the synthetic ⌘V.
    func paste(_ item: ClipItem, plainText: Bool) {
        copy(item, plainText: plainText)
        guard settings.autoPaste else { return }

        guard Accessibility.isTrusted else {
            if !didPromptForAccess {
                didPromptForAccess = true
                Accessibility.requestAccess()
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Self.postCommandV()
        }
    }

    private static func postCommandV() {
        // Look the key up so pasting works with Dvorak and other Latin layouts too.
        let vKey = CGKeyCode(KeyCodeTranslator.keyCode(for: "v") ?? UInt16(kVK_ANSI_V))
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
