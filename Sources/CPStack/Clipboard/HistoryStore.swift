import AppKit
import Observation

/// In-memory clipboard history backed by `HistoryStorage`.
/// Pinned items come first, the rest are sorted from newest to oldest.
@Observable
final class HistoryStore {
    private(set) var items: [ClipItem] = []

    @ObservationIgnored let storage: HistoryStorage
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private let thumbnails = NSCache<NSUUID, NSImage>()
    @ObservationIgnored private var appIcons: [String: NSImage] = [:]
    @ObservationIgnored var onChange: (() -> Void)?

    init(settings: AppSettings, storage: HistoryStorage = .default()) {
        self.settings = settings
        self.storage = storage
        storage.prepareDirectories()
        items = storage.loadIndex()
        sort()
        let ids = Set(items.map(\.id))
        Task.detached(priority: .background) { storage.removeOrphans(keeping: ids) }
    }

    // MARK: Adding

    func ingest(_ clip: RawClip) async {
        let hash = await Task.detached(priority: .userInitiated) { clip.contentHash }.value
        if bump(hash: hash, source: clip.source, date: clip.date) { return }

        let id = UUID()
        let storage = storage
        let prepared = await Task.detached(priority: .userInitiated) {
            Self.prepare(clip, id: id, hash: hash, storage: storage)
        }.value
        guard let prepared else { return }

        // The same content may have arrived while we were busy.
        if bump(hash: hash, source: clip.source, date: clip.date) {
            Task.detached(priority: .background) { storage.removeFiles(for: [id]) }
            return
        }
        items.append(prepared)
        didMutate()
    }

    /// Moves an existing item with the same content to the top instead of duplicating it.
    private func bump(hash: String, source: SourceApp?, date: Date) -> Bool {
        guard let index = items.firstIndex(where: { $0.contentHash == hash }) else { return false }
        items[index].date = date
        if let source { items[index].source = source }
        didMutate()
        return true
    }

    nonisolated private static func prepare(_ clip: RawClip, id: UUID, hash: String, storage: HistoryStorage) -> ClipItem? {
        var item = ClipItem(
            id: id, kind: .text, preview: "", isRichText: false, fileURLs: [],
            source: clip.source, date: clip.date, isPinned: false, contentHash: hash
        )
        do {
            switch clip.content {
            case .text(let plain, let payload, let isRich):
                item.preview = String(plain.prefix(ClipItem.previewLimit))
                item.isRichText = isRich
                try storage.writePayload(payload, for: id)

            case .image(let data, let isPNG):
                guard let image = ImageProcessing.process(data, alreadyPNG: isPNG) else { return nil }
                item.kind = .image
                item.pixelWidth = image.width
                item.pixelHeight = image.height
                try image.png.write(to: storage.imageURL(for: id), options: .atomic)
                try image.thumbnail?.write(to: storage.thumbnailURL(for: id), options: .atomic)

            case .files(let urls):
                item.kind = .files
                item.fileURLs = urls
                item.preview = urls.map(\.lastPathComponent).joined(separator: "\n")
            }
        } catch {
            storage.removeFiles(for: [id])
            return nil
        }
        return item
    }

    // MARK: Editing

    func touch(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].date = .now
        didMutate()
    }

    func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        didMutate()
    }

    func delete(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        removeFiles(for: [item.id])
        didMutate()
    }

    /// Removes everything except pinned items.
    func clear() {
        let removed = items.filter { !$0.isPinned }.map(\.id)
        items.removeAll { !$0.isPinned }
        removeFiles(for: removed)
        didMutate()
    }

    func enforceLimit() {
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > settings.historyLimit else { return }
        let removed = unpinned.dropFirst(settings.historyLimit).map(\.id)
        let removedSet = Set(removed)
        items.removeAll { removedSet.contains($0.id) }
        removeFiles(for: removed)
        didMutate()
    }

    private func didMutate() {
        sort()
        let limitExceeded = items.lazy.filter { !$0.isPinned }.count > settings.historyLimit
        if limitExceeded {
            enforceLimit()
            return
        }
        scheduleSave()
        onChange?()
    }

    private func sort() {
        items.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.date > rhs.date
        }
    }

    private func removeFiles(for ids: [UUID]) {
        for id in ids { thumbnails.removeObject(forKey: id as NSUUID) }
        let storage = storage
        Task.detached(priority: .background) { storage.removeFiles(for: ids) }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [storage] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let snapshot = items
            await Task.detached(priority: .utility) { storage.saveIndex(snapshot) }.value
        }
    }

    /// Writes pending changes immediately (used on quit).
    func flush() {
        saveTask?.cancel()
        storage.saveIndex(items)
    }

    // MARK: Images

    func thumbnail(for item: ClipItem) -> NSImage? {
        if let cached = thumbnails.object(forKey: item.id as NSUUID) { return cached }
        guard let image = NSImage(contentsOf: storage.thumbnailURL(for: item.id))
            ?? NSImage(contentsOf: storage.imageURL(for: item.id))
        else { return nil }
        thumbnails.setObject(image, forKey: item.id as NSUUID)
        return image
    }

    func appIcon(for source: SourceApp?) -> NSImage? {
        guard let bundleID = source?.bundleID else { return nil }
        if let cached = appIcons[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        appIcons[bundleID] = icon
        return icon
    }
}
