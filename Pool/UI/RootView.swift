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
                .ignoresSafeArea()

            ZStack(alignment: .top) {
                content
                if model.addMenuOpen || model.paletteShown || model.folderListOpen {
                    Theme.paletteBackdrop
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(Theme.exit) {
                                model.addMenuOpen = false
                                model.paletteShown = false
                                model.folderListOpen = false
                            }
                        }
                        .transition(.opacity.animation(Theme.exit))
                        .zIndex(2)
                }
                if model.filterOpen {
                    FilterOverlay()
                        .zIndex(1.5)
                }
                if model.viewOpen {
                    ViewOverlay()
                        .zIndex(1.5)
                }
                TopBar()
                if model.selecting {
                    SelectionBar()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity.combined(with: .offset(y: 24)))
                        .zIndex(2.2)
                } else if model.selectedID == nil {
                    DockHost()
                        .transition(.opacity.combined(with: .offset(y: 24)))
                        .zIndex(2.1)
                }
            }
            .ignoresSafeArea()

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
        .background(Theme.canvas.ignoresSafeArea())
        .onKeyPress(.escape) {
            if model.trashConfirm != nil {
                model.trashConfirm = nil
                return .handled
            }
            if model.barPopover != nil {
                model.barPopover = nil
                return .handled
            }
            if model.selecting {
                model.clearSelection(animated: false)
                return .handled
            }
            if model.filterOpen || model.viewOpen {
                model.filterOpen = false
                model.viewOpen = false
                return .handled
            }
            if model.paletteShown {
                model.paletteShown = false
                return .handled
            }
            if model.folderListOpen {
                withAnimation(Theme.exit) { model.folderListOpen = false }
                return .handled
            }
            guard model.addMenuOpen else { return .ignored }
            withAnimation(Theme.exit) { model.addMenuOpen = false }
            return .handled
        }
        .preferredColorScheme(.light)
        .background(WindowChrome())
        .background(KeyboardNav(model: model))
        .onDrop(of: [.fileURL, .url, .movie, .video, .gif, .image, .plainText], delegate: LibraryDrop(model: model))
        .onPasteCommand(of: [.fileURL, .url, .movie, .video, .gif, .image, .png, .tiff, .plainText]) { _ in
            model.ingestor.pasteFromClipboard()
        }
        .onChange(of: model.store.saves) { _, _ in model.refresh() }
    }

    @ViewBuilder private var content: some View {
        if !model.store.isLoaded {
            Color.clear
        } else if model.trashPage {
            TrashPage()
        } else if model.foldersPage {
            FoldersPage()
        } else if model.store.saves.isEmpty {
            EmptyLibrary()
        } else if model.results.isEmpty && model.related.isEmpty && model.folderID != nil && !model.isSearching && model.kind == nil && model.filterCount == 0 {
            EmptyFolder()
        } else if model.results.isEmpty && model.related.isEmpty && model.filterCount > 0 && !model.isSearching {
            EmptyFilters()
        } else if model.results.isEmpty && model.related.isEmpty {
            EmptySearch()
        } else {
            MasonryGrid(namespace: namespace)
        }
    }
}

struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                PageTitle()
                if !onPage {
                    filters
                }
                Spacer(minLength: 12)
                if model.enricher.activeID != nil {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                        .help(L.Detail.reading)
                }
                if !onPage {
                    ViewControls()
                } else if model.trashPage, !model.store.trash.isEmpty {
                    Button(L.Trash.emptyTrash) {
                        withAnimation(Theme.settle) { model.trashConfirm = .all }
                    }
                    .poolSecondary()
                    .transition(.opacity)
                }
            }
            .frame(height: Control.regular)
            .padding(.horizontal, Theme.sideInset)

            if model.openFolder != nil {
                Text(L.Folders.addHint)
                    .font(Theme.ui(TextSize.small))
                    .foregroundStyle(Theme.tertiary)
                    .frame(height: Chrome.hintHeight, alignment: .bottom)
                    .padding(.leading, Theme.sideInset + Control.small + 10)
                    .transition(.opacity)
            }

            if model.filterCount > 0 && !onPage {
                FilterBar()
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .padding(.top, Chrome.barHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            VStack(spacing: 0) {
                Theme.canvas
                LinearGradient(colors: [Theme.canvas, Theme.canvas.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: Chrome.fade)
            }
            .padding(.bottom, -Chrome.fade)
            .allowsHitTesting(false)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var onPage: Bool { model.foldersPage || model.trashPage }

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
        .fixedSize()
    }
}

struct PageTitle: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            if let folder = currentFolder {
                Button {
                    withAnimation(Theme.settle) { model.foldersPage = true }
                } label: {
                    Icon("chevron.left", size: IconSize.sm)
                        .foregroundStyle(Theme.ink)
                        .frame(width: Control.small, height: Control.small)
                        .background(Circle().fill(hovering ? Theme.softFillStrong : Theme.softFill))
                        .contentShape(Circle())
                }
                .buttonStyle(PressStyle())
                .onHover { hovering = $0 }
                .animation(Theme.hover, value: hovering)
                .help(L.Folders.allFolders)
                .accessibilityLabel(L.Folders.allFolders)
                Text(folder.name)
                    .help(folder.name)
            } else {
                Text(title)
            }
        }
        .font(Theme.serif(TitleSize.title))
        .foregroundStyle(Theme.ink)
        .lineLimit(1)
        .truncationMode(.tail)
        .accessibilityAddTraits(.isHeader)
        .transition(.opacity)
        .animation(Theme.fade, value: title)
    }

    private var currentFolder: Folder? {
        guard !model.foldersPage, !model.trashPage, let id = model.folderID else { return nil }
        return model.store.folder(id: id)
    }

    private var title: String {
        if model.trashPage { return L.Trash.title }
        if model.foldersPage { return L.Folders.allFolders }
        if let folder = currentFolder { return folder.name }
        return L.Folders.everything
    }
}

struct LibraryDrop: DropDelegate {
    let model: AppModel

    private static let dropTypes: [UTType] = [.fileURL, .url, .movie, .video, .gif, .image, .plainText]

    private func external(_ info: DropInfo) -> Bool {
        !info.hasItemsConforming(to: [UTType(exportedAs: AppModel.saveType)])
            && info.hasItemsConforming(to: Self.dropTypes)
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
        model.ingestor.ingest(providers: info.itemProviders(for: Self.dropTypes))
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
            Theme.scrim
            RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                .strokeBorder(Theme.dropDash, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                .padding(18)
            VStack(spacing: 12) {
                Icon("arrow.down", size: IconSize.lg)
                    .foregroundStyle(Theme.ink)
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
    static let bottomInset: CGFloat = Dock.clearance

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            if let toast = model.feedback.toast {
                ToastView(toast: toast)
                    .onHover { model.feedback.holdToast($0) }
                    .id(toast.id)
                    .padding(.bottom, Self.bottomInset)
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .opacity.combined(with: .offset(y: 6)).animation(Theme.exit)
                    ))
            }
            if let ask = model.why.ask, !ask.floating {
                WhyCard(prompt: model.why)
                    .id(ask.id)
                    .padding(.bottom, Self.bottomInset)
                    .transition(WhyCard.exit)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.35, bounce: 0), value: model.feedback.toast?.id)
        .animation(.spring(duration: 0.35, bounce: 0), value: model.why.ask?.id)
    }
}

struct ToastView: View {
    let toast: Feedback.Toast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var width: CGFloat = 40
    @State private var bloomed = false

    var body: some View {
        let actionable = toast.actionTitle != nil && toast.action != nil
        HStack(spacing: 16) {
            Text(toast.message)
                .font(Theme.ui(TextSize.large))
                .foregroundStyle(.white)
                .monospacedDigit()
            if let title = toast.actionTitle, let action = toast.action {
                Button(title, action: action)
                    .buttonStyle(PillSolidStyle())
                    .keyboardShortcut(title == L.Toast.undo ? KeyboardShortcut("z", modifiers: .command) : nil)
            }
        }
        .fixedSize()
        .padding(.leading, 20)
        .padding(.trailing, actionable ? 8 : 20)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
        .opacity(bloomed ? 1 : 0)
        .blur(radius: bloomed || reduceMotion ? 0 : 4)
        .frame(width: bloomed ? width : 48, height: 48)
        .background(Capsule().fill(Theme.pill))
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
        .overlay(
            Capsule()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
        .scaleEffect(bloomed || reduceMotion ? 1 : 0.9)
        .onAppear {
            withAnimation(reduceMotion ? Theme.fade : Theme.pop) { bloomed = true }
            AccessibilityNotification.Announcement(toast.message).post()
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
            Theme.scrim
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
                        .font(Theme.ui(TextSize.caption, weight: .medium))
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
            .floatingPanel(radius: Radius.sheet)
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
