import AppKit
import SwiftUI

enum BarPopover { case folder, tag }

extension AppModel {
    var selecting: Bool { !selection.isEmpty }

    var actionIDs: [String] {
        if !selection.isEmpty { return orderedIDs.filter { selection.contains($0) } }
        return focusedID.map { [$0] } ?? []
    }

    func tap(_ id: String, shift: Bool, command: Bool, open: () -> Void) {
        focusedID = id
        if shift, let anchor = anchorID, let from = orderedIDs.firstIndex(of: anchor), let to = orderedIDs.firstIndex(of: id) {
            let range = orderedIDs[min(from, to)...max(from, to)]
            withAnimation(Theme.settle) { selection.formUnion(range) }
        } else if shift || command || selecting {
            toggle(id)
        } else {
            open()
        }
    }

    func toggle(_ id: String) {
        withAnimation(Theme.settle) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        }
        anchorID = id
        if selection.isEmpty { barPopover = nil }
    }

    func selectAll() {
        selection = Set(orderedIDs)
    }

    func clearSelection(animated: Bool = true) {
        withAnimation(animated ? Theme.settle : nil) {
            selection = []
            barPopover = nil
        }
    }

    func deleteSelected() {
        let ids = actionIDs
        guard !ids.isEmpty else { return }
        if ids.count == 1, let save = store.save(id: ids[0]) {
            clearSelection()
            delete(save)
            return
        }
        let saves = ids.compactMap { store.save(id: $0) }
        clearSelection()
        Task {
            var trashed: [LibraryStore.Trashed] = []
            for save in saves { if let item = await store.delete(save) { trashed.append(item) } }
            guard !trashed.isEmpty else { return }
            SoundEngine.shared.play(.delete)
            refresh()
            feedback.toast(L.Select.deletedMany(trashed.count), actionTitle: L.Toast.undo) {
                Task {
                    for item in trashed.reversed() { await self.store.restore(item) }
                    self.refresh()
                    self.feedback.dismissToast()
                }
            }
        }
    }

    func tagSelected(_ raw: String) {
        let ids = actionIDs
        tag(ids, with: raw, on: true)
        let clean = raw.lowercased().trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard !clean.isEmpty else { return }
        feedback.toast(L.Select.tagged(clean, ids.count))
        clearSelection()
    }

    func fileSelected(into folder: Folder) {
        let ids = actionIDs
        file(ids, into: folder)
        clearSelection()
    }

    func newFolderFromSelection() {
        let ids = actionIDs
        clearSelection()
        newFolder(adding: ids)
        foldersPage = true
    }

    enum Direction { case left, right, up, down }

    func moveFocus(_ direction: Direction) {
        let ids = orderedIDs
        guard !ids.isEmpty else { return }
        let frames = layoutFrames()
        guard let current = focusedID, let from = frames[current], ids.contains(current) else {
            let visible = tileFrames()
            let first = ids.filter { visible[$0] != nil }.min { (visible[$0]!.minY, visible[$0]!.minX) < (visible[$1]!.minY, visible[$1]!.minX) } ?? ids[0]
            focus(first)
            return
        }
        let target: String?
        switch direction {
        case .left, .right:
            guard let index = ids.firstIndex(of: current) else { return }
            let next = index + (direction == .right ? 1 : -1)
            target = ids.indices.contains(next) ? ids[next] : nil
        case .up, .down:
            let down = direction == .down
            target = ids.filter { id in
                guard id != current, let frame = frames[id] else { return false }
                return down ? frame.minY > from.maxY - 4 : frame.maxY < from.minY + 4
            }.min { lhs, rhs in
                score(frames[lhs]!, from, down) < score(frames[rhs]!, from, down)
            }
        }
        if let target { focus(target) }
    }

    private func score(_ frame: CGRect, _ from: CGRect, _ down: Bool) -> CGFloat {
        let dy = down ? frame.minY - from.maxY : from.minY - frame.maxY
        return abs(frame.midX - from.midX) * 2 + max(0, dy)
    }

    private func focus(_ id: String) {
        focusedID = id
        scrollToTile(id)
    }

    func openFocused() {
        guard let id = focusedID, store.save(id: id) != nil else { return }
        selectedID = id
    }
}

struct SelectDot: View {
    let on: Bool
    @State private var hovering = false

    var body: some View {
        ZStack {
            Circle().fill(on ? Theme.ink : Color.white.opacity(hovering ? 1 : 0.92))
            Circle().strokeBorder(on ? Theme.ink : Color.black.opacity(0.18), lineWidth: 1)
            if on {
                Icon("checkmark", size: IconSize.xs)
                    .foregroundStyle(.white)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .frame(width: 22, height: 22)
        .shadow(color: .black.opacity(on ? 0 : 0.1), radius: 3, y: 1)
        .contentShape(Circle())
        .onHover { hovering = $0 }
        .animation(Theme.settle, value: on)
        .accessibilityLabel(on ? "Deselect" : "Select")
        .accessibilityAddTraits(.isButton)
    }
}

struct SelectionBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let count = model.selection.count
        VStack(spacing: 10) {
            if let popover = model.barPopover {
                Group {
                    switch popover {
                    case .folder: FolderPicker()
                    case .tag: TagPicker()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }
            HStack(spacing: 6) {
                Button { model.clearSelection() } label: {
                    Icon("xmark", size: IconSize.xs)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.white.opacity(0.14)))
                        .contentShape(Circle())
                }
                .buttonStyle(PressStyle())
                .help(L.Select.clear)
                Text(L.Select.count(count))
                    .font(Theme.ui(13, weight: .medium))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                HStack(spacing: 2) {
                    BarButton(title: L.Select.folder, symbol: "folder", active: model.barPopover == .folder, segment: .first) { toggle(.folder) }
                    BarButton(title: L.Select.tag, symbol: "number", active: model.barPopover == .tag, segment: .middle) { toggle(.tag) }
                    BarButton(title: L.Select.delete, symbol: "trash", active: false, segment: .last) { model.deleteSelected() }
                }
            }
            .padding(8)
            .background(Capsule().fill(Theme.pill))
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        }
        .animation(reduceMotion ? Theme.fade : Theme.enter, value: model.barPopover)
        .padding(.bottom, 34)
    }

