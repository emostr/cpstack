import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Pasteboard contents as a list of items, each mapping a type identifier to raw data.
typealias PasteboardPayload = [[String: Data]]

/// File layout inside `~/Library/Application Support/CPStack`:
///
///     history.json        index of all items (metadata only)
///     data/<id>.plist     pasteboard payload of a text item
///     data/<id>.png       full image of an image item
///     thumbs/<id>.png     small preview of an image item
nonisolated struct HistoryStorage: Sendable {
    let baseURL: URL

    private var indexURL: URL { baseURL.appending(path: "history.json") }
    private var dataURL: URL { baseURL.appending(path: "data", directoryHint: .isDirectory) }
    private var thumbsURL: URL { baseURL.appending(path: "thumbs", directoryHint: .isDirectory) }

    static func `default`() -> HistoryStorage {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return HistoryStorage(baseURL: support.appending(path: "CPStack", directoryHint: .isDirectory))
    }

    func prepareDirectories() {
        for url in [baseURL, dataURL, thumbsURL] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: Index

    func loadIndex() -> [ClipItem] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ClipItem].self, from: data)) ?? []
    }

    func saveIndex(_ items: [ClipItem]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: indexURL, options: [.atomic])
    }

    // MARK: Payloads

    func payloadURL(for id: UUID) -> URL { dataURL.appending(path: "\(id.uuidString).plist") }
    func imageURL(for id: UUID) -> URL { dataURL.appending(path: "\(id.uuidString).png") }
    func thumbnailURL(for id: UUID) -> URL { thumbsURL.appending(path: "\(id.uuidString).png") }

    func writePayload(_ payload: PasteboardPayload, for id: UUID) throws {
        let data = try PropertyListEncoder.binary.encode(payload)
        try data.write(to: payloadURL(for: id), options: [.atomic])
    }

    func readPayload(for id: UUID) -> PasteboardPayload? {
        guard let data = try? Data(contentsOf: payloadURL(for: id)) else { return nil }
        return try? PropertyListDecoder().decode(PasteboardPayload.self, from: data)
    }

    func readImage(for id: UUID) -> Data? {
        try? Data(contentsOf: imageURL(for: id))
    }

    func removeFiles(for ids: [UUID]) {
        let fm = FileManager.default
        for id in ids {
            try? fm.removeItem(at: payloadURL(for: id))
            try? fm.removeItem(at: imageURL(for: id))
            try? fm.removeItem(at: thumbnailURL(for: id))
        }
    }

    /// Deletes payload files that no item in the index refers to (e.g. after a crash).
    func removeOrphans(keeping ids: Set<UUID>) {
        let fm = FileManager.default
        for dir in [dataURL, thumbsURL] {
            let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for file in files {
                let name = file.deletingPathExtension().lastPathComponent
                if let id = UUID(uuidString: name), ids.contains(id) { continue }
                try? fm.removeItem(at: file)
            }
        }
    }
}

// MARK: - Image processing

nonisolated enum ImageProcessing {
    struct Result: Sendable {
        var png: Data
        var thumbnail: Data?
        var width: Int
        var height: Int
    }

    /// Normalizes any pasteboard image (TIFF, PNG, …) to PNG and renders a small thumbnail.
    static func process(_ data: Data, alreadyPNG: Bool) -> Result? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let png = alreadyPNG ? data : encodePNG(image)
        guard let png else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 560,
        ]
        let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            .flatMap(encodePNG)

        return Result(png: png, thumbnail: thumbnail, width: image.width, height: image.height)
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

private extension PropertyListEncoder {
    nonisolated static var binary: PropertyListEncoder {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }
}
