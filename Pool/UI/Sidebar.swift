import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Namespace private var selection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                SidebarToggle(onPanel: true)
            }
            .frame(height: Chrome.barHeight - 16)
            .padding(.trailing, 4)

            XSourceRow()
                .padding(.top, 2)

            HStack {
                Text(L.Folders.title)
                    .font(Theme.ui(11, weight: .medium))
                    .foregroundStyle(Theme.sideTertiary)
                Spacer()
                Button {
                    withAnimation(Theme.settle) { model.newFolder() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.sideSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.88))
                .help(L.Folders.new)
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.top, 14)
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 1) {
                    ForEach(model.store.folders) { folder in
                        FolderRow(folder: folder, namespace: selection)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    if model.store.folders.isEmpty {
                        Button {
                            withAnimation(Theme.settle) { model.newFolder() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 13))
                                    .frame(width: 20)
                                Text(L.Folders.new)
                                    .font(Theme.ui(13))
                                Spacer()
                            }
                            .foregroundStyle(Theme.sideTertiary)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle(scale: 0.98))
                    }
                }
            }
            .scrollIndicators(.never)

            Spacer(minLength: 0)

            LibraryFooter()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.panel)
                .shadow(color: .black.opacity(0.05), radius: 16, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.sideStroke))
    }
}

private struct FolderRow: View {
    @Environment(AppModel.self) private var model
    let folder: Folder
    let namespace: Namespace.ID

    @State private var hovering = false
    @State private var targeted = false
    @State private var dropped = 0
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        let selected = model.folderID == folder.id
        Group {
            if model.editingFolderID == folder.id {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 20)
                    TextField(L.Folders.untitled, text: $name)
                        .textFieldStyle(.plain)
                        .font(Theme.ui(13, weight: .medium))
                        .focused($nameFocused)
                        .onSubmit(commit)
                        .onExitCommand(perform: commit)
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.ink.opacity(0.14)))
                .onAppear {
                    name = folder.name == L.Folders.untitled ? "" : folder.name
                    nameFocused = true
                }
                .onChange(of: nameFocused) { _, focused in if !focused { commit() } }
            } else {
                Button {
                    withAnimation(.spring(duration: 0.38, bounce: 0.12)) {
                        model.folderID = selected ? nil : folder.id
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selected ? "folder.fill" : "folder")
                            .font(.system(size: 13))
                            .foregroundStyle(selected ? Theme.ink : Theme.sideSecondary)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.bounce, value: dropped)
                            .frame(width: 20)
                        Text(folder.name)
                            .font(Theme.ui(13, weight: selected ? .medium : .regular))
                            .foregroundStyle(selected ? Theme.ink : (Theme.bold ? Color.white.opacity(0.8) : Theme.ink.opacity(0.75)))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(model.store.count(in: folder))")
                            .font(Theme.ui(11))
                            .monospacedDigit()
                            .foregroundStyle(selected && Theme.bold ? Theme.ink.opacity(0.5) : Theme.sideTertiary)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Theme.folderSelection)
                                .shadow(color: .black.opacity(Theme.folderSelectionShadow), radius: 6, y: 2)
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        } else if hovering || targeted {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(targeted ? Theme.sideTarget : Theme.sideHover)
                                .shadow(color: .black.opacity(Theme.bold ? 0 : (targeted ? 0.1 : 0.06)), radius: 4, y: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle(scale: 0.98))
                .simultaneousGesture(TapGesture(count: 2).onEnded { model.editingFolderID = folder.id })
                .onHover { hovering = $0 }
                .animation(Theme.hover, value: hovering)
            }
        }
        .scaleEffect(targeted ? 1.02 : 1)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: targeted)
        .onDrop(of: [UTType(exportedAs: AppModel.saveType), .fileURL, .url], isTargeted: $targeted) { providers in
            receive(providers)
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

    private func commit() {
        guard model.editingFolderID == folder.id else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        model.store.rename(folder, to: trimmed.isEmpty ? L.Folders.untitled : trimmed)
        model.editingFolderID = nil
    }

    private func receive(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(AppModel.saveType) {
                provider.loadDataRepresentation(forTypeIdentifier: AppModel.saveType) { data, _ in
                    guard let data else { return }
                    let id = String(decoding: data, as: UTF8.self)
                    Task { @MainActor in file(id) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        if let id = model.saveID(forFile: url) { file(id) } else { model.ingestor.ingest(fileURLs: [url], into: folder.id) }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.url.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        if let save = model.store.saves.first(where: { $0.url == url }) { file(save.id) }
                    }
                }
            }
        }
    }

    private func file(_ id: String) {
        model.file([id], into: folder)
        dropped += 1
    }
}

private struct XSourceRow: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        let importer = model.xImport
        let selected = model.bookmarksOnly
        Button {
            if importer.connected || importer.importedCount > 0 {
                withAnimation(.spring(duration: 0.38, bounce: 0.12)) { model.bookmarksOnly.toggle() }
            } else {
                importer.open()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 20)
                Text(L.X.source)
                    .font(Theme.ui(13, weight: selected ? .medium : .regular))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Group {
                    if importer.isBusy {
                        Text(L.X.syncing)
                    } else if importer.connected {
                        Text("\(importer.importedCount)")
                            .contentTransition(.numericText())
                    } else {
                        Text(L.X.connect)
                            .foregroundStyle(Theme.sideInk)
                    }
                }
                .font(Theme.ui(11))
                .foregroundStyle(Theme.sideTertiary)
            }
            .foregroundStyle(selected ? Theme.ink : (hovering ? Theme.sideInk : Theme.sideSecondary))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Theme.folderSelection : (hovering ? Theme.sideHover : .clear))
                    .shadow(color: .black.opacity(selected ? Theme.folderSelectionShadow : 0), radius: 6, y: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .contextMenu {
            if importer.connected {
                Button(L.X.syncNow) { importer.open() }
                Button(L.X.disconnect) { importer.disconnect() }
            } else {
                Button(L.X.importAction) { importer.open() }
            }
        }
    }
}

private struct LibraryFooter: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        let root = model.store.paths.root
        let inICloud = root.path(percentEncoded: false).contains("Mobile Documents")
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([root])
        } label: {
            HStack(spacing: 8) {
                Image(systemName: inICloud ? "icloud" : "externaldrive")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14)
                Text(inICloud ? L.Sidebar.iCloud : root.lastPathComponent)
                    .font(Theme.ui(11.5, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(L.Sidebar.count(model.store.saves.count))
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.sideTertiary)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(hovering ? Theme.sideInk : Theme.sideSecondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Theme.sideHover : .clear).shadow(color: .black.opacity(hovering && !Theme.bold ? 0.06 : 0), radius: 4, y: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .help(root.path(percentEncoded: false))
    }
}
