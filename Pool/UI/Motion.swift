import SwiftUI

struct GenieRequest: Identifiable, Equatable {
    let id = UUID()
    let save: Save
    let frame: CGRect
}

struct GenieEffect: ViewModifier, Animatable {
    var rect: CGRect
    var target: CGPoint
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.distortionEffect(
            ShaderLibrary.genie(
                .float4(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height)),
                .float2(Float(target.x), Float(target.y)),
                .float(Float(progress))
            ),
            maxSampleOffset: .zero
        )
    }
}

struct GenieOverlay: View {
    let request: GenieRequest
    let onFinish: () -> Void
    @State private var progress = 0.0

    var body: some View {
        GeometryReader { proxy in
            let target = CGPoint(x: proxy.size.width / 2, y: proxy.size.height - ToastHost.bottomInset - 20)
            ZStack(alignment: .topLeading) {
                Color.clear
                TileFace(save: request.save, hovering: false)
                    .frame(width: request.frame.width, height: request.frame.height)
                    .offset(x: request.frame.minX, y: request.frame.minY)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .drawingGroup()
            .modifier(GenieEffect(rect: request.frame, target: target, progress: progress))
            .opacity(progress > 0.96 ? 0 : 1)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.timingCurve(0.6, 0.02, 0.32, 1, duration: 0.62)) {
                progress = 1
            } completion: {
                onFinish()
            }
        }
    }
}

struct GooeyTabs<Value: Hashable>: View {
    let items: [(title: String, value: Value)]
    @Binding var selection: Value
    var counts: [Value: Int] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let selected = items.firstIndex { $0.value == selection }
        HStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    selection = item.value
                } label: {
                    HStack(spacing: 5) {
                        Text(item.title)
                            .font(Theme.ui(TextSize.body, weight: .medium))
                            .foregroundStyle(selection == item.value ? Theme.ink : Theme.tabIdle)
                        if let count = counts[item.value], count > 0 {
                            Text(count.formatted())
                                .font(Theme.ui(TextSize.caption, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: Control.regular - 6)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item.value ? .isSelected : [])
                .anchorPreference(key: TabBounds.self, value: .bounds) { [index: $0] }
            }
        }
        .backgroundPreferenceValue(TabBounds.self) { anchors in
            GeometryReader { proxy in
                let rect = selected.flatMap { anchors[$0] }.map { proxy[$0] } ?? .zero
                LiquidLayer(blur: 4.5, fill: Theme.tabPill, shadow: false) {
                    ZStack(alignment: .topLeading) {
                        Capsule()
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                            .animation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.18), value: selected)
                        Capsule()
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                            .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.14), value: selected)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
                .shadow(color: .black.opacity(Theme.tabPillShadow), radius: 3, y: 1)
                .opacity(rect == .zero ? 0 : 1)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.softFill))
    }
}

private struct TabBounds: PreferenceKey {
    static let defaultValue: [Int: Anchor<CGRect>] = [:]

    static func reduce(value: inout [Int: Anchor<CGRect>], nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
