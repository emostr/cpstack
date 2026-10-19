import Combine
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let store: HistoryStore

    @ViewState private var launchAtLogin = LaunchAtLogin.isEnabled
    @ViewState private var isTrusted = Accessibility.isTrusted
    @ViewState private var language = AppLanguage.current
    @ViewState private var isConfirmingClear = false
    private let initialLanguage = AppLanguage.current
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            generalSection
            pastingSection
            historySection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 700)
        .onReceive(refreshTimer) { _ in
            isTrusted = Accessibility.isTrusted
            launchAtLogin = LaunchAtLogin.isEnabled
        }
        .onChange(of: settings.historyLimit) { store.enforceLimit() }
        .alert("Clear clipboard history?", isPresented: $isConfirmingClear) {
            Button("Clear", role: .destructive) { store.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned items will be kept.")
        }
    }

    // MARK: Sections

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    LaunchAtLogin.setEnabled(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            ))

            LabeledContent {
                ShortcutRecorder(settings: settings)
            } label: {
                Text("Open history")
                if !settings.shortcutIsAvailable {
                    Label("This shortcut is used by another app", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Picker("Show panel", selection: $settings.panelPosition) {
                Text("At text cursor").tag(AppSettings.PanelPosition.caret)
                Text("At mouse pointer").tag(AppSettings.PanelPosition.mouse)
                Text("In screen center").tag(AppSettings.PanelPosition.center)
            }

            Picker(selection: $language) {
                Text("System").tag(AppLanguage.system)
                Text(verbatim: "English").tag(AppLanguage.english)
                Text(verbatim: "Русский").tag(AppLanguage.russian)
            } label: {
                Text("Language")
                if language != initialLanguage {
                    Text("Restart CPStack to apply")
                }
            }
            .onChange(of: language) { _, newValue in newValue.apply() }

            if language != initialLanguage {
                HStack {
                    Spacer()
                    Button("Restart Now") { AppLanguage.relaunch() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private var pastingSection: some View {
        Section {
            Toggle(isOn: $settings.autoPaste) {
                Text("Paste automatically")
                Text("Choosing an item pastes it into the active app. When off, the item is only copied.")
            }

            LabeledContent {
                if isTrusted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                } else {
                    Button("Grant Access…") {
                        Accessibility.requestAccess()
                        Accessibility.openSettings()
                    }
                }
            } label: {
                Text("Accessibility")
                Text(isTrusted
                     ? "Access granted. CPStack can paste and find the text cursor."
                     : "Needed to paste into other apps and to show the panel at the text cursor.")
            }
        } header: {
            Text("Pasting")
        }
    }

    private var historySection: some View {
        Section("History") {
            Picker("Items to keep", selection: $settings.historyLimit) {
                ForEach(AppSettings.historyLimits, id: \.self) { limit in
                    Text(verbatim: "\(limit)").tag(limit)
                }
            }

            Toggle("Save images", isOn: $settings.saveImages)

            Toggle(isOn: $settings.ignoreConfidential) {
                Text("Ignore passwords")
                Text("Skip data that password managers mark as confidential.")
            }

            Toggle("Pause recording", isOn: $settings.isPaused)

            HStack {
                Text("Pinned items are never removed automatically.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Spacer()
                Button("Clear History…", role: .destructive) { isConfirmingClear = true }
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "CPStack \(Bundle.main.shortVersion)")
                        .font(.headline)
                    Text("Clipboard history in your menu bar.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            shortcutsHelp
        }
    }

    private var shortcutsHelp: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            helpRow(settings.shortcut.displayString, "Open or close the history")
            helpRow("↑ ↓", "Choose an item")
            helpRow("↩ / ⌘1…9", "Paste the selected / numbered item")
            helpRow("⇧↩", "Paste as plain text")
            helpRow("⌘P", "Pin or unpin")
            helpRow("⌘⌫", "Delete from history")
            helpRow("⇥", "Show pinned only")
            helpRow("⎋", "Clear search / close")
        }
        .font(.callout)
    }

    private func helpRow(_ keys: String, _ action: LocalizedStringKey) -> some View {
        GridRow {
            Text(verbatim: keys)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            Text(action)
        }
    }
}

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
