import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DockHost: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var palette: PaletteState?
    @State private var dockWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 10) {
            if let palette, model.paletteShown {
                DockPalette(state: palette)
            }
            if model.folderListOpen {
                FolderList()
                    .frame(width: max(dockWidth, FolderList.width), alignment: .leading)
                    .transition(.asymmetric(
                        insertion: reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .bottomLeading)).combined(with: .offset(y: 8)),
                        removal: .identity
                    ))
            }
            if model.addMenuOpen {
                AddSheet()
                    .frame(width: max(dockWidth, AddSheet.width), alignment: .trailing)
                    .transition(.asymmetric(
                        insertion: reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .bottomTrailing)).combined(with: .offset(y: 8)),
                        removal: .identity
                    ))
            }
            Dock(palette: model.paletteShown ? palette : nil)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { dockWidth = $0 }
        }
        .padding(.bottom, Dock.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(alignment: .bottom) {
            LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .frame(height: Dock.clearance + 24)
                .allowsHitTesting(false)
        }
        .onChange(of: model.paletteShown, initial: true) { _, shown in
            palette = shown ? PaletteState(model: model, floating: false) { [model] in model.paletteShown = false } : nil
            if shown {
                model.addMenuOpen = false
                model.folderListOpen = false
            }
        }
        .onChange(of: model.addMenuOpen) { _, open in
            if open {
                model.paletteShown = false
                model.folderListOpen = false
            }
        }
        .onChange(of: model.folderListOpen) { _, open in
            if open {
                model.paletteShown = false
                model.addMenuOpen = false
            }
        }
    }
}

struct Dock: View {
    @Environment(AppModel.self) private var model
    let palette: PaletteState?
    @State private var dragOver = false

    static let item: CGFloat = Control.large
    static let inset: CGFloat = 6
    static let height: CGFloat = item + inset * 2
    static let bottom: CGFloat = 20
    static let clearance: CGFloat = bottom + height + 16

    var body: some View {
        HStack(spacing: 4) {
            DockTab(symbol: "square.grid.2x2", title: L.Folders.everything, active: home) {
                withAnimation(Theme.settle) { model.goHome() }
            }
            DockTab(symbol: "folder", title: L.Folders.allFolders, active: model.foldersPage || model.folderID != nil) {
                withAnimation(Theme.enter) { model.folderListOpen.toggle() }
            }
            .onDrop(of: [UTType(exportedAs: AppModel.saveType), .fileURL, .url], isTargeted: $dragOver) { _ in false }
            DockTab(symbol: "trash", title: nil, help: L.Trash.title, active: model.trashPage) {
                withAnimation(Theme.settle) { model.trashPage = true }
            }
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1, height: 22)
                .padding(.horizontal, 6)
            DockSearch(palette: palette)
            DockAdd()
        }
        .padding(Self.inset)
        .background(Capsule().fill(Theme.softFill.opacity(0.9)))
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.14), radius: 24, y: 12)
        .onChange(of: dragOver) { _, over in
            guard over else { return }
            model.folderListOpen = false
            withAnimation(Theme.settle) { model.foldersPage = true }
        }
        .onChange(of: model.editingFolderID) { _, id in if id != nil, model.folderID == nil { model.foldersPage = true } }
    }

    private var home: Bool { model.folderID == nil && !model.foldersPage && !model.trashPage }
}

