import SwiftUI

struct ViewButton: View {
    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                model.filterOpen = false
                model.viewOpen.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                HugeIcon(symbol, size: IconSize.xs)
                Text(title)
                    .font(Theme.ui(12, weight: .medium))
                HugeIcon("chevron.down", size: IconSize.xs)
                    .opacity(0.6)
                    .rotationEffect(.degrees(model.viewOpen ? 180 : 0))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(Theme.ink.opacity(hovering ? 0.88 : 1)).shadow(color: .black.opacity(Theme.controlShadow), radius: 6, y: 2))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .fixedSize()
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
                .onTapGesture { withAnimation(.spring(duration: 0.35, bounce: 0)) { model.viewOpen = false } }
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.Viewing.sort).font(Theme.ui(11, weight: .medium)).foregroundStyle(Theme.tertiary)
                        .padding(.bottom, 4)
                    SortRow(title: L.Sort.newest, symbol: "arrow.down", order: .newest)
                    SortRow(title: L.Sort.oldest, symbol: "arrow.up", order: .oldest)
                    SortRow(title: L.Sort.shuffle, symbol: "shuffle", order: .shuffle)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L.Viewing.size).font(Theme.ui(11, weight: .medium)).foregroundStyle(Theme.tertiary)
                        Spacer()
                        Text(L.Viewing.saves(model.results.count))
                            .font(Theme.ui(11.5))
                            .foregroundStyle(Theme.tertiary)
                            .monospacedDigit()
                    }
                    HStack(spacing: 12) {
                        HugeIcon("square.grid.3x3", size: IconSize.sm).foregroundStyle(Theme.tertiary)
                        SoftSlider(value: Bindable(model).columnWidth, range: 150...420)
                        HugeIcon("square.grid.2x2", size: IconSize.sm).foregroundStyle(Theme.tertiary)
                    }
                }
            }
            .padding(18)
            .frame(width: 280)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.1), radius: 30, y: 12)
            .padding(.top, 118)
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
    @State private var hovering = false

    var body: some View {
        let on = model.sort == order
        Button { model.sort = order } label: {
            HStack(spacing: 10) {
                HugeIcon(symbol, size: IconSize.sm).frame(width: 18).foregroundStyle(Theme.secondary)
                Text(title).font(Theme.ui(13.5, weight: on ? .medium : .regular)).foregroundStyle(Theme.ink)
                Spacer()
                if on { HugeIcon("checkmark", size: IconSize.xs).foregroundStyle(Theme.ink) }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? Theme.softFill : (hovering ? Theme.softHover : .clear)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
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
                Capsule().fill(Theme.softFillStrong).frame(height: 4)
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
