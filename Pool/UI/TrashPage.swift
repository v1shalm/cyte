import AppKit
import SwiftUI

enum TrashConfirm: Hashable {
    case one(String)
    case all

    func items(in trash: [LibraryStore.TrashItem]) -> [LibraryStore.TrashItem] {
        switch self {
        case .one(let id): trash.filter { $0.id == id }
        case .all: trash
        }
    }
}

struct TrashPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let items = model.store.trash
        ZStack(alignment: .bottom) {
            if !model.store.trashLoaded {
                Color.clear
            } else if items.isEmpty {
                EmptyState(symbol: "trash", title: L.Trash.emptyTitle, message: L.Trash.emptyBody, primary: L.EmptyState.browse) {
                    withAnimation(Theme.settle) { model.goHome() }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: Theme.gap)], spacing: Theme.gap) {
                        ForEach(items) { item in
                            TrashCard(item: item)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    .padding(.horizontal, Theme.sideInset)
                    .padding(.top, Theme.topInset)
                    .padding(.bottom, 140)
                    .animation(reduceMotion ? nil : Theme.reflow, value: items.map(\.id))
                }
                .scrollIndicators(.automatic)
            }

            if let confirm = model.trashConfirm {
                let count = confirm.items(in: items).count
                QuestionPill(
                    message: confirmMessage(confirm, count: count),
                    soft: L.Trash.confirmYes(count),
                    solid: L.Trash.keep,
                    onSoft: { model.confirmErase() }
                ) {
                    withAnimation(Theme.settle) { model.trashConfirm = nil }
                }
                .padding(.bottom, ToastHost.bottomInset)
                .transition(.opacity)
                .id(confirm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.settle, value: model.trashConfirm)
    }

    private func confirmMessage(_ confirm: TrashConfirm, count: Int) -> String {
        switch confirm {
        case .one(let id): L.Trash.confirmOne(model.store.trash.first { $0.id == id }?.save.displayTitle ?? "")
        case .all: L.Trash.confirmAll(count)
        }
    }
}

private struct EraseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon("trash", size: IconSize.xs)
                .foregroundStyle(Theme.ink)
                .frame(width: Control.small, height: Control.small)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().strokeBorder(Theme.hairline))
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .help(L.Trash.deleteNow)
        .accessibilityLabel(L.Trash.deleteNow)
    }
}

private struct TrashCard: View {
    @Environment(AppModel.self) private var model
    let item: LibraryStore.TrashItem
    @State private var hovering = false

    private var save: Save { item.save }
    private var daysLeft: Int { item.daysLeft() }
    private var soon: Bool { daysLeft <= 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline))
                .overlay(alignment: .topTrailing) {
                    if hovering {
                        EraseButton { model.trashConfirm = .one(item.id) }
                            .padding(8)
                            .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                    }
                }
                .padding(8)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(save.displayTitle)
                        .font(Theme.ui(TextSize.large, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .help(save.displayTitle)
                    Text(L.Trash.daysLeft(daysLeft))
                        .font(Theme.ui(TextSize.small, weight: soon ? .medium : .regular))
                        .foregroundStyle(soon ? Theme.ink : Theme.tertiary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                Button(L.Trash.restore) { model.restore(item) }
                    .buttonStyle(ChipStyle())
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardShadow(radius: Theme.tileRadius + 4, hovering: hovering)
        .overlay(RoundedRectangle(cornerRadius: Theme.tileRadius + 4, style: .continuous).strokeBorder(Theme.hairline))
        .contentShape(RoundedRectangle(cornerRadius: Theme.tileRadius + 4, style: .continuous))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .contextMenu {
            Button(L.Trash.restore) { model.restore(item) }
            Divider()
            Button(L.Trash.deleteNow, role: .destructive) { model.trashConfirm = .one(item.id) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(save.displayTitle), \(L.Trash.daysLeft(daysLeft))")
        .accessibilityAction(named: L.Trash.deleteNow) { model.trashConfirm = .one(item.id) }
    }

    @ViewBuilder private var preview: some View {
        if let thumb = item.file(save.thumbnail) {
            Thumb(url: thumb, maxPixel: 600, tint: save.tint)
                .clipped()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let host = save.host {
                    Text(host)
                        .font(Theme.ui(TextSize.caption))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                }
                if save.kind == .note {
                    Text(save.text ?? "")
                        .font(Theme.ui(TextSize.body))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                        .lineLimit(7)
                } else {
                    Text(save.displayTitle)
                        .font(Theme.serif(LinkTile.titleSize))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(1)
                        .lineLimit(4)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.softHover)
        }
    }
}