    private func toggle(_ popover: BarPopover) {
        model.barPopover = model.barPopover == popover ? nil : popover
    }
}

private struct BarButton: View {
    let title: String
    let symbol: String
    let active: Bool
    var segment: Segment = .alone
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Icon(symbol, size: IconSize.sm)
                Text(title).font(Theme.ui(13, weight: .medium))
            }
            .foregroundStyle(active ? Theme.ink : .white)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(segment.shape(16).fill(active ? Color.white : .white.opacity(hovering ? 0.26 : 0.16)))
            .contentShape(segment.shape(16))
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .animation(Theme.hover, value: active)
    }
}

private struct PickerCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(8)
            .frame(width: 260)
            .floatingPanel()
    }
}

private struct PickerRow: View {
    let title: String
    let symbol: String
    var trailing: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Icon(symbol, size: IconSize.sm)
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 18)
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let trailing {
                    Text(trailing).font(Theme.ui(TextSize.small)).foregroundStyle(Theme.tertiary).monospacedDigit()
                }
            }
        }
        .buttonStyle(RowStyle())
    }
}

private struct FolderPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PickerCard {
            VStack(spacing: 2) {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(model.store.folders) { folder in
                            PickerRow(title: folder.name, symbol: "folder", trailing: "\(model.store.count(in: folder))") {
                                model.fileSelected(into: folder)
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
                .scrollIndicators(.never)
                .fixedSize(horizontal: false, vertical: true)
                if !model.store.folders.isEmpty { Rectangle().fill(Theme.hairline).frame(height: 1).padding(.vertical, 4).padding(.horizontal, 10) }
                PickerRow(title: L.Select.newFolder, symbol: "plus") { model.newFolderFromSelection() }
            }
        }
    }
}

private struct TagPicker: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        PickerCard {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Icon("number", size: IconSize.sm).foregroundStyle(Theme.secondary)
                    TextField(L.Select.tagPlaceholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(Theme.ui(13))
                        .focused($focused)
                        .onSubmit(commit)
                }
                .padding(.horizontal, 10)
                .frame(height: Control.row)
                .background(RoundedRectangle(cornerRadius: Radius.row, style: .continuous).fill(Theme.softFill))
                let suggestions = model.tagIndex.mine.prefix(6).filter { text.isEmpty || $0.tag.contains(text.lowercased()) }
                ForEach(suggestions, id: \.tag) { item in
                    PickerRow(title: item.tag, symbol: "number", trailing: "\(item.count)") { model.tagSelected(item.tag) }
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            focused = true
        }
    }

    private func commit() {
        let value = text.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        model.tagSelected(value)
    }
}

struct KeyboardNav: NSViewRepresentable {
    let model: AppModel

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(model: model)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        nonisolated(unsafe) private var monitor: Any?

        func install(model: AppModel) {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                MainActor.assumeIsolated { Self.handle(event, model) } ? nil : event
            }
        }

        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }

        @MainActor private static func handle(_ event: NSEvent, _ model: AppModel) -> Bool {
            guard let window = NSApp.keyWindow, window.canBecomeMain, !(window is NSPanel) else { return false }
            if window.firstResponder is NSText { return false }
            guard !model.paletteShown, !model.composingNote, !model.addMenuOpen,
                  model.selectedID == nil, !model.foldersPage, !model.trashPage, !model.filterOpen else { return false }
            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if flags == .command, key == "a" { model.selectAll(); return true }
            if event.keyCode == 53 {
                if model.barPopover != nil { model.barPopover = nil; return true }
                if model.selecting { model.clearSelection(animated: false); return true }
                if model.focusedID != nil { model.focusedID = nil; return true }
                return false
            }
            guard flags.isEmpty || flags == .shift else { return false }
            switch event.keyCode {
            case 123: model.moveFocus(.left)
            case 124: model.moveFocus(.right)
            case 125: model.moveFocus(.down)
            case 126: model.moveFocus(.up)
            case 36, 49:
                if model.focusedID == nil { model.focusedID = model.hoveredID }
                model.openFocused()
            case 51, 117:
                guard !model.actionIDs.isEmpty else { return false }
                model.deleteSelected()
            default:
                switch key {
                case "t": return openPopover(.tag, model)
                case "f": return openPopover(.folder, model)
                case "x": if let id = model.focusedID { model.toggle(id) } else { return false }
                default: return false
                }
            }
            return true
        }

        @MainActor private static func openPopover(_ popover: BarPopover, _ model: AppModel) -> Bool {
            guard let id = model.focusedID else { return false }
            if model.selection.isEmpty { model.toggle(id) }
            model.barPopover = popover
            return true
        }
    }
}
