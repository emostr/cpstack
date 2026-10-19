import SwiftUI

enum PanelMetrics {
    static let size = CGSize(width: 380, height: 470)
    static let cornerRadius: CGFloat = 26
}

/// Content of the floating history panel. The Liquid Glass background
/// is provided by the `NSGlassEffectView` that hosts this view.
struct PanelView: View {
    @Bindable var model: PanelViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
                .opacity(0.5)
                .padding(.horizontal, 14)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(width: PanelMetrics.size.width, height: PanelMetrics.size.height)
        .onChange(of: model.showToken) {
            DispatchQueue.main.async { isSearchFocused = true }
        }
        .onAppear { isSearchFocused = true }
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isSearchFocused)

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .transition(.opacity)
            }

            Button {
                withAnimation(.snappy(duration: 0.2)) { model.pinnedOnly.toggle() }
            } label: {
                Image(systemName: model.pinnedOnly ? "pin.fill" : "pin")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.pinnedOnly ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .help("Show pinned only (Tab)")
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(height: 50)
    }

    // MARK: List

    @ViewBuilder
    private var content: some View {
        if model.results.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                            ClipRow(
                                item: item,
                                index: index,
                                isSelected: index == model.selectedIndex,
                                now: model.openedAt,
                                store: model.store
                            )
                            .id(item.id)
                            .onTapGesture { model.paste(item) }
                            .contextMenu { contextMenu(for: item) }
                        }
                    }
                    .padding(8)
                }
                .scrollIndicators(.automatic)
                .onChange(of: model.selectedIndex) { _, index in
                    guard let id = model.results[safe: index]?.id else { return }
                    proxy.scrollTo(id)
                }
                .onChange(of: model.showToken) {
                    if let id = model.results.first?.id { proxy.scrollTo(id, anchor: .top) }
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for item: ClipItem) -> some View {
        Button(model.settings.autoPaste ? "Paste" : "Copy") { model.paste(item) }
        if item.kind != .image {
            Button("Paste as Plain Text") { model.paste(item, plainText: true) }
        }
        Button("Copy Without Pasting") { model.copy(item) }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin") { model.togglePin(item) }
        if let url = item.linkURL {
            Button("Open Link") { NSWorkspace.shared.open(url) }
        }
        if item.kind == .files {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(item.fileURLs) }
        }
        Divider()
        Button("Delete", role: .destructive) { model.delete(item) }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            if model.isHistoryEmpty {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("History is empty")
                    .font(.system(size: 15, weight: .semibold))
                Text("Copy something and it will appear here.\nPress \(model.settings.shortcut.displayString) to open CPStack anywhere.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if model.pinnedOnly && model.query.isEmpty {
                Image(systemName: "pin")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("No pinned items")
                    .font(.system(size: 15, weight: .semibold))
                Text("Pinned items stay in the history until you unpin them. Select an item and press ⌘P.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Nothing found")
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 12)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 14) {
            KeyHint(keys: "↩", label: model.settings.autoPaste ? "Paste" : "Copy")
            KeyHint(keys: "⇧↩", label: "Plain text")
            KeyHint(keys: "⌘P", label: "Pin")
            Spacer(minLength: 0)
            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings (⌘,)")
        }
        .font(.system(size: 11))
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(height: 38)
    }
}

private struct KeyHint: View {
    let keys: String
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 5) {
            Text(verbatim: keys)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(label)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }
}
