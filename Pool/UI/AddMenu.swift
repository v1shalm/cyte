import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AddMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Option: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let run: () -> Void
    }

    @State private var clipboardLink: URL?
    @State private var hovering = false

    static let closedWidth: CGFloat = 80
    static let height: CGFloat = Control.regular
    private let bubble: CGFloat = 38
    private let step: CGFloat = 46
    private let firstGap: CGFloat = 12

    private var open: Bool { model.addMenuOpen }

    var body: some View {
        let options = makeOptions()
        ZStack(alignment: .topTrailing) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                AddMenuRow(option: option, bubble: bubble) {
                    withAnimation(Theme.exit) { model.addMenuOpen = false }
                    option.run()
                }
                .offset(x: (bubble - Self.height) / 2, y: open ? rowY(index) : 0)
                .scaleEffect(open || reduceMotion ? 1 : 0.9, anchor: .topTrailing)
                .opacity(open ? 1 : 0)
                .animation(rowMotion(index, count: options.count), value: open)
                .allowsHitTesting(open)
            }

            trigger
        }
        .frame(width: 280, height: Self.height + firstGap + CGFloat(options.count) * step, alignment: .topTrailing)
        .onChange(of: open) { _, isOpen in
            if isOpen { clipboardLink = Self.readClipboardLink() }
        }
        .onAppear { clipboardLink = Self.readClipboardLink() }
    }

    private var trigger: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { model.addMenuOpen.toggle() }
        } label: {
            HStack(spacing: 6) {
                Icon("plus", size: IconSize.sm)
                    .rotationEffect(.degrees(open ? 45 : 0))
                if !open {
                    Text(L.Add.button)
                        .font(Theme.ui(TextSize.body, weight: .medium))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .foregroundStyle(.white)
            .frame(width: open ? Self.height : Self.closedWidth, height: Self.height)
            .background(Capsule().fill(hovering ? Theme.inkHover : Theme.ink))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(Theme.hover, value: hovering)
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.34, bounce: 0.16), value: open)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(open ? L.Add.close : L.Add.button)
    }

    private func rowY(_ index: Int) -> CGFloat {
        Self.height + firstGap + CGFloat(index) * step - (bubble - Self.height) / 2
    }

    private func rowMotion(_ index: Int, count: Int) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.15) }
        if open { return .spring(duration: 0.3, bounce: 0.12).delay(Double(index) * 0.03) }
        return Theme.exit.delay(Double(count - 1 - index) * 0.015)
    }

    private func makeOptions() -> [Option] {
        [
            linkOption,
            Option(id: "files", symbol: "photo.on.rectangle", title: L.Add.images) { chooseFiles() },
            Option(id: "note", symbol: "text.alignleft", title: L.Add.note) { model.composingNote = true },
            Option(id: "voice", symbol: "mic", title: L.Voice.speakNote) { model.voiceNoteShown = true },
            Option(id: "paste", symbol: "doc.on.clipboard", title: L.Add.paste) { model.ingestor.pasteFromClipboard() },
        ]
    }

    private var linkOption: Option {
        guard let url = clipboardLink, let host = url.host() else {
            return Option(id: "link", symbol: "link", title: L.Add.link) { model.linkEntryShown = true }
        }
        let name = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return Option(id: "link", symbol: "link", title: L.Add.saveHost(name)) {
            if let current = Self.readClipboardLink() {
                model.ingestor.ingest(link: current, source: "add")
            } else {
                model.linkEntryShown = true
            }
        }
    }

    private static func readClipboardLink() -> URL? {
        NSPasteboard.general.string(forType: .string).flatMap(Ingestor.webURL(in:))
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .movie, .video, .gif]
        guard panel.runModal() == .OK else { return }
        model.ingestor.ingest(fileURLs: panel.urls)
    }
}

private struct AddMenuRow: View {
    let option: AddMenu.Option
    let bubble: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(option.title)
                    .font(Theme.ui(TextSize.small, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(height: Control.small)
                    .background(Capsule().fill(hovering ? Theme.softHover : .white))
                    .overlay(Capsule().strokeBorder(Theme.hairline))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                Icon(option.symbol, size: IconSize.md)
                    .foregroundStyle(.white)
                    .frame(width: bubble, height: bubble)
                    .background(Circle().fill(Theme.ink))
                    .scaleEffect(hovering ? 1.06 : 1)
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .accessibilityLabel(option.title)
    }
}
