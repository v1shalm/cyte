import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .top) {
            Theme.canvas
                .background(alignment: .topLeading) {
                    if let web = model.xImport.webView {
                        WebHost(view: web)
                            .frame(width: 1000, height: 800)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .ignoresSafeArea()

            ZStack(alignment: .top) {
                content
                if model.addingFocus {
                    Theme.canvas.opacity(0.82)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                model.addMenuOpen = false
                                model.linkEntryShown = false
                            }
                        }
                        .transition(.opacity)
                }
                RadialAdd()
                    .padding(.leading, model.contentLeading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(2)
                TopBar()
                    .padding(.leading, model.contentLeading)
                if model.linkEntryShown {
                    LinkEntry()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.2), value: model.linkEntryShown)
            .ignoresSafeArea()

            if model.sidebarShown {
                Sidebar()
                    .frame(width: AppModel.sidebarWidth)
                    .padding(.vertical, 10)
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .ignoresSafeArea()
                    .transition(.asymmetric(
                        insertion: .offset(x: -24).combined(with: .opacity),
                        removal: .offset(x: -24).combined(with: .opacity)
                    ))
                    .zIndex(1)
            }

            if let id = model.selectedID, let save = model.store.save(id: id) {
                DetailView(save: save, namespace: namespace)
                    .ignoresSafeArea()
                    .zIndex(5)
            }

            if model.voiceNoteShown {
                VoiceNoteOverlay()
                    .ignoresSafeArea()
                    .zIndex(6.5)
                    .transition(.opacity.animation(Theme.fade))
            }

            if model.composingNote {
                NoteComposer()
                    .ignoresSafeArea()
                    .zIndex(6)
            }

            if let genie = model.genie {
                GenieOverlay(request: genie) { model.genie = nil }
                    .ignoresSafeArea()
                    .id(genie.id)
                    .zIndex(7.5)
            }

            if model.dropTargeted {
                DropOverlay()
                    .ignoresSafeArea()
                    .zIndex(7)
                    .transition(.opacity.animation(Theme.fade))
            }

            ToastHost()
                .ignoresSafeArea()
                .zIndex(8)
        }
        .blur(radius: model.paletteShown || model.xImport.isShown ? 24 : 0)
        .background(Theme.canvas.ignoresSafeArea())
        .overlay {
            if model.paletteShown {
                PaletteBackdrop { model.paletteShown = false }
            } else if model.xImport.isShown {
                ZStack {
                    Theme.sheetBackdrop
                        .contentShape(Rectangle())
                    XImportView()
                }
                .ignoresSafeArea()
            }
        }
        .onKeyPress(.escape) {
            guard model.addMenuOpen else { return .ignored }
            withAnimation(.easeOut(duration: 0.2)) { model.addMenuOpen = false }
            return .handled
        }
        .preferredColorScheme(.light)
        .background(WindowChrome())
        .onDrop(of: [.fileURL, .url, .image, .plainText], delegate: LibraryDrop(model: model))
        .onPasteCommand(of: [.fileURL, .url, .image, .png, .tiff, .plainText]) { _ in
            model.ingestor.pasteFromClipboard()
        }
        .onChange(of: model.store.saves) { _, _ in model.refresh() }
    }

    @ViewBuilder private var content: some View {
        if !model.store.isLoaded {
            Color.clear
        } else if model.store.saves.isEmpty {
            EmptyLibrary()
                .padding(.leading, model.contentLeading)
        } else if model.results.isEmpty && model.related.isEmpty && model.folderID != nil && !model.isSearching && model.kind == nil {
            EmptyFolder()
                .padding(.leading, model.contentLeading)
        } else if model.results.isEmpty && model.related.isEmpty {
            EmptySearch()
                .padding(.leading, model.contentLeading)
        } else {
            MasonryGrid(namespace: namespace)
        }
    }
}

