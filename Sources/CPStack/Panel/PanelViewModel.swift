import Foundation
import Observation

/// State of the history panel: search, filter and keyboard selection.
@Observable
final class PanelViewModel {
    let store: HistoryStore
    let settings: AppSettings

    var query = "" {
        didSet { if query != oldValue { refresh(resetSelection: true) } }
    }

    var pinnedOnly = false {
        didSet { if pinnedOnly != oldValue { refresh(resetSelection: true) } }
    }

    private(set) var results: [ClipItem] = []
    var selectedIndex = 0

    /// Incremented on every show so the view can focus the search field and scroll to top.
    private(set) var showToken = 0
    /// Reference point for "5 min ago" labels, updated on every show.
    private(set) var openedAt = Date.now

    @ObservationIgnored var onPaste: ((ClipItem, _ plainText: Bool) -> Void)?
    @ObservationIgnored var onCopy: ((ClipItem) -> Void)?
    @ObservationIgnored var onOpenSettings: (() -> Void)?

    init(store: HistoryStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        refresh(resetSelection: true)
    }

    var selectedItem: ClipItem? { results[safe: selectedIndex] }

    var isHistoryEmpty: Bool { store.items.isEmpty }

    func prepareForShow() {
        query = ""
        pinnedOnly = false
        refresh(resetSelection: true)
        openedAt = .now
        showToken += 1
    }

    func refresh(resetSelection: Bool = false) {
        let query = query.trimmingCharacters(in: .whitespaces)
        results = store.items.filter { item in
            if pinnedOnly && !item.isPinned { return false }
            guard !query.isEmpty else { return true }
            return item.preview.localizedStandardContains(query)
                || (item.source?.name?.localizedStandardContains(query) ?? false)
        }
        if resetSelection {
            selectedIndex = 0
        } else {
            selectedIndex = min(selectedIndex, max(results.count - 1, 0))
        }
    }

    // MARK: Keyboard

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    func moveSelectionToEdge(top: Bool) {
        guard !results.isEmpty else { return }
        selectedIndex = top ? 0 : results.count - 1
    }

    // MARK: Actions

    func paste(_ item: ClipItem? = nil, plainText: Bool = false) {
        guard let item = item ?? selectedItem else { return }
        onPaste?(item, plainText)
    }

    func paste(at index: Int) {
        guard let item = results[safe: index] else { return }
        onPaste?(item, false)
    }

    func copy(_ item: ClipItem? = nil) {
        guard let item = item ?? selectedItem else { return }
        onCopy?(item)
    }

    func togglePin(_ item: ClipItem? = nil) {
        guard let item = item ?? selectedItem else { return }
        store.togglePin(item)
        // Keep the same item selected after it moves in or out of the pinned group.
        if let index = results.firstIndex(where: { $0.id == item.id }) { selectedIndex = index }
    }

    func delete(_ item: ClipItem? = nil) {
        guard let item = item ?? selectedItem else { return }
        store.delete(item)
    }

    func openSettings() {
        onOpenSettings?()
    }
}
