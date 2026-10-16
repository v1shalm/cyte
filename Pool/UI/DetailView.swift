import AppKit
import SwiftUI

struct DetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let save: Save
    let namespace: Namespace.ID

    @FocusState private var focused: Bool
    @State private var inspectorShown = false

    var body: some View {
        ZStack {
            Theme.detailBackdrop
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { close(animated: true) }
                .transition(.opacity)

            HStack(spacing: 0) {
                media
                    .padding(.horizontal, 56)
                    .padding(.top, 64)
                    .padding(.bottom, 48)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { close(animated: true) }

                Inspector(save: save)
                    .frame(width: 340)
                    .modifier(InspectorChrome())
                    .offset(x: inspectorShown || reduceMotion ? 0 : 24)
                    .opacity(inspectorShown ? 1 : 0)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.escape) {
            close(animated: false)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            model.select(offset: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            model.select(offset: 1)
            return .handled
        }
        .onAppear {
            focused = true
            withAnimation(Theme.open.delay(0.06)) { inspectorShown = true }
        }
    }

    @ViewBuilder private var media: some View {
        switch save.kind {
        case .image:
            let url = model.store.url(for: save, file: save.original) ?? model.store.url(for: save, file: save.thumbnail)
            Thumb(url: url, maxPixel: 2800, contentMode: .fit)
                .aspectRatio(save.aspect > 0 ? save.aspect : 1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .matchedGeometryEffect(id: save.id, in: namespace, isSource: true)
                .shadow(color: .black.opacity(0.12), radius: 30, y: 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .link:
            LinkHero(save: save)
                .matchedGeometryEffect(id: save.id, in: namespace, isSource: true)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .note:
            NoteHero(save: save)
                .matchedGeometryEffect(id: save.id, in: namespace, isSource: true)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func close(animated: Bool) {
        if animated, !reduceMotion {
            withAnimation(Theme.open) { model.selectedID = nil }
        } else {
            model.selectedID = nil
        }
    }
}

private struct LinkHero: View {
    @Environment(AppModel.self) private var model
    let save: Save

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if save.thumbnail != nil {
                Thumb(url: model.store.url(for: save, file: save.thumbnail), maxPixel: 2000)
                    .aspectRatio(save.aspect > 0 ? save.aspect : 1.91, contentMode: .fit)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Favicon(url: model.store.url(for: save, file: save.favicon))
                    Text(save.host ?? "")
                        .font(Theme.ui(12, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
                Text(save.displayTitle)
                    .font(Theme.serif(28))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = save.url {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label(L.Detail.openLink, systemImage: "arrow.up.right")
                    }
                    .poolPrimary()
                    .padding(.top, 6)
                }
            }
            .padding(24)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.10), radius: 30, y: 16)
    }
}

private struct NoteHero: View {
    @Environment(AppModel.self) private var model
    let save: Save
    @State private var text = ""

    var body: some View {
        TextEditor(text: $text)
            .font(Theme.serif(20))
            .lineSpacing(5)
            .scrollContentBackground(.hidden)
            .foregroundStyle(Theme.ink)
            .padding(28)
            .frame(minHeight: 240, maxHeight: 560)
            .background(Theme.note)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.08), radius: 30, y: 16)
            .onAppear { text = save.text ?? "" }
            .onChange(of: text) { _, value in
                guard value != save.text else { return }
                model.store.modify(save.id) { $0.text = value }
            }
    }
}

private struct Inspector: View {
    @Environment(AppModel.self) private var model
    let save: Save

    @State private var title = ""
    @State private var note = ""
    @State private var newTag = ""
    @State private var similar: [String] = []
    @State private var showText = false
    @FocusState private var tagFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if model.enricher.activeID == save.id || (save.enriched == 0 && !save.pending && model.enricher.modelAvailable) {
                        Text(L.Detail.reading)
                            .font(Theme.ui(12))
                            .foregroundStyle(Theme.secondary)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.fill))
                            .lifted(RoundedRectangle(cornerRadius: 10, style: .continuous), shadow: 0.03)
                            .borderBeam(size: .sm, palette: Theme.bold ? .accent : .silver, cornerRadius: 10, duration: 1.8)
                    }
                    if let summary = save.summary, !summary.isEmpty {
                        section(L.Detail.summary) {
                            Text(summary)
                                .font(Theme.ui(13))
                                .foregroundStyle(Theme.secondary)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                    }
                    if !save.palette.isEmpty { palette }
                    tags
                    noteField
                    if let text = save.ocrText, !text.isEmpty { ocr(text) }
                    if !similar.isEmpty { similarGrid }
                }
                .padding(.horizontal, 24)
                .padding(.top, Theme.bold ? 28 : 60)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.never)
            actions
        }
        .background(Theme.surface)
        .onAppear(perform: load)
        .onChange(of: save.id) { _, _ in load() }
        .task(id: save.id) {
            similar = save.kind == .note ? [] : await model.enricher.similar(to: save)
        }
    }

    private func load() {
        title = save.title
        note = save.note
        newTag = ""
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.serif(24))
                .foregroundStyle(Theme.ink)
                .lineLimit(1...4)
                .onSubmit(commitTitle)
                .onChange(of: title) { _, _ in commitTitle() }
            HStack(spacing: 6) {
                if let url = save.url, let host = save.host {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text(host).underline(color: Theme.hairline)
                    }
                    .buttonStyle(.plain)
                    Text("·")
                }
                Text(save.createdAt.formatted(.relative(presentation: .named)))
            }
            .font(Theme.ui(12))
            .foregroundStyle(Theme.tertiary)
        }
    }

    private func commitTitle() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != save.title else { return }
        model.store.modify(save.id) { $0.title = trimmed }
    }

    private var palette: some View {
        HStack(spacing: 8) {
            ForEach(save.palette, id: \.self) { hex in
                Button {
                    model.selectedID = nil
                    model.query = hex.lowercased()
                } label: {
                    Circle()
                        .fill(Theme.color(hex: hex))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(Theme.hairline))
                }
                .buttonStyle(PressStyle(scale: 0.9))
                .help(hex)
            }
        }
    }

    private var tags: some View {
        section(L.Detail.tags) {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(save.tags, id: \.self) { tag in
                    TagChip(text: tag, strong: true) {
                        model.selectedID = nil
                        model.query = "#\(tag)"
                    } remove: {
                        model.store.modify(save.id) { $0.tags.removeAll { $0 == tag } }
                    }
                }
                ForEach(save.labels.filter { !save.tags.contains($0) }, id: \.self) { label in
                    TagChip(text: label, strong: false, action: {
                        model.selectedID = nil
                        model.query = label
                    }, remove: nil)
                }
                TextField(L.Detail.addTag, text: $newTag)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(12))
                    .frame(width: 84)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    .focused($tagFocused)
                    .onSubmit(addTag)
            }
        }
    }

    private func addTag() {
        let tag = newTag.lowercased().trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard !tag.isEmpty else { return }
        model.store.modify(save.id) { save in
            if !save.tags.contains(tag) { save.tags.append(tag) }
        }
        newTag = ""
        tagFocused = true
    }

    private var noteField: some View {
        section(L.Detail.note) {
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text(L.Detail.notePlaceholder)
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $note)
                    .font(Theme.ui(13))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 8)
                    .frame(minHeight: 84)
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.fill))
            .lifted(RoundedRectangle(cornerRadius: 10, style: .continuous), shadow: 0)
            .onChange(of: note) { _, value in
                guard value != save.note else { return }
                model.store.modify(save.id) { $0.note = value }
            }
        }
    }

    private func ocr(_ text: String) -> some View {
        section(L.Detail.text) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(showText ? nil : 4)
                    .textSelection(.enabled)
                if text.split(separator: "\n").count > 4 || text.count > 220 {
                    Button(showText ? L.Detail.showLess : L.Detail.showAll) { showText.toggle() }
                        .buttonStyle(.plain)
                        .font(Theme.ui(12, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private var similarGrid: some View {
        section(L.Detail.similar) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(similar, id: \.self) { id in
                    if let other = model.store.save(id: id) {
                        Button {
                            model.selectedID = id
                        } label: {
                            Thumb(url: model.store.url(for: other, file: other.thumbnail), maxPixel: 300)
                                .aspectRatio(1, contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 4) {
            if let url = save.url {
                ActionButton(symbol: "arrow.up.right", title: L.Detail.openLink) { NSWorkspace.shared.open(url) }
            }
            ActionButton(symbol: "doc.on.doc", title: L.Detail.copy) {
                Clipboard.copy(save, store: model.store)
                model.feedback.toast(L.Toast.copied)
            }
            ActionButton(symbol: "folder", title: L.Detail.reveal) {
                NSWorkspace.shared.activateFileViewerSelecting([model.store.folder(for: save)])
            }
            Spacer()
            ActionButton(symbol: "trash", title: L.Detail.delete) { model.delete(save) }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.ui(11, weight: .medium))
                .foregroundStyle(Theme.tertiary)
            content()
        }
    }
}

private struct TagChip: View {
    let text: String
    let strong: Bool
    let action: () -> Void
    let remove: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: action) {
                Text(text)
                    .font(Theme.ui(12, weight: strong ? .medium : .regular))
                    .foregroundStyle(strong ? Theme.ink : Theme.secondary)
            }
            .buttonStyle(.plain)
            if let remove, hovering {
                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Capsule().fill(strong ? Theme.fillStrong : Theme.fill))
        .lifted(Capsule(), shadow: strong ? 0.06 : 0.03)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
    }
}

private struct InspectorChrome: ViewModifier {
    func body(content: Content) -> some View {
        if Theme.bold {
            content
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))
                .shadow(color: .black.opacity(0.08), radius: 24, y: 10)
                .padding(10)
        } else {
            content
                .overlay(alignment: .leading) { Rectangle().fill(Theme.hairline).frame(width: 1) }
        }
    }
}

private struct ActionButton: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.actionIcon)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.action))
                .lifted(Circle(), shadow: 0.06)
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .help(title)
        .accessibilityLabel(title)
    }
}
