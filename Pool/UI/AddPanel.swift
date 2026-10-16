import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AddPanel: View {
    @Environment(AppModel.self) private var model
    var compact = false
    var onDone: () -> Void = {}

    @State private var link = ""
    @FocusState private var linkFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !compact {
                Text(L.Add.title)
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.ink)
            }
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                TextField(L.Add.linkPlaceholder, text: $link)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(13))
                    .focused($linkFocused)
                    .onSubmit(saveLink)
                if Ingestor.webURL(in: link.trimmingCharacters(in: .whitespaces)) != nil {
                    Button(action: saveLink) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Theme.ink))
                    }
                    .buttonStyle(PressStyle(scale: 0.9))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .frame(height: 40)
            .background(Capsule().fill(Theme.field))
            .lifted(Capsule(), shadow: 0.04)
            .overlay(Capsule().strokeBorder(linkFocused ? Theme.ink.opacity(0.18) : .clear))
            .animation(Theme.settle, value: link.isEmpty)

            HStack(spacing: 8) {
                AddAction(symbol: "photo.on.rectangle", title: L.Add.images, action: chooseImages)
                AddAction(symbol: "text.alignleft", title: L.Add.note) {
                    onDone()
                    model.composingNote = true
                }
                AddAction(symbol: "mic", title: L.Voice.speakNote) {
                    onDone()
                    model.voiceNoteShown = true
                }
                AddAction(symbol: "doc.on.clipboard", title: L.Add.paste) {
                    model.ingestor.pasteFromClipboard()
                    onDone()
                }
            }

            Text(L.Add.hint)
                .font(Theme.ui(12))
                .foregroundStyle(Theme.tertiary)
        }
        .padding(compact ? 0 : 20)
        .frame(width: compact ? 520 : 500)
        .onAppear { linkFocused = !compact }
    }

    private func saveLink() {
        guard let url = Ingestor.webURL(in: link.trimmingCharacters(in: .whitespaces)) else { return }
        model.ingestor.ingest(link: url, source: "manual")
        link = ""
        onDone()
    }

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        onDone()
        guard panel.runModal() == .OK else { return }
        model.ingestor.ingest(fileURLs: panel.urls)
    }
}

private struct AddAction: View {
    let symbol: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.ink)
                Text(title)
                    .font(Theme.ui(12, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.fieldTile(hovering: hovering)))
            .lifted(RoundedRectangle(cornerRadius: 14, style: .continuous), shadow: hovering ? 0.08 : 0.04)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
    }
}
