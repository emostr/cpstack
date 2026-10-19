import AppKit

/// Polls the general pasteboard for changes. macOS has no change notification,
/// and reading `changeCount` a few times per second is practically free.
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private let store: HistoryStore
    private let settings: AppSettings
    private var timer: Timer?
    private var lastChangeCount: Int

    init(store: HistoryStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Call after CPStack itself wrote to the pasteboard so the write isn't recorded again.
    func skipCurrentChange() {
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        guard !settings.isPaused else { return }

        guard let content = Pasteboard.read(
            pasteboard,
            ignoreConfidential: settings.ignoreConfidential,
            includeImages: settings.saveImages
        ) else { return }

        let app = NSWorkspace.shared.frontmostApplication
        let source = app.map { SourceApp(bundleID: $0.bundleIdentifier, name: $0.localizedName) }
        let clip = RawClip(content: content, date: .now, source: source)
        Task { await store.ingest(clip) }
    }
}
