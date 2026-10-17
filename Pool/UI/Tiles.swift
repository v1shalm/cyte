import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Tile: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let save: Save
    let namespace: Namespace.ID
    let fresh: Bool
    var playing = false

    @State private var hovering = false
    @State private var beamDone = false

    private var working: Bool { save.pending || model.enricher.activeID == save.id }
    private var beaming: Bool { fresh && !beamDone }

    var body: some View {
        let selected = model.selectedID == save.id
        let picked = model.selection.contains(save.id)
        Button {
            let flags = NSApp.currentEvent?.modifierFlags ?? []
            model.tap(save.id, shift: flags.contains(.shift), command: flags.contains(.command)) {
                withAnimation(reduceMotion ? Theme.fade : Theme.open) { model.selectedID = save.id }
            }
        } label: {
            TileFace(save: save, hovering: hovering, playing: playing)
                .overlay(RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous).strokeBorder(Theme.hairline))
                .contentShape(RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.985))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: picked ? 2.5 : 0)
                .opacity(picked ? 1 : 0)
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.55), lineWidth: 1.5)
                .padding(-3)
                .opacity(model.focusedID == save.id && !picked ? 1 : 0)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            if (hovering || model.selecting) && !selected {
                SelectDot(on: picked)
                    .padding(10)
                    .onTapGesture { model.toggle(save.id) }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .overlay(alignment: .topTrailing) {
            if hovering && !selected && !model.selecting {
                TileActions(save: save)
                    .padding(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
            }
        }
        .borderBeam(active: beaming, cornerRadius: Theme.tileRadius, duration: 1.5, laps: 1.15)
        .task(id: fresh) {
            guard fresh else { return }
            try? await Task.sleep(for: .seconds(1.9))
            beamDone = true
            if !working { model.store.clearFresh(save.id) }
        }
        .onChange(of: working) { _, busy in
            if !busy, beamDone { model.store.clearFresh(save.id) }
        }
        .matchedGeometryEffect(id: save.id, in: namespace, isSource: !selected)
        .opacity(selected ? 0 : 1)
        .cardShadow(hovering: hovering)
        .animation(Theme.hover, value: hovering)
        .onHover { inside in
            hovering = inside
            model.hoveredID = inside ? save.id : (model.hoveredID == save.id ? nil : model.hoveredID)
        }
        .onDrag { dragProvider() }
        .contextMenu { TileMenu(save: save) }
        .accessibilityLabel(save.displayTitle)
    }

    private func dragProvider() -> NSItemProvider {
        let provider: NSItemProvider
        if let original = model.store.url(for: save, file: save.original), let file = NSItemProvider(contentsOf: original) {
            provider = file
        } else if let url = save.url {
            provider = NSItemProvider(object: url as NSURL)
        } else {
            provider = NSItemProvider(object: (save.text ?? save.displayTitle) as NSString)
        }
        let id = save.id
        provider.registerDataRepresentation(forTypeIdentifier: AppModel.saveType, visibility: .ownProcess) { completion in
            completion(Data(id.utf8), nil)
            return nil
        }
        return provider
    }
}

struct TileActions: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let save: Save
    @State private var spread = false

    private let size: CGFloat = 28
    private let step: CGFloat = 34

    var body: some View {
        let count = save.url == nil ? 2 : 3
        ZStack(alignment: .topTrailing) {
            LiquidLayer(blur: 5, fill: onCard ? Theme.softFill : .white, shadow: !onCard) {
                ZStack(alignment: .topTrailing) {
                    ForEach(0..<count, id: \.self) { index in
                        Circle()
                            .frame(width: size, height: size)
                            .offset(x: spread ? -CGFloat(index) * step : 0)
                            .animation(motion(index), value: spread)
                    }
                }
                .frame(width: step * CGFloat(count), height: size, alignment: .topTrailing)
            }

            ZStack(alignment: .topTrailing) {
                TileAction(symbol: "trash", label: L.Actions.delete) { model.delete(save) }
                    .offset(x: 0)
                TileAction(symbol: "folder.badge.plus", label: L.Actions.addToFolder) {
                    FolderMenu.show(for: save, model: model)
                }
                .offset(x: spread ? -step : 0)
                .opacity(spread ? 1 : 0)
                .animation(motion(1), value: spread)
                if let url = save.url {
                    TileAction(symbol: "arrow.up.right", label: L.Actions.open) { NSWorkspace.shared.open(url) }
                        .offset(x: spread ? -step * 2 : 0)
                        .opacity(spread ? 1 : 0)
                        .animation(motion(2), value: spread)
                }
            }
            .frame(width: step * CGFloat(count), height: size, alignment: .topTrailing)
        }
        .onAppear { spread = true }
    }

    private var onCard: Bool { save.kind == .note || (save.kind == .link && save.thumbnail == nil) }

    private func motion(_ index: Int) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.5, bounce: 0.34).delay(Double(index) * 0.03)
    }
}

