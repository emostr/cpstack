import Carbon.HIToolbox

/// Registers one system-wide hotkey via Carbon. Unlike event taps, this API
/// needs no Accessibility permission and works while other apps are active.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var shortcut: KeyShortcut?
    private static let signature: OSType = 0x4350_5354 // 'CPST'

    private init() {}

    /// Returns `false` if the combination is already taken by another app.
    @discardableResult
    func register(_ shortcut: KeyShortcut) -> Bool {
        self.shortcut = shortcut
        return registerCurrent()
    }

    /// Temporarily releases the hotkey, e.g. while the user records a new one.
    func suspend() {
        unregister()
    }

    @discardableResult
    func resume() -> Bool {
        registerCurrent()
    }

    private func registerCurrent() -> Bool {
        unregister()
        guard let shortcut else { return false }
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode), shortcut.carbonModifiers, id,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        return status == noErr
    }

    private func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon delivers application-target events on the main thread.
            MainActor.assumeIsolated { HotKeyCenter.shared.onPress?() }
            return noErr
        }, 1, &eventType, nil, &handlerRef)
    }
}