private struct DockTab: View {
    let symbol: String
    let title: String?
    var help: String?
    let active: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Icon(symbol, size: IconSize.md, fill: active ? 1 : 0)
                if let title {
                    Text(title)
                        .font(Theme.ui(TextSize.body, weight: .medium))
                }
            }
            .foregroundStyle(active || hovering ? Theme.ink : Theme.secondary)
            .padding(.horizontal, title == nil ? 0 : 14)
            .frame(width: title == nil ? Dock.item : nil, height: Dock.item)
            .background {
                if active {
                    Capsule()
                        .fill(Theme.tabPill)
                        .shadow(color: .black.opacity(Theme.tabPillShadow), radius: 3, y: 1)
                } else if hovering {
                    Capsule().fill(Theme.softFillStrong)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .help(help ?? title ?? "")
        .accessibilityLabel(help ?? title ?? "")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

private struct DockSearch: View {
    @Environment(AppModel.self) private var model
    let palette: PaletteState?
    @FocusState private var focused: Bool
    @State private var hovering = false

    static let width: CGFloat = 320

    var body: some View {
        Group {
            if let palette {
                field(palette)
            } else {
                trigger
            }
        }
        .frame(width: Self.width, height: Dock.item)
    }

    private func field(_ palette: PaletteState) -> some View {
        @Bindable var palette = palette
        return HStack(spacing: 10) {
            Icon("magnifyingglass", size: IconSize.sm)
                .foregroundStyle(Theme.secondary)
            TextField(L.Palette.placeholder, text: $palette.query)
                .textFieldStyle(.plain)
                .font(Theme.ui(TextSize.large))
                .foregroundStyle(Theme.ink)
                .focused($focused)
                .onSubmit { palette.run() }
            MicButton(listening: palette.voice.isListening, level: palette.voice.level) { palette.toggleVoice() }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(width: Self.width, height: Dock.item)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.16)))
        .paletteKeys(palette)
        .onAppear { focused = true }
        .onDisappear { palette.voice.cancel() }
    }

    private var trigger: some View {
        Button { model.paletteShown = true } label: {
            HStack(spacing: 10) {
                Icon("magnifyingglass", size: IconSize.sm)
                    .foregroundStyle(Theme.secondary)
                if model.query.isEmpty {
                    Text(L.Search.placeholder)
                        .font(Theme.ui(TextSize.body))
                        .foregroundStyle(Theme.secondary)
                } else {
                    Text(model.query)
                        .font(Theme.ui(TextSize.body, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if model.query.isEmpty {
                    Text("⌘K")
                        .font(Theme.ui(TextSize.caption, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(Theme.softFill))
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .frame(width: Self.width, height: Dock.item)
            .background(Capsule().fill(hovering ? Theme.softHover : Theme.surface))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Icon("xmark.circle.fill", size: IconSize.sm)
                        .foregroundStyle(Theme.secondary)
                        .frame(width: Control.small, height: Control.small)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .accessibilityLabel(L.Search.clear)
            }
        }
        .borderBeam(size: .sm, active: model.voiceSearch.isListening, cornerRadius: Dock.item / 2, duration: 1.6)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .accessibilityLabel(model.query.isEmpty ? L.Search.placeholder : model.query)
        .accessibilityHint("⌘K")
    }
}

private struct DockAdd: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        let open = model.addMenuOpen
        let folder = model.openFolder
        Button {
            withAnimation(Theme.enter) { model.addMenuOpen.toggle() }
        } label: {
            HStack(spacing: 7) {
                Icon(open ? "xmark" : (folder == nil ? "plus" : "folder.badge.plus"), size: IconSize.sm)
                Text(folder == nil ? L.Add.button : L.Add.here)
                    .font(Theme.ui(TextSize.body, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.leading, 14)
            .padding(.trailing, 18)
            .frame(height: Dock.item)
            .background(Capsule().fill(hovering || open ? Theme.inkHover : Theme.ink))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .help(folder.map { L.Add.into($0.name) } ?? L.Add.button)
        .accessibilityLabel(open ? L.Add.close : (folder.map { L.Add.into($0.name) } ?? L.Add.button))
    }
}

private struct DockPalette: View {
    let state: PaletteState

    var body: some View {
        VStack(spacing: 0) {
            PaletteList(state: state, maxHeight: 380)
            PaletteHints(searching: !state.query.isEmpty)
        }
        .frame(width: 640)
        .floatingPanel(radius: Radius.sheet)
        .borderBeam(strength: 0.45 + state.voice.level * 0.55, active: state.voice.isListening, cornerRadius: Radius.sheet, duration: 1.8)
    }
}

struct FolderList: View {
    @Environment(AppModel.self) private var model
    @State private var filter = ""
    @FocusState private var filterFocused: Bool

    static let width: CGFloat = 340
    private static let inner: CGFloat = Radius.panel - 6

    var body: some View {
        let all = model.store.folders
        let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = trimmed.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        VStack(alignment: .leading, spacing: 0) {
            if all.count > 6 {
                HStack(spacing: 8) {
                    Icon("magnifyingglass", size: IconSize.sm)
                        .foregroundStyle(Theme.secondary)
                    TextField(L.Folders.find, text: $filter)
                        .textFieldStyle(.plain)
                        .font(Theme.ui(TextSize.large))
                        .focused($filterFocused)
                        .onSubmit { if let first = shown.first { open(first) } }
                }
                .padding(.horizontal, 12)
                .frame(height: Control.regular)
                .background(RoundedRectangle(cornerRadius: Self.inner, style: .continuous).fill(Theme.softFill))
                .padding(.bottom, 6)
                .onAppear { filterFocused = true }
            }
            if all.isEmpty {
                Text(L.Sidebar.noFolders)
                    .font(Theme.ui(TextSize.body))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else if shown.isEmpty {
                Text(L.Folders.noMatch(trimmed))
                    .font(Theme.ui(TextSize.body))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(shown) { folder in
                            FolderRow(folder: folder, current: model.folderID == folder.id && !model.foldersPage) { open(folder) }
                        }
                    }
                }
                .frame(maxHeight: 360)
                .fixedSize(horizontal: false, vertical: true)
                .scrollIndicators(.automatic)
            }
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            HStack(spacing: 0) {
                FooterButton(symbol: "folder.badge.plus", title: L.Folders.new) {
                    model.folderListOpen = false
                    model.newFolder()
                }
                Spacer()
                FooterButton(symbol: "arrow.right", title: L.Folders.seeAll, trailingIcon: true) {
                    model.folderListOpen = false
                    withAnimation(Theme.settle) { model.foldersPage = true }
                }
            }
        }
        .padding(6)
        .frame(width: Self.width)
        .floatingPanel(radius: Radius.panel)
    }

    private func open(_ folder: Folder) {
        model.folderListOpen = false
        withAnimation(Theme.settle) {
            model.trashPage = false
            model.foldersPage = false
            model.folderID = folder.id
        }
    }
}

private struct FolderRow: View {
    @Environment(AppModel.self) private var model
    let folder: Folder
    let current: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                mosaic
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.hairline))
                Text(folder.name)
                    .font(Theme.ui(TextSize.large, weight: current ? .medium : .regular))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if folder.rule != nil {
                    Icon("sparkles", size: IconSize.xs)
                        .foregroundStyle(Theme.tertiary)
                }
                Spacer(minLength: 8)
                Text("\(model.store.count(in: folder))")
                    .font(Theme.ui(TextSize.small))
                    .foregroundStyle(Theme.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .frame(height: 46)
            .background {
                let shape = RoundedRectangle(cornerRadius: Radius.panel - 6, style: .continuous)
                if current {
                    shape
                        .fill(Theme.tabPill)
                        .overlay(shape.strokeBorder(Theme.hairline))
                        .shadow(color: .black.opacity(Theme.tabPillShadow), radius: 3, y: 1)
                } else if hovering {
                    shape.fill(Theme.softHover)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .help(folder.name)
        .accessibilityLabel("\(folder.name), \(L.Sidebar.count(model.store.count(in: folder)))")
        .accessibilityAddTraits(current ? .isSelected : [])
    }

    private var mosaic: some View {
        let thumbs = model.store.members(of: folder).compactMap { save in model.store.url(for: save, file: save.thumbnail).map { (save, $0) } }.prefix(4)
        return Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            GridRow {
                cell(thumbs.count > 0 ? thumbs[thumbs.startIndex] : nil)
                cell(thumbs.count > 1 ? thumbs[thumbs.startIndex + 1] : nil)
            }
            GridRow {
                cell(thumbs.count > 2 ? thumbs[thumbs.startIndex + 2] : nil)
                cell(thumbs.count > 3 ? thumbs[thumbs.startIndex + 3] : nil)
            }
        }
        .background(Theme.softFill)
    }

    @ViewBuilder private func cell(_ item: (Save, URL)?) -> some View {
        if let item {
            Thumb(url: item.1, maxPixel: 64, tint: item.0.tint)
                .frame(width: 15.5, height: 15.5)
                .clipped()
        } else {
            Theme.softFill.frame(width: 15.5, height: 15.5)
        }
    }
}

private struct FooterButton: View {
    let symbol: String
    let title: String
    var trailingIcon = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if !trailingIcon { Icon(symbol, size: IconSize.sm) }
                Text(title)
                if trailingIcon { Icon(symbol, size: IconSize.xs) }
            }
            .font(Theme.ui(TextSize.body, weight: .medium))
            .foregroundStyle(hovering ? Theme.ink : Theme.secondary)
            .padding(.horizontal, 10)
            .frame(height: Control.small)
            .background(RoundedRectangle(cornerRadius: Radius.panel - 6, style: .continuous).fill(hovering ? Theme.softHover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
    }
}
