import SwiftUI

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let now: Date
    let store: HistoryStore

    @ViewState private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            leadingIcon
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                preview
                Text(verbatim: metadata)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(background)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private var background: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color.accentColor.opacity(0.22)) }
        if isHovered { return AnyShapeStyle(Color.primary.opacity(0.06)) }
        return AnyShapeStyle(Color.clear)
    }

    // MARK: Leading icon

    @ViewBuilder
    private var leadingIcon: some View {
        if let color = item.hexColor {
            Circle()
                .fill(Color(red: color.red, green: color.green, blue: color.blue))
                .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                .padding(2)
        } else if item.kind == .files, let first = item.fileURLs.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                .resizable()
                .scaledToFit()
        } else if item.linkURL != nil {
            symbol("link")
        } else if let icon = store.appIcon(for: item.source) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            symbol(item.kind == .image ? "photo" : "text.alignleft")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    // MARK: Preview

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .text:
            Text(verbatim: item.trimmedPreview)
                .font(.system(size: 13))
                .foregroundStyle(item.linkURL != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .lineLimit(item.linkURL != nil ? 1 : 3)
                .truncationMode(item.linkURL != nil ? .middle : .tail)

        case .image:
            if let image = store.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: thumbnailSize(for: image).width, height: thumbnailSize(for: image).height)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                    )
            } else {
                Text("Image")
                    .font(.system(size: 13))
            }

        case .files:
            HStack(spacing: 6) {
                Text(verbatim: item.fileURLs.first?.lastPathComponent ?? "")
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if item.fileURLs.count > 1 {
                    Text(verbatim: "+\(item.fileURLs.count - 1)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }

    /// Fits the picture into 260×88 pt while keeping its aspect ratio.
    private func thumbnailSize(for image: NSImage) -> CGSize {
        let width = CGFloat(item.pixelWidth ?? Int(image.size.width))
        let height = CGFloat(item.pixelHeight ?? Int(image.size.height))
        guard width > 0, height > 0 else { return CGSize(width: 88, height: 88) }
        let scale = min(260 / width, 88 / height, 1)
        return CGSize(width: max(width * scale, 24), height: max(height * scale, 24))
    }

    private var metadata: String {
        var parts: [String] = []
        if item.kind == .image, let width = item.pixelWidth, let height = item.pixelHeight {
            parts.append("\(width)×\(height)")
        }
        if item.kind == .files, let folder = item.fileURLs.first?.deletingLastPathComponent() {
            parts.append(folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
        } else if let name = item.source?.name {
            parts.append(name)
        }
        parts.append(Self.relativeFormatter.localizedString(for: min(item.date, now), relativeTo: now))
        return parts.joined(separator: " · ")
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .short
        return formatter
    }()

    // MARK: Trailing

    private var trailing: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(45))
            }
            if index < 9 {
                Text(verbatim: "⌘\(index + 1)")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .secondary : .tertiary)
            }
        }
        .frame(minWidth: 22, alignment: .trailing)
    }
}