private struct TileAction: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { TileActionFace(symbol: symbol) }
            .buttonStyle(PressStyle(scale: 0.88))
            .help(label)
            .accessibilityLabel(label)
    }
}

private struct TileActionFace: View {
    let symbol: String

    var body: some View {
        Icon(symbol, size: IconSize.xs)
            .foregroundStyle(Theme.ink)
            .frame(width: 28, height: 28)
            .contentShape(Circle())
    }
}

enum FolderMenu {
    static func show(for save: Save, model: AppModel) {
        let menu = NSMenu()
        let target = MenuTarget()
        for folder in model.store.folders {
            let item = NSMenuItem(title: folder.name, action: #selector(MenuTarget.fire(_:)), keyEquivalent: "")
            item.target = target
            item.image = Icon.nsImage("folder", size: IconSize.sm)
            item.state = save.folders.contains(folder.id) ? .on : .off
            target.actions[item] = {
                if save.folders.contains(folder.id) {
                    model.store.remove(save.id, from: folder)
                    model.refresh()
                } else {
                    model.file([save.id], into: folder)
                }
            }
            menu.addItem(item)
        }
        if !model.store.folders.isEmpty { menu.addItem(.separator()) }
        let create = NSMenuItem(title: L.Folders.new, action: #selector(MenuTarget.fire(_:)), keyEquivalent: "")
        create.target = target
        create.image = Icon.nsImage("folder.badge.plus", size: IconSize.sm)
        target.actions[create] = { model.newFolder(adding: [save.id]) }
        menu.addItem(create)
        objc_setAssociatedObject(menu, &MenuTarget.key, target, .OBJC_ASSOCIATION_RETAIN)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

final class MenuTarget: NSObject {
    nonisolated(unsafe) static var key: UInt8 = 0
    var actions: [NSMenuItem: () -> Void] = [:]

    @objc func fire(_ sender: NSMenuItem) { actions[sender]?() }
}

struct TileFace: View {
    let save: Save
    let hovering: Bool
    var playing = false

    var body: some View {
        Group {
            switch save.kind {
            case .image: ImageTile(save: save, hovering: hovering, playing: playing)
            case .link: LinkTile(save: save)
            case .note: NoteTile(save: save)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous)
                .strokeBorder(Theme.hairline)
        )
    }
}

struct ImageTile: View {
    @Environment(AppModel.self) private var model
    let save: Save
    let hovering: Bool
    let playing: Bool

    var body: some View {
        SaveMedia(save: save, maxPixel: model.tilePixels, playing: playing, cornerRadius: Theme.tileRadius)
            .overlay(alignment: .bottomLeading) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [.black.opacity(0), .black.opacity(0.42)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 72)
                    Text(save.displayTitle)
                        .font(Theme.ui(12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
                .opacity(hovering ? 1 : 0)
                .animation(Theme.hover, value: hovering)
                .allowsHitTesting(false)
            }
    }
}

struct LinkTile: View {
    @Environment(AppModel.self) private var model
    let save: Save
    static let footerHeight: CGFloat = 62
    static let titleSize: CGFloat = 19
    static let titleLines = 4

    var body: some View {
        VStack(spacing: 0) {
            if save.thumbnail != nil {
                Thumb(url: model.store.url(for: save, file: save.thumbnail), maxPixel: model.tilePixels, tint: save.tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Favicon(url: model.store.url(for: save, file: save.favicon))
                        Text(save.host ?? "")
                            .font(Theme.ui(TextSize.caption))
                            .foregroundStyle(Theme.tertiary)
                            .lineLimit(1)
                    }
                    Text(save.pending ? "" : save.displayTitle)
                        .font(Theme.serif(LinkTile.titleSize))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(1)
                        .lineLimit(LinkTile.titleLines)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Theme.surface)
                .shimmer(save.pending)
            }
            if save.thumbnail != nil {
                footer
            }
        }
        .background(Theme.surface)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(save.pending ? (save.host ?? "") : save.displayTitle)
                .font(Theme.ui(12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Favicon(url: model.store.url(for: save, file: save.favicon))
                Text(save.host ?? "")
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: Self.footerHeight, maxHeight: Self.footerHeight, alignment: .leading)
        .background(Theme.surface)
    }
}

struct Favicon: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                Thumb(url: url, maxPixel: 64, contentMode: .fit)
            } else {
                Icon("link", size: IconSize.xs)
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .frame(width: 12, height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}

struct NoteTile: View {
    let save: Save

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.note
            Text(save.text ?? "")
                .font(Theme.ui(13))
                .lineSpacing(3.5)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct TileMenu: View {
    @Environment(AppModel.self) private var model
    let save: Save

    var body: some View {
        if let url = save.url {
            Button(L.Detail.openLink) { NSWorkspace.shared.open(url) }
        }
        Button(model.selection.contains(save.id) ? "Deselect" : L.Similar.select) { model.toggle(save.id) }
        if save.kind != .note {
            Button(L.Similar.find) { model.findSimilar(to: save) }
        }
        Button(L.Detail.copy) { Clipboard.copy(save, store: model.store) }
        Button(L.Detail.reveal) {
            NSWorkspace.shared.activateFileViewerSelecting([model.store.folder(for: save)])
        }
        Divider()
        Menu(L.Folders.addTo) {
            ForEach(model.store.folders) { folder in
                Button(folder.name) { model.file([save.id], into: folder) }
                    .disabled(save.folders.contains(folder.id))
            }
            if !model.store.folders.isEmpty { Divider() }
            Button(L.Folders.new) { model.newFolder(adding: [save.id]) }
        }
        if let id = model.folderID, let folder = model.store.folder(id: id), save.folders.contains(id) {
            Button(L.Folders.removeFrom) {
                model.store.remove(save.id, from: folder)
                model.refresh()
            }
        }
        Menu(L.Filter.tag) {
            ForEach(model.tagIndex.mine, id: \.tag) { item in
                Toggle(item.tag, isOn: Binding(
                    get: { save.tags.contains(item.tag) },
                    set: { model.tag([save.id], with: item.tag, on: $0) }
                ))
            }
            if !model.tagIndex.mine.isEmpty { Divider() }
            Button(L.Filter.newTag + "…") { TagPrompt.ask { model.tag([save.id], with: $0, on: true) } }
        }
        Divider()
        Button(L.Detail.delete, role: .destructive) { model.delete(save) }
    }
}

enum Clipboard {
    static func copy(_ save: Save, store: LibraryStore) {
        let board = NSPasteboard.general
        board.clearContents()
        if save.motion == .video, let original = store.url(for: save, file: save.original) {
            board.writeObjects([original as NSURL])
        } else if let original = store.url(for: save, file: save.original), let image = NSImage(contentsOf: original) {
            board.writeObjects([image])
        } else if let url = save.url {
            board.writeObjects([url as NSURL])
        } else {
            board.setString(save.text ?? save.displayTitle, forType: .string)
        }
    }
}

enum TagPrompt {
    static func ask(_ done: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = L.Filter.newTagPrompt
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: L.Filter.create)
        alert.addButton(withTitle: L.Filter.cancel)
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn { done(field.stringValue) }
    }
}
