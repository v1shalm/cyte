import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FoldersPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let folders = model.store.folders
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: Theme.gap)], spacing: Theme.gap) {
                    ForEach(folders) { folder in
                        FolderCard(folder: folder)
                    }
                    NewFolderCard()
                }
            }
            .padding(.horizontal, Theme.sideInset)
            .padding(.top, Theme.topInset)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.automatic)
    }
}

private struct FolderCard: View {
    @Environment(AppModel.self) private var model
    let folder: Folder
    static let mosaicHeight: CGFloat = 170
    static let infoHeight: CGFloat = 60
    static let height: CGFloat = mosaicHeight + 16 + infoHeight

    @State private var hovering = false
    @State private var targeted = false
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var previews: [Save] {
        Array(model.store.members(of: folder).filter { $0.thumbnail != nil }.prefix(4))
    }

    var body: some View {
        let editing = model.editingFolderID == folder.id
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Self.mosaicHeight)
                .overlay { mosaic }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(8)
            VStack(alignment: .leading, spacing: 3) {
                if editing {
                    TextField(L.Folders.untitled, text: $name)
                        .textFieldStyle(.plain)
                        .font(Theme.ui(14, weight: .medium))
                        .focused($nameFocused)
                        .onSubmit(commit)
                        .onExitCommand(perform: commit)
                        .onAppear {
                            name = folder.name == L.Folders.untitled ? "" : folder.name
                            nameFocused = true
                        }
                        .onChange(of: nameFocused) { _, focused in if !focused { commit() } }
                } else {
                    Text(folder.name)
                        .font(Theme.ui(14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .help(folder.name)
                }
                let count = model.store.count(in: folder)
                Text(L.Sidebar.count(count))
                    .font(Theme.ui(TextSize.small))
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .frame(height: FolderCard.infoHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardShadow(radius: Theme.tileRadius + 4, hovering: hovering)
        .overlay(RoundedRectangle(cornerRadius: Theme.tileRadius + 4, style: .continuous).strokeBorder(targeted ? Theme.ink.opacity(0.35) : Theme.hairline))
        .scaleEffect(targeted ? 1.02 : 1)
        .contentShape(RoundedRectangle(cornerRadius: Theme.tileRadius + 4, style: .continuous))
        .onTapGesture {
            guard !editing else { return }
            withAnimation(Theme.settle) { model.folderID = folder.id }
        }
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: targeted)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { withAnimation(Theme.settle) { model.folderID = folder.id } }
        .onDrop(of: [UTType(exportedAs: AppModel.saveType), .fileURL, .url], isTargeted: $targeted) { providers in
            FolderDrop.receive(providers, into: folder, model: model)
            return true
        }
        .contextMenu {
            Button(L.Folders.rename) { model.editingFolderID = folder.id }
            Divider()
            Button(L.Folders.delete, role: .destructive) {
                withAnimation(Theme.settle) { model.store.deleteFolder(folder) }
                model.refresh()
            }
        }
    }

    @ViewBuilder private var mosaic: some View {
        let items = previews
        if items.isEmpty {
            ZStack {
                Theme.softFill
                Icon("folder", size: IconSize.xl)
                    .foregroundStyle(Theme.tertiary)
            }
        } else if items.count == 1 {
            thumb(items[0])
        } else {
            HStack(spacing: 4) {
                thumb(items[0])
                VStack(spacing: 4) {
                    thumb(items[1])
                    if items.count > 2 {
                        HStack(spacing: 4) {
                            thumb(items[2])
                            if items.count > 3 { thumb(items[3]) }
                        }
                    }
                }
            }
        }
    }

    private func thumb(_ save: Save) -> some View {
        Thumb(url: model.store.url(for: save, file: save.thumbnail), maxPixel: 420)
            .clipped()
    }

    private func commit() {
        guard model.editingFolderID == folder.id else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        model.store.rename(folder, to: trimmed.isEmpty ? L.Folders.untitled : trimmed)
        model.editingFolderID = nil
    }
}

private struct NewFolderCard: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        Button {
            withAnimation(Theme.settle) { model.newFolder() }
        } label: {
            VStack(spacing: 10) {
                Icon("plus", size: IconSize.lg)
                Text(L.Folders.new)
                    .font(Theme.ui(13, weight: .medium))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: FolderCard.height)
            .background(RoundedRectangle(cornerRadius: Theme.tileRadius + 4, style: .continuous).fill(hovering ? Theme.softFillStrong : Theme.softFill))
            .contentShape(RoundedRectangle(cornerRadius: Theme.tileRadius + 4, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
    }
}

enum FolderDrop {
    static func receive(_ providers: [NSItemProvider], into folder: Folder, model: AppModel) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(AppModel.saveType) {
                provider.loadDataRepresentation(forTypeIdentifier: AppModel.saveType) { data, _ in
                    guard let data else { return }
                    let id = String(decoding: data, as: UTF8.self)
                    Task { @MainActor in model.file([id], into: folder) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        if let id = model.saveID(forFile: url) { model.file([id], into: folder) } else { model.ingestor.ingest(fileURLs: [url], into: folder.id) }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.url.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        if let save = model.store.saves.first(where: { $0.url == url }) { model.file([save.id], into: folder) }
                    }
                }
            }
        }
    }
}
