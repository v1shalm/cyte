import SwiftUI

enum DateRange: String, CaseIterable, Identifiable {
    case any, today, week, month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: L.Filter.anyTime
        case .today: L.Filter.today
        case .week: L.Filter.thisWeek
        case .month: L.Filter.thisMonth
        }
    }

    var since: Date? {
        let calendar = Calendar.current
        switch self {
        case .any: return nil
        case .today: return calendar.startOfDay(for: .now)
        case .week: return calendar.date(byAdding: .day, value: -7, to: .now)
        case .month: return calendar.date(byAdding: .day, value: -30, to: .now)
        }
    }
}

struct ActiveFilter: Identifiable {
    let id: String
    let title: String
    var swatch: Color?
    let remove: () -> Void
}

extension AppModel {
    var filterCount: Int { activeFilters.count }

    var activeFilters: [ActiveFilter] {
        var list: [ActiveFilter] = []
        if let similar = similarFilter {
            list.append(ActiveFilter(id: "similar", title: L.Similar.chip(similar.title)) { self.similarFilter = nil })
        }
        if activeRange != .any {
            list.append(ActiveFilter(id: "range", title: activeRange.title) { self.activeRange = .any })
        }
        if let color = activeColor, let hex = SearchQuery.colorNames[color] {
            list.append(ActiveFilter(id: "color", title: color.capitalized, swatch: Theme.color(hex: hex)) { self.activeColor = nil })
        }
        if let host = activeHost {
            list.append(ActiveFilter(id: "host", title: host) { self.activeHost = nil })
        }
        for tag in activeTags.sorted() {
            list.append(ActiveFilter(id: "tag-\(tag)", title: tag) { self.toggleTag(tag) })
        }
        return list
    }

    var hostIndex: [(host: String, count: Int)] {
        var counts: [String: Int] = [:]
        for save in store.saves { if let host = save.host { counts[host, default: 0] += 1 } }
        return counts.map { (host: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.host < $1.host }
            .prefix(6).map { $0 }
    }
}

struct FilterBar: View {
    @Environment(AppModel.self) private var model
    @State private var width: CGFloat = 0

    var body: some View {
        let filters = model.activeFilters
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(filters) { filter in
                    ActiveChip(filter: filter)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                if filters.count > 1 {
                    Button {
                        withAnimation(Theme.settle) { model.clearFilters() }
                    } label: {
                        Text(L.Filter.clear)
                            .font(Theme.ui(12.5, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle(scale: 0.96))
                }
            }
            .padding(.horizontal, Theme.sideInset)
            .frame(minWidth: width, alignment: .center)
            .animation(Theme.settle, value: filters.map(\.id))
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width = $0 })
        .frame(height: 38)
    }
}

private struct ActiveChip: View {
    @Environment(AppModel.self) private var model
    let filter: ActiveFilter

    var body: some View {
        Button {
            withAnimation(Theme.settle) { filter.remove() }
        } label: {
            HStack(spacing: 7) {
                if let swatch = filter.swatch {
                    Circle().fill(swatch).frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(.white.opacity(0.5)))
                }
                Text(filter.title)
                    .font(Theme.ui(12.5, weight: .medium))
                Icon("xmark", size: IconSize.xs)
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(Capsule().fill(Theme.ink))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.96))
    }
}

struct FilterOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.spring(duration: 0.35, bounce: 0)) { model.filterOpen = false } }
            ScrollView {
                FilterPanel()
            }
            .scrollIndicators(.never)
            .frame(width: 380)
            .frame(maxHeight: 580)
            .fixedSize(horizontal: false, vertical: true)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.1), radius: 30, y: 12)
            .padding(.top, 118)
            .padding(.trailing, Theme.sideInset)
            .transition(.scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FilterPanel: View {
    @Environment(AppModel.self) private var model

    private let swatches = ["black", "gray", "white", "brown", "red", "orange", "yellow", "green", "teal", "blue", "purple", "pink"]

    var body: some View {
        let index = model.tagIndex
        let hosts = model.hostIndex
        VStack(alignment: .leading, spacing: 20) {
            section(L.Filter.added) {
                HStack(spacing: 8) {
                    ForEach(DateRange.allCases) { range in
                        OptionPill(title: range.title, active: model.activeRange == range) {
                            model.activeRange = model.activeRange == range ? .any : range
                        }
                    }
                }
            }
            section(L.Filter.colour) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(swatches, id: \.self) { name in
                        let selected = model.activeColor == name
                        Button {
                            withAnimation(Theme.hover) { model.activeColor = selected ? nil : name }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.color(hex: SearchQuery.colorNames[name] ?? "#888888"))
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().strokeBorder(Theme.hairline))
                                Text(name.capitalized)
                                    .font(Theme.ui(12, weight: selected ? .medium : .regular))
                                    .foregroundStyle(selected ? Color.white : Theme.ink.opacity(0.78))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 12)
                            .padding(.trailing, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 32)
                            .background(Capsule().fill(selected ? Theme.ink : Theme.softHover))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(PressStyle(scale: 0.96))
                    }
                }
            }
            if !hosts.isEmpty {
                section(L.Filter.sites) {
                    VStack(spacing: 2) {
                        ForEach(hosts, id: \.host) { item in
                            let selected = model.activeHost == item.host
                            Button {
                                model.activeHost = selected ? nil : item.host
                            } label: {
                                HStack {
                                    Text(item.host)
                                        .font(Theme.ui(13, weight: selected ? .medium : .regular))
                                        .foregroundStyle(Theme.ink)
                                    Spacer()
                                    if selected {
                                        Icon("checkmark", size: IconSize.xs)
                                    } else {
                                        Text("\(item.count)").font(Theme.ui(12)).foregroundStyle(Theme.tertiary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Theme.softFillStrong : .clear))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressStyle(scale: 0.98))
                        }
                    }
                    .padding(.horizontal, -12)
                }
            }
            if !index.mine.isEmpty {
                section(L.Filter.yourTags) {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(index.mine.prefix(18), id: \.tag) { item in
                            OptionPill(title: item.tag, active: model.activeTags.contains(item.tag)) { model.toggleTag(item.tag) }
                        }
                    }
                }
            }
            if !index.found.isEmpty {
                section(L.Filter.autoTags) {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(index.found.prefix(14), id: \.tag) { item in
                            OptionPill(title: item.tag, active: model.activeTags.contains(item.tag)) { model.toggleTag(item.tag) }
                        }
                    }
                }
            }
            if model.filterCount > 0 || model.kind != nil {
                Button {
                    withAnimation(Theme.settle) { model.saveSmartFolder() }
                } label: {
                    HStack(spacing: 6) {
                        Icon("sparkles", size: IconSize.sm)
                        Text(L.Similar.save)
                    }
                }
                .poolSecondary()
            }
        }
        .padding(20)
        .frame(width: 380)
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

private struct OptionPill: View {
    let title: String
    let active: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(12.5, weight: .medium))
                .foregroundStyle(active ? Color.white : Theme.ink.opacity(0.78))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(active ? Theme.ink : (hovering ? Theme.softTarget : Theme.softHover)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .animation(Theme.hover, value: active)
    }
}