private struct LinkEntry: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var invalid = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                    TextField(L.Add.linkPlaceholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(Theme.ui(15))
                        .foregroundStyle(Theme.ink)
                        .focused($focused)
                        .onSubmit(save)
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(link == nil ? Theme.tertiary : .white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(link == nil ? Theme.chip : Theme.ink))
                        .lifted(Circle(), active: link == nil, shadow: 0)
                        .animation(.easeOut(duration: 0.15), value: link == nil)
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
                .frame(width: 360, height: 50)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.black.opacity(0.07)))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                .shadow(color: .black.opacity(0.1), radius: 24, y: 12)
                if invalid {
                    Text(L.Add.linkInvalid)
                        .font(Theme.ui(12))
                        .foregroundStyle(Theme.secondary)
                        .padding(.leading, 16)
                        .transition(.opacity)
                }
            }
            .padding(.top, Chrome.barHeight)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            focused = true
        }
        .onAppear {
            if let clip = NSPasteboard.general.string(forType: .string), Self.parse(clip) != nil { text = clip }
        }
        .onChange(of: text) { _, _ in invalid = false }
        .onExitCommand { model.linkEntryShown = false }
    }

    private var link: URL? { Self.parse(text) }

    private func save() {
        guard let url = link else {
            withAnimation(.easeOut(duration: 0.15)) { invalid = true }
            return
        }
        model.ingestor.ingest(link: url, source: "add")
        model.linkEntryShown = false
    }

    static func parse(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = Ingestor.webURL(in: trimmed) { return url }
        guard !trimmed.contains("://"), trimmed.contains("."), !trimmed.hasPrefix(".") else { return nil }
        return Ingestor.webURL(in: "https://" + trimmed)
    }
}

private struct PaletteBackdrop: View {
    let close: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Theme.paletteBackdrop
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                CommandPalette(close: close)
                    .padding(.top, max(56, (proxy.size.height - CommandPalette.maxHeight) / 2))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .ignoresSafeArea()
    }
}

struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                HStack(spacing: 8) {
                    if !model.sidebarShown {
                        Spacer().frame(width: Chrome.lightsWidth - 6)
                        SidebarToggle()
                    }
                    Spacer()
                    if model.enricher.activeID != nil {
                        ProgressView()
                            .controlSize(.mini)
                            .padding(.trailing, 6)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 18)

                SearchTrigger()
            }
            .frame(height: 40)

            ZStack {
                filters
                    .opacity(model.addingFocus ? 0.35 : 1)
                    .animation(.easeOut(duration: 0.15), value: model.addingFocus)
                HStack(spacing: 18) {
                    Spacer()
                    SortMenu()
                        .opacity(model.addingFocus ? 0 : 1)
                        .animation(.easeOut(duration: 0.15), value: model.addingFocus)
                }
                .padding(.horizontal, Theme.sideInset)
            }

            if !model.tagRow.isEmpty {
                TagRow()
                    .opacity(model.addingFocus ? 0.35 : 1)
                    .animation(.easeOut(duration: 0.15), value: model.addingFocus)
            }
        }
        .padding(.top, (Chrome.barHeight - 40) / 2)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background {
            Group {
                if Theme.bold {
                    LinearGradient(stops: [
                        .init(color: Theme.canvas, location: 0),
                        .init(color: Theme.canvas, location: 0.42),
                        .init(color: Theme.canvas.opacity(0.94), location: 0.52),
                        .init(color: Theme.canvas.opacity(0.8), location: 0.62),
                        .init(color: Theme.canvas.opacity(0.58), location: 0.72),
                        .init(color: Theme.canvas.opacity(0.34), location: 0.82),
                        .init(color: Theme.canvas.opacity(0.14), location: 0.91),
                        .init(color: Theme.canvas.opacity(0.04), location: 0.97),
                        .init(color: Theme.canvas.opacity(0), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                    .padding(.bottom, -18)
                } else {
                    LinearGradient(stops: [
                        .init(color: Theme.canvas, location: 0),
                        .init(color: Theme.canvas, location: 0.72),
                        .init(color: Theme.canvas.opacity(0), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var filters: some View {
        @Bindable var model = model
        return GooeyTabs(items: [
            (L.Filter.all, nil),
            (L.Filter.images, SaveKind.image),
            (L.Filter.links, SaveKind.link),
            (L.Filter.notes, SaveKind.note),
        ], selection: $model.kind)
    }
}

struct SearchTrigger: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.controlMuted)
            if model.query.isEmpty {
                Text(L.Search.placeholder)
                    .font(Theme.ui(13))
                    .foregroundStyle(Theme.controlMuted)
            } else {
                Text(model.query)
                    .font(Theme.ui(13, weight: .medium))
                    .foregroundStyle(Theme.controlText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if model.query.isEmpty {
                Text("⌘K")
                    .font(Theme.ui(11, weight: .medium))
                    .foregroundStyle(Theme.controlMuted)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.controlChip))
                    .lifted(RoundedRectangle(cornerRadius: 5, style: .continuous), shadow: 0)
            } else {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.controlMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 460, height: 40)
        .background(Capsule().fill(hovering ? Theme.controlHover : Theme.control).shadow(color: .black.opacity(Theme.controlShadow * (hovering ? 1.8 : 1)), radius: hovering ? 10 : 6, y: 2))
        .overlay(Capsule().strokeBorder(Theme.bold ? .clear : Theme.hairline))
        .borderBeam(size: .sm, active: model.voiceSearch.isListening, cornerRadius: 18, duration: 1.6)
        .contentShape(Capsule())
        .onTapGesture { model.paletteShown = true }
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
    }
}

struct LibraryDrop: DropDelegate {
    let model: AppModel

    private func external(_ info: DropInfo) -> Bool {
        !info.hasItemsConforming(to: [UTType(exportedAs: AppModel.saveType)])
            && info.hasItemsConforming(to: [.fileURL, .url, .image, .plainText])
    }

    func validateDrop(info: DropInfo) -> Bool { external(info) }

    func dropEntered(info: DropInfo) { model.dropTargeted = external(info) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: external(info) ? .copy : .forbidden)
    }

    func dropExited(info: DropInfo) { model.dropTargeted = false }

    func performDrop(info: DropInfo) -> Bool {
        model.dropTargeted = false
        guard external(info) else { return false }
        model.ingestor.ingest(providers: info.itemProviders(for: [.fileURL, .url, .image, .plainText]))
        return true
    }
}

struct SortMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu { options } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(Theme.ui(12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(Theme.ink).shadow(color: .black.opacity(Theme.controlShadow), radius: 6, y: 2))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var options: some View {
        Picker(L.Sort.label, selection: Bindable(model).sort) {
            Label(L.Sort.newest, systemImage: "arrow.down").tag(SortOrder.newest)
            Label(L.Sort.oldest, systemImage: "arrow.up").tag(SortOrder.oldest)
            Label(L.Sort.shuffle, systemImage: "shuffle").tag(SortOrder.shuffle)
        }
        .pickerStyle(.inline)
    }

    private var symbol: String { model.sort == .shuffle ? "shuffle" : "arrow.up.arrow.down" }

    private var title: String {
        switch model.sort {
        case .newest: L.Sort.newest
        case .oldest: L.Sort.oldest
        case .shuffle: L.Sort.shuffle
        }
    }
}

struct EmptyLibrary: View {
    var body: some View {
        VStack(spacing: 0) {
            Text(L.Empty.title)
                .font(Theme.serif(44, light: true))
                .foregroundStyle(Theme.ink)
            Text(L.Empty.body)
                .font(Theme.ui(14))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, 12)
                .padding(.bottom, 30)
            AddPanel(compact: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyFolder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Theme.tertiary)
                .padding(.bottom, 4)
            Text(L.Folders.emptyTitle)
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
            Text(L.Folders.emptyBody)
                .font(Theme.ui(13))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptySearch: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Text(L.Search.emptyTitle(model.query.isEmpty ? (model.kind?.rawValue ?? "") : model.query))
                .font(Theme.serif(24))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(L.Search.emptyBody)
                .font(Theme.ui(13))
                .foregroundStyle(Theme.secondary)
            Button(L.Search.emptyPrimary) {
                model.query = ""
                model.kind = nil
            }
            .poolSecondary()
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DropOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Theme.canvas.opacity(0.78)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.dropDash, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                .padding(18)
            VStack(spacing: 12) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.actionIcon)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Theme.bold ? Theme.ink : Theme.surface))
                    .overlay(Circle().strokeBorder(Theme.hairline))
                    .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
                Text(L.dropOverlay)
                    .font(Theme.ui(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
            .scaleEffect(shown || reduceMotion ? 1 : 0.94)
            .opacity(shown ? 1 : 0)
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(Theme.settle) { shown = true } }
    }
}

struct ToastHost: View {
    @Environment(AppModel.self) private var model
    static let bottomInset: CGFloat = 28

    var body: some View {
        VStack {
            Spacer()
            if let toast = model.feedback.toast {
                ToastView(toast: toast)
                    .id(toast.id)
                    .padding(.bottom, Self.bottomInset)
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.35, bounce: 0), value: model.feedback.toast?.id)
    }
}

struct ToastView: View {
    let toast: Feedback.Toast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var width: CGFloat = 40
    @State private var bloomed = false

    var body: some View {
        HStack(spacing: 16) {
            Text(toast.message)
                .font(Theme.ui(14))
                .foregroundStyle(.white)
                .padding(.leading, toast.actionTitle == nil ? 10 : 10)
            if let title = toast.actionTitle, let action = toast.action {
                Button(title, action: action).buttonStyle(PillSolidStyle())
            }
        }
        .fixedSize()
        .padding(8)
        .padding(.horizontal, toast.actionTitle == nil ? 6 : 0)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
        .opacity(bloomed ? 1 : 0)
        .blur(radius: bloomed || reduceMotion ? 0 : 6)
        .frame(width: bloomed ? width : 44, height: 48)
        .background(Capsule().fill(Theme.pill))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .scaleEffect(bloomed || reduceMotion ? 1 : 0.5)
        .onAppear {
            withAnimation(reduceMotion ? Theme.fade : .spring(duration: 0.55, bounce: 0.28)) { bloomed = true }
        }
    }
}

struct NoteComposer: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var confirming = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.06)
                .contentShape(Rectangle())
                .onTapGesture { requestClose() }
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(L.Note.placeholder)
                            .font(Theme.serif(19))
                            .foregroundStyle(Theme.tertiary)
                            .padding(.horizontal, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(Theme.serif(19))
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                        .frame(minHeight: 150, maxHeight: 320)
                }
                .padding(20)
                HStack {
                    Text("⌘↩")
                        .font(Theme.ui(11, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                    Spacer()
                    Button(L.Note.cancel) { requestClose() }
                        .poolSecondary()
                        .keyboardShortcut(.cancelAction)
                    Button(L.Note.save) {
                        model.ingestor.addNote(text)
                        close()
                    }
                    .poolPrimary()
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
            }
            .frame(width: 560)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.16), radius: 40, y: 20)
            .overlay(alignment: .bottom) {
                if confirming {
                    QuestionPill(message: L.Note.discardQuestion, soft: L.Note.discardYes, solid: L.Note.discardNo, onSoft: { close() }) {
                        withAnimation(Theme.settle) { confirming = false }
                        focused = true
                    }
                    .offset(y: 36)
                    .transition(.opacity)
                }
            }
            .padding(.top, 120)
        }
        .onAppear { focused = true }
    }

    private func requestClose() {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            close()
        } else {
            withAnimation(Theme.settle) { confirming = true }
        }
    }

    private func close() {
        text = ""
        model.composingNote = false
    }
}

struct TagRow: View {
    @Environment(AppModel.self) private var model
    @State private var width: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.tagRow, id: \.tag) { item in
                    TagPill(title: item.tag, active: model.activeTags.contains(item.tag)) {
                        withAnimation(Theme.settle) { model.toggleTag(item.tag) }
                    }
                }
                if !model.activeTags.isEmpty {
                    Button {
                        withAnimation(Theme.settle) { model.activeTags = [] }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                            Text(L.Filter.clear).font(Theme.ui(12.5, weight: .medium))
                        }
                        .foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressStyle(scale: 0.96))
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Theme.sideInset)
            .frame(minWidth: width, alignment: .center)
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width = $0 })
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 24)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 24)
            }
        )
        .frame(height: 34)
    }
}

private struct TagPill: View {
    let title: String
    let active: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(12.5, weight: .medium))
                .foregroundStyle(active ? Color.white : (hovering ? Theme.ink : Theme.secondary))
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Capsule().fill(active ? Theme.ink : (hovering ? Theme.softFill : Color.white)))
                .overlay(Capsule().strokeBorder(active ? Color.clear : Theme.hairline))
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .animation(Theme.hover, value: active)
    }
}
