import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a new key combination. Esc cancels, ⌫ restores the default.
struct ShortcutRecorder: View {
    @Bindable var settings: AppSettings

    @ViewState private var isRecording = false
    @ViewState private var heldModifiers: NSEvent.ModifierFlags = []
    @ViewState private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(verbatim: label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isRecording ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .frame(minWidth: 96)
            }
            .buttonStyle(.glass)
            .help(isRecording ? "Press a shortcut. Esc cancels, ⌫ resets." : "Click to record a new shortcut")

            if settings.shortcut != .default && !isRecording {
                Button {
                    settings.shortcut = .default
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset to \(KeyShortcut.default.displayString)")
            }
        }
        .onDisappear { stopRecording() }
    }

    private var label: String {
        guard isRecording else { return settings.shortcut.displayString }
        return heldModifiers.isEmpty
            ? String(localized: "Type shortcut…")
            : heldModifiers.symbols + "…"
    }

    private func startRecording() {
        isRecording = true
        heldModifiers = []
        HotKeyCenter.shared.suspend()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        heldModifiers = []
        settings.shortcutIsAvailable = HotKeyCenter.shared.resume()
    }

    private func handle(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(KeyShortcut.relevantModifiers)
        if event.type == .flagsChanged {
            heldModifiers = modifiers
            return
        }

        switch Int(event.keyCode) {
        case kVK_Escape where modifiers.isEmpty:
            stopRecording()
        case kVK_Delete where modifiers.isEmpty, kVK_ForwardDelete where modifiers.isEmpty:
            stopRecording()
            settings.shortcut = .default
        default:
            let shortcut = KeyShortcut(keyCode: event.keyCode, modifiers: modifiers)
            guard shortcut.isValid else {
                NSSound.beep()
                return
            }
            stopRecording()
            // Assigning re-registers the hotkey and updates `shortcutIsAvailable`.
            settings.shortcut = shortcut
        }
    }
}
