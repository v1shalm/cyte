import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct Rail: View {
    @Environment(AppModel.self) private var model
    @State private var dragOver = false

    var body: some View {
        VStack(spacing: 0) {
            Button { goHome() } label: {
                Image("MenuBarMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Theme.sideInk)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(scale: 0.92))
            .help(L.Folders.everything)
            .accessibilityLabel(L.Folders.everything)
            .padding(.top, Chrome.titleRowCenter - 22)

            VStack(spacing: 6) {
                RailButton(symbol: "square.grid.2x2.fill", title: L.Folders.everything, active: model.folderID == nil && !model.bookmarksOnly && !model.foldersPage) {
                    withAnimation(Theme.settle) { goHome() }
                }
                RailButton(symbol: "bookmark.fill", title: L.X.source, active: model.bookmarksOnly) {
                    withAnimation(Theme.settle) {
                        if model.xImport.connected || model.xImport.importedCount > 0 { model.bookmarksOnly.toggle() } else { model.xImport.open() }
                    }
                }
                RailButton(symbol: "folder.fill", title: L.Folders.allFolders, active: model.foldersPage || model.folderID != nil) {
                    withAnimation(Theme.settle) { model.foldersPage = true }
                }
                .onDrop(of: [UTType(exportedAs: AppModel.saveType), .fileURL, .url], isTargeted: $dragOver) { _ in false }
                .onChange(of: dragOver) { _, over in if over { withAnimation(Theme.settle) { model.foldersPage = true } } }
                .onChange(of: model.editingFolderID) { _, id in if id != nil, model.folderID == nil { model.foldersPage = true } }
            }
            .padding(.top, 20)

            Spacer(minLength: 0)

            SettingsLink {
                RailIcon(symbol: "gearshape.fill", active: false)
            }
            .buttonStyle(PressStyle(scale: 0.92))
            .help(L.Settings.title)
            .accessibilityLabel(L.Settings.title)
            .padding(.bottom, 16)

        }
        .frame(maxHeight: .infinity)
    }

    private func goHome() { model.goHome() }
}

private struct RailIcon: View {
    let symbol: String
    var activeSymbol: String?
    let active: Bool
    @State private var hovering = false

    var body: some View {
        Icon(symbol, size: IconSize.lg, fill: 1)
            .foregroundStyle(active || hovering ? Theme.sideInk : Theme.tertiary)
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: Radius.row, style: .continuous).fill(active ? Theme.softFill : (hovering ? Theme.softHover : .clear)))
            .contentShape(RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            .onHover { hovering = $0 }
            .animation(Theme.hover, value: hovering)
            .animation(Theme.hover, value: active)
    }
}

private struct RailButton: View {
    let symbol: String
    var activeSymbol: String?
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RailIcon(symbol: symbol, activeSymbol: activeSymbol, active: active)
        }
        .buttonStyle(PressStyle(scale: 0.92))
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
