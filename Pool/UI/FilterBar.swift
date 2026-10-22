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
        if let color = activeColor {
            let named = SearchQuery.colorNames[color]
            list.append(ActiveFilter(id: "color", title: named == nil ? color.uppercased() : color.capitalized,
                                     swatch: Theme.color(hex: named ?? color)) { self.activeColor = nil })
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

    var body: some View {
        let filters = model.activeFilters
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(filters) { filter in
                    ActiveChip(filter: filter)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                if filters.count > 1 {
                    Button(L.Filter.clear) {
                        withAnimation(Theme.settle) { model.clearFilters() }
                    }
                    .buttonStyle(.plain)
                    .font(Theme.ui(TextSize.small, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: Control.small)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, Theme.sideInset)
            .animation(Theme.settle, value: filters.map(\.id))
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: Control.small)
    }
}

private struct ActiveChip: View {
    let filter: ActiveFilter

    var body: some View {
        Button {
            withAnimation(Theme.settle) { filter.remove() }
        } label: {
            HStack(spacing: 6) {
                if let swatch = filter.swatch {
                    Circle().fill(swatch).frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(.white.opacity(0.5)))
                }
                Text(filter.title)
                Icon("xmark", size: IconSize.xs)
                    .opacity(0.7)
            }
        }
        .buttonStyle(ChipStyle(active: true))
        .accessibilityLabel(filter.title)
        .accessibilityHint(L.Filter.remove)
    }
}

struct FilterOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(Theme.exit) { model.filterOpen = false } }
            ScrollView {
                FilterPanel()
            }
            .scrollIndicators(.automatic)
            .frame(width: 360)
            .frame(maxHeight: 560)
            .fixedSize(horizontal: false, vertical: true)
            .floatingPanel()
            .padding(.top, Chrome.panelTop)
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
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(DateRange.allCases) { range in
                        let on = model.activeRange == range
                        Button(range.title) {
                            model.activeRange = on ? .any : range
                        }
                        .buttonStyle(ChipStyle(active: on))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            section(L.Filter.colour) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(swatches, id: \.self) { name in
                        let selected = model.activeColor == name
                        Button {
                            withAnimation(Theme.hover) { model.activeColor = selected ? nil : name }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.color(hex: SearchQuery.colorNames[name] ?? "#888888"))
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().strokeBorder(selected ? Color.white.opacity(0.6) : Theme.hairline))
                                Text(name.capitalized)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(ChipStyle(active: selected))
                        .accessibilityAddTraits(selected ? .isSelected : [])
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
                                        .lineLimit(1)
                                    Spacer()
                                    if selected {
                                        Icon("checkmark", size: IconSize.sm)
                                    } else {
                                        Text("\(item.count)")
                                            .font(Theme.ui(TextSize.small))
                                            .foregroundStyle(Theme.tertiary)
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .buttonStyle(RowStyle(selected: selected))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, -10)
                }
            }
            if !index.mine.isEmpty {
                section(L.Filter.yourTags) {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(index.mine.prefix(18), id: \.tag) { item in
                            tagChip(item.tag)
                        }
                    }
                }
            }
            if !index.found.isEmpty {
                section(L.Filter.autoTags) {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(index.found.prefix(14), id: \.tag) { item in
                            tagChip(item.tag)
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
        .frame(width: 360)
    }

    private func tagChip(_ tag: String) -> some View {
        let on = model.activeTags.contains(tag)
        return Button(tag) { model.toggleTag(tag) }
            .buttonStyle(ChipStyle(active: on))
            .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            content()
        }
    }
}
