import SwiftUI

struct EmptyArt: View {
    let symbol: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.softFillStrong)
                .frame(width: 74, height: 96)
                .rotationEffect(.degrees(-10))
                .offset(x: -40, y: 6)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.softFill)
                .frame(width: 74, height: 96)
                .rotationEffect(.degrees(10))
                .offset(x: 40, y: 6)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .frame(width: 84, height: 108)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
                .overlay(
                    Icon(symbol, size: IconSize.xl)
                        .foregroundStyle(Theme.tertiary)
                )
                .shadow(color: .black.opacity(0.04), radius: 1.5, y: 1)
                .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
        }
        .frame(height: 124)
        .accessibilityHidden(true)
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var primary: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            EmptyArt(symbol: symbol)
                .padding(.bottom, 26)
            Text(title)
                .font(Theme.serif(26))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Theme.ui(13.5))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 340)
                .padding(.top, 10)
            if let primary {
                Button(primary, action: action)
                    .poolPrimary()
                    .padding(.top, 22)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyFolder: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let smart = model.folderID.flatMap { model.store.folder(id: $0)?.rule } != nil
        EmptyState(symbol: smart ? "sparkles" : "folder", title: L.EmptyState.folderTitle,
                   message: smart ? L.EmptyState.smartBody : L.EmptyState.folderBody, primary: L.EmptyState.browse) {
            withAnimation(Theme.settle) { model.goHome() }
        }
    }
}

struct EmptyFilters: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        EmptyState(symbol: "line.3.horizontal.decrease", title: L.EmptyState.filterTitle,
                   message: L.EmptyState.filterBody, primary: L.Filter.clear) {
            withAnimation(Theme.settle) { model.clearFilters() }
        }
    }
}

struct EmptyBookmarks: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        EmptyState(symbol: "bookmark", title: L.EmptyState.bookmarksTitle, message: L.EmptyState.bookmarksBody,
                   primary: L.X.importAction) { model.xImport.open() }
    }
}

struct EmptySearch: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        EmptyState(symbol: "magnifyingglass", title: L.Search.emptyTitle(model.query.isEmpty ? (model.kind?.rawValue ?? "") : model.query),
                   message: L.Search.emptyBody, primary: L.Search.emptyPrimary) {
            model.query = ""
            model.kind = nil
        }
    }
}
