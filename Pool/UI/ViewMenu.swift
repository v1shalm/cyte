import SwiftUI

struct ViewControls: View {
    var body: some View {
        HStack(spacing: 2) {
            FilterButton(segment: .first)
            ViewButton(segment: .last)
        }
        .fixedSize()
    }
}

struct FilterButton: View {
    @Environment(AppModel.self) private var model
    var segment: Segment = .alone

    var body: some View {
        let count = model.filterCount
        Button {
            withAnimation(Theme.enter) {
                model.viewOpen = false
                model.filterOpen.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Icon("line.3.horizontal.decrease", size: IconSize.sm)
                Text(L.Filter.title)
                if count > 0 {
                    Text("\(count)")
                        .font(Theme.ui(TextSize.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(Theme.ink))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
        .poolSecondary(segment, active: model.filterOpen)
        .animation(Theme.settle, value: count)
        .accessibilityValue(count > 0 ? "\(count)" : "")
    }
}

struct ViewButton: View {
    @Environment(AppModel.self) private var model
    var segment: Segment = .alone

    var body: some View {
        Button {
            withAnimation(Theme.enter) {
                model.filterOpen = false
                model.viewOpen.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Icon(symbol, size: IconSize.sm)
                Text(title)
                Icon("chevron.down", size: IconSize.xs)
                    .foregroundStyle(Theme.secondary)
                    .rotationEffect(.degrees(model.viewOpen ? 180 : 0))
            }
        }
        .poolSecondary(segment, active: model.viewOpen)
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

struct ViewOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(Theme.exit) { model.viewOpen = false } }
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(L.Viewing.sort)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                    SortRow(title: L.Sort.newest, symbol: "arrow.down", order: .newest)
                    SortRow(title: L.Sort.oldest, symbol: "arrow.up", order: .oldest)
                    SortRow(title: L.Sort.shuffle, symbol: "shuffle", order: .shuffle)
                }
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.horizontal, 10)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionLabel(L.Viewing.size)
                        Spacer()
                        Text(L.Viewing.saves(model.results.count))
                            .font(Theme.ui(TextSize.caption))
                            .foregroundStyle(Theme.tertiary)
                            .monospacedDigit()
                    }
                    HStack(spacing: 12) {
                        Icon("square.grid.3x3", size: IconSize.sm).foregroundStyle(Theme.secondary)
                        SoftSlider(value: Bindable(model).columnWidth, range: 150...420)
                            .accessibilityLabel(L.Viewing.size)
                        Icon("square.grid.2x2", size: IconSize.sm).foregroundStyle(Theme.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .padding(8)
            .frame(width: 264)
            .floatingPanel()
            .padding(.top, Chrome.panelTop)
            .padding(.trailing, Theme.sideInset)
            .transition(.scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SortRow: View {
    @Environment(AppModel.self) private var model
    let title: String
    let symbol: String
    let order: SortOrder

    var body: some View {
        let on = model.sort == order
        Button { model.sort = order } label: {
            HStack(spacing: 10) {
                Icon(symbol, size: IconSize.sm).frame(width: 18).foregroundStyle(Theme.secondary)
                Text(title)
                Spacer()
                if on { Icon("checkmark", size: IconSize.sm) }
            }
        }
        .buttonStyle(RowStyle(selected: on))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct SoftSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var dragging = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.softTarget).frame(height: 4)
                Capsule().fill(Theme.ink).frame(width: max(4, width * fraction), height: 4)
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().strokeBorder(Theme.hairline))
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 1)
                    .scaleEffect(dragging ? 1.12 : 1)
                    .offset(x: (width - 20) * fraction)
                    .animation(Theme.press, value: dragging)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        dragging = true
                        let t = min(1, max(0, (drag.location.x - 10) / max(1, width - 20)))
                        value = range.lowerBound + t * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in dragging = false }
            )
        }
        .frame(height: 24)
        .accessibilityValue("\(Int(value))")
    }
}
