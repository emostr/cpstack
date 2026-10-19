import Foundation

/// Application that owned the pasteboard when an item was copied.
nonisolated struct SourceApp: Codable, Hashable, Sendable {
    var bundleID: String?
    var name: String?
}

/// One entry of the clipboard history. Heavy payloads (rich text, images)
/// live on disk next to the index and are loaded only when pasting.
nonisolated struct ClipItem: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case text
        case image
        case files
    }

    let id: UUID
    var kind: Kind
    /// Plain-text representation used for display and search (truncated).
    var preview: String
    var isRichText: Bool
    var fileURLs: [URL]
    var pixelWidth: Int?
    var pixelHeight: Int?
    var source: SourceApp?
    var date: Date
    var isPinned: Bool
    var contentHash: String

    static let previewLimit = 10_000
}

extension ClipItem {
    var trimmedPreview: String {
        String(preview.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600))
    }

    /// Text that is a single web link, e.g. `https://example.com`.
    var linkURL: URL? {
        guard kind == .text else { return nil }
        let text = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else { return nil }
        return url
    }

    /// Text that is a hex color such as `#3A7BFF` — shown with a swatch.
    var hexColor: (red: Double, green: Double, blue: Double)? {
        guard kind == .text else { return nil }
        var text = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("#") else { return nil }
        text.removeFirst()
        if text.count == 3 { text = text.map { "\($0)\($0)" }.joined() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
