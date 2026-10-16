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
                if model.filterOpen {
                    FilterOverlay()
                        .zIndex(1.5)
                }
                if model.viewOpen {
                    ViewOverlay()
                        .zIndex(1.5)
                }
                RadialAdd()
                    .padding(.leading, model.contentLeading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .opacity(model.selecting || model.selectedID != nil ? 0 : 1)
                    .allowsHitTesting(!model.selecting && model.selectedID == nil)
                    .animation(Theme.settle, value: model.selecting)
                    .zIndex(2)
                if model.selecting {
                    SelectionBar()
                        .padding(.leading, model.contentLeading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity.combined(with: .offset(y: 24)))
                        .zIndex(2.2)
                }
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
                Rail()
                    .frame(width: AppModel.railWidth)
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
            if model.barPopover != nil {
                withAnimation(Theme.settle) { model.barPopover = nil }
                return .handled
            }
            if model.selecting {
                model.clearSelection()
                return .handled
            }
            if model.filterOpen || model.viewOpen {
                withAnimation(.spring(duration: 0.35, bounce: 0)) { model.filterOpen = false; model.viewOpen = false }
                return .handled
            }
            guard model.addMenuOpen else { return .ignored }
            withAnimation(.easeOut(duration: 0.2)) { model.addMenuOpen = false }
            return .handled
        }
        .preferredColorScheme(.light)
        .background(WindowChrome())
        .background(KeyboardNav(model: model))
        .onDrop(of: [.fileURL, .url, .image, .plainText], delegate: LibraryDrop(model: model))
        .onPasteCommand(of: [.fileURL, .url, .image, .png, .tiff, .plainText]) { _ in
            model.ingestor.pasteFromClipboard()
        }
        .onChange(of: model.store.saves) { _, _ in model.refresh() }
    }

    @ViewBuilder private var content: some View {
        if !model.store.isLoaded {
            Color.clear
        } else if model.foldersPage {
            FoldersPage()
                .padding(.leading, model.contentLeading)
        } else if model.store.saves.isEmpty {
            EmptyLibrary()
                .padding(.leading, model.contentLeading)
        } else if model.results.isEmpty && model.related.isEmpty && model.folderID != nil && !model.isSearching && model.kind == nil && model.filterCount == 0 {
            EmptyFolder()
                .padding(.leading, model.contentLeading)
        } else if model.results.isEmpty && model.related.isEmpty && model.bookmarksOnly && !model.isSearching && model.kind == nil && model.filterCount == 0 {
            EmptyBookmarks()
                .padding(.leading, model.contentLeading)
        } else if model.results.isEmpty && model.related.isEmpty && model.filterCount > 0 && !model.isSearching {
            EmptyFilters()
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
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
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

            if !model.foldersPage {
                ZStack {
                    filters
                        .opacity(model.addingFocus ? 0.35 : 1)
                        .animation(.easeOut(duration: 0.15), value: model.addingFocus)
                    HStack(spacing: 18) {
                        FolderCrumb()
                        Spacer()
                        ViewButton()
                            .opacity(model.addingFocus ? 0 : 1)
                            .animation(.easeOut(duration: 0.15), value: model.addingFocus)
                    }
                    .padding(.horizontal, Theme.sideInset)
                }

                if model.filterCount > 0 {
                    FilterBar()
                        .opacity(model.addingFocus ? 0.35 : 1)
                        .animation(.easeOut(duration: 0.15), value: model.addingFocus)
                        .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }
        }
        .padding(.top, (Chrome.barHeight - 40) / 2)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background {
            Group {
                LinearGradient(stops: [
                    .init(color: Theme.canvas, location: 0),
                    .init(color: Theme.canvas, location: 0.72),
                    .init(color: Theme.canvas.opacity(0), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var filters: some View {
        @Bindable var model = model
        let counts = model.kindCounts
        let total = counts.values.reduce(0, +)
        return GooeyTabs(items: [
            (L.Filter.all, nil),
            (L.Filter.images, SaveKind.image),
            (L.Filter.links, SaveKind.link),
            (L.Filter.notes, SaveKind.note),
        ], selection: $model.kind, counts: [nil: total, .image: counts[.image] ?? 0, .link: counts[.link] ?? 0, .note: counts[.note] ?? 0])
    }
}

struct SearchFilterButton: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        let count = model.filterCount
        Button {
            withAnimation(.spring(duration: 0.4, bounce: 0.15)) { model.viewOpen = false; model.filterOpen.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 12, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(Theme.ui(10.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Circle().fill(Theme.ink))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundStyle(count > 0 || model.filterOpen ? Theme.ink : Theme.controlMuted)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Capsule().fill(model.filterOpen || hovering ? Theme.softFillStrong : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .animation(Theme.settle, value: count)
        .help(L.Filter.title)
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
            SearchFilterButton()
            if model.query.isEmpty {
                Text("⌘K")
                    .font(Theme.ui(11, weight: .medium))
                    .foregroundStyle(Theme.controlMuted)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.white))
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
        .background(Capsule().fill(hovering ? Theme.softTarget : Theme.softHover))
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
                    .background(Circle().fill(Theme.surface))
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
                    HStack(spacing: 2) {
                        Button(L.Note.cancel) { requestClose() }
                            .poolSecondary(.first)
                            .keyboardShortcut(.cancelAction)
                        Button(L.Note.save) {
                            model.ingestor.addNote(text)
                            close()
                        }
                        .poolPrimary(.last)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
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
