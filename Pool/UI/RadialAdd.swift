import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RadialAdd: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Option: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let run: () -> Void
    }

    @State private var clipboardLink: URL?
    @State private var hovered: String?

    private let trigger: CGFloat = 60
    private let bubble: CGFloat = 62
    private let radius: CGFloat = 132
    private let bottomInset: CGFloat = 28
    private let pillWidth: CGFloat = 118
    private let pillHeight: CGFloat = 52

    private var open: Bool { model.addMenuOpen }

    var body: some View {
        let options = makeOptions()
        let width: CGFloat = 400
        let height = radius + bubble + trigger + bottomInset + 40

        ZStack(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Theme.ink)
                    .frame(width: open ? trigger : pillWidth, height: open ? trigger : pillHeight)
                    .animation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.25), value: open)
                    .padding(.bottom, bottomInset)
                ForEach(Array(options.enumerated()), id: \.element.id) { index, _ in
                    let cell = Cell(
                        progress: open ? 1 : 0,
                        degrees: angle(index, count: options.count),
                        distance: radius,
                        triggerRadius: trigger / 2,
                        bubbleRadius: bubble / 2,
                        inset: bottomInset
                    )
                    cell.neck.fill(Theme.ink).animation(blob(index), value: open)
                    cell.body.fill(Theme.ink).animation(blob(index), value: open)
                }
            }
            .frame(width: width, height: height, alignment: .bottom)
            .compositingGroup()
            .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
            .allowsHitTesting(false)

            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                optionButton(option)
                    .scaleEffect(open ? 1 : 0.2)
                    .opacity(open ? 1 : 0)
                    .animation(open ? .spring(duration: 0.6, bounce: 0.3).delay(0.3 + Double(abs(index - 2)) * 0.08) : .easeIn(duration: 0.26).delay(0.28), value: open)
                    .offset(place(index, count: options.count))
                    .animation(blob(index), value: open)
                    .allowsHitTesting(open)
                    .padding(.bottom, bottomInset)
            }

            Text(hovered.flatMap { id in options.first { $0.id == id }?.title } ?? "")
                .font(Theme.ui(12.5, weight: .medium))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(.white))
                .overlay(Capsule().strokeBorder(Theme.hairline))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                .opacity(hovered == nil ? 0 : 1)
                .offset(y: -(bottomInset + trigger + radius + bubble / 2 + 14))
                .animation(.easeOut(duration: 0.12), value: hovered)
                .allowsHitTesting(false)

            Button {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) { model.addMenuOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    HugeIcon("plus", size: open ? IconSize.xl : IconSize.md)
                        .rotationEffect(.degrees(open ? 45 : 0))
                    if !open {
                        Text(L.Add.button)
                            .font(Theme.ui(16, weight: .medium))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: open ? trigger : pillWidth, height: open ? trigger : pillHeight)
                .contentShape(Capsule())
                .animation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.25), value: open)
            }
            .buttonStyle(PressStyle(scale: 0.96))
            .accessibilityLabel(L.Add.button)
            .padding(.bottom, bottomInset)
        }
        .frame(width: width, height: height, alignment: .bottom)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onExitCommand { withAnimation(.spring(duration: 0.7, bounce: 0)) { model.addMenuOpen = false } }
        .onChange(of: open) { _, isOpen in
            hovered = nil
            if isOpen { clipboardLink = NSPasteboard.general.string(forType: .string).flatMap(Ingestor.webURL(in:)) }
        }
        .onAppear { clipboardLink = NSPasteboard.general.string(forType: .string).flatMap(Ingestor.webURL(in:)) }
    }

    private func optionButton(_ option: Option) -> some View {
        Button {
            withAnimation(.spring(duration: 0.7, bounce: 0)) { model.addMenuOpen = false }
            option.run()
        } label: {
            HugeIcon(option.symbol, size: IconSize.xl)
                .foregroundStyle(.white)
                .frame(width: bubble, height: bubble)
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .onHover { inside in
            if inside { hovered = option.id } else if hovered == option.id { hovered = nil }
        }
        .accessibilityLabel(option.title)
    }

    private func blob(_ index: Int) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.15) }
        let spread = Double(abs(index - 2))
        return open ? .spring(duration: 1.05, bounce: 0.42).delay(0.12 + spread * 0.08) : .spring(duration: 0.62, bounce: 0).delay((2 - spread) * 0.03)
    }

    private func place(_ index: Int, count: Int) -> CGSize {
        if open {
            let spot = target(index, count: count)
            return CGSize(width: spot.width, height: spot.height + (bubble - trigger) / 2)
        }
        return CGSize(width: 0, height: (bubble - pillHeight) / 2)
    }

    private func angle(_ index: Int, count: Int) -> Double {
        180 + (Double(index) + 0.5) * 180 / Double(count)
    }

    private func target(_ index: Int, count: Int) -> CGSize {
        let radians = angle(index, count: count) * .pi / 180
        return CGSize(width: cos(radians) * radius, height: sin(radians) * radius)
    }

    private func makeOptions() -> [Option] {
        [
            linkOption,
            Option(id: "images", symbol: "photo.on.rectangle", title: L.Add.images) { chooseImages() },
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
            if let current = NSPasteboard.general.string(forType: .string).flatMap(Ingestor.webURL(in:)) {
                model.ingestor.ingest(link: current, source: "add")
            } else {
                model.linkEntryShown = true
            }
        }
    }

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK else { return }
        model.ingestor.ingest(fileURLs: panel.urls)
    }
}

nonisolated struct Droplet: Shape {
    var reach: CGFloat = 1.55

    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let d = r * reach
        let a = acos(r / d)
        let tip = CGPoint(x: c.x + d, y: c.y)
        let start = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        var path = Path()
        path.move(to: start)
        path.addArc(center: c, radius: r, startAngle: .radians(a), endAngle: .radians(-a), clockwise: false)
        path.addQuadCurve(to: start, control: tip)
        path.closeSubpath()
        return path
    }
}

nonisolated struct Cell {
    var progress: CGFloat
    var degrees: Double
    var distance: CGFloat
    var triggerRadius: CGFloat
    var bubbleRadius: CGFloat
    var inset: CGFloat

    var neck: CellNeck { CellNeck(cell: self) }
    var body: CellBody { CellBody(cell: self) }

    func trigger(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.maxY - inset - triggerRadius)
    }

    func center(in rect: CGRect) -> CGPoint {
        let origin = trigger(in: rect)
        let radians = degrees * .pi / 180
        let travel = max(0, progress)
        return CGPoint(x: origin.x + cos(radians) * distance * travel, y: origin.y + sin(radians) * distance * travel)
    }

    var radius: CGFloat { bubbleRadius * min(pow(max(progress, 0), 0.6), 1.1) }
}

nonisolated struct CellBody: Shape {
    var cell: Cell

    var animatableData: CGFloat {
        get { cell.progress }
        set { cell.progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = cell.center(in: rect)
        let r = max(0.01, cell.radius)
        let drop = Droplet(reach: 1.55).path(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        let turn = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: cell.degrees * .pi / 180)
        return drop.applying(turn)
    }
}

nonisolated struct CellNeck: Shape {
    var cell: Cell

    var animatableData: CGFloat {
        get { cell.progress }
        set { cell.progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let t = cell.trigger(in: rect)
        let c = cell.center(in: rect)
        let r1 = cell.triggerRadius
        let r2 = max(0, cell.radius)
        let d = hypot(c.x - t.x, c.y - t.y)
        let gap = d - r1 - r2
        let snap: CGFloat = 54
        guard r2 > 1, d > abs(r1 - r2) + 0.5, gap < snap else { return Path() }
        let tension = pow(1 - max(gap, 0) / snap, 1.5)
        let v = 0.05 + 0.42 * tension
        return Self.bridge(t, r1, c, r2, v: v)
    }

    static func bridge(_ c1: CGPoint, _ r1: CGFloat, _ c2: CGPoint, _ r2: CGFloat, v: CGFloat) -> Path {
        let d = hypot(c2.x - c1.x, c2.y - c1.y)
        var u1: CGFloat = 0
        var u2: CGFloat = 0
        if d < r1 + r2 {
            u1 = acos(max(-1, min(1, (r1 * r1 + d * d - r2 * r2) / (2 * r1 * d))))
            u2 = acos(max(-1, min(1, (r2 * r2 + d * d - r1 * r1) / (2 * r2 * d))))
        }
        let a = atan2(c2.y - c1.y, c2.x - c1.x)
        let s = (.pi - u1 - u2) * v
        let a1a = a + u1 + s
        let a1b = a - u1 - s
        let a2a = a + .pi - u2 - s
        let a2b = a - .pi + u2 + s
        func vec(_ p: CGPoint, _ angle: CGFloat, _ length: CGFloat) -> CGPoint {
            CGPoint(x: p.x + cos(angle) * length, y: p.y + sin(angle) * length)
        }
        let p1 = vec(c1, a1a, r1)
        let p4 = vec(c1, a1b, r1)
        let p2 = vec(c2, a2a, r2)
        let p3 = vec(c2, a2b, r2)
        let d2 = min(v * 2.4, d / (r1 + r2)) * min(1, d * 2 / (r1 + r2))
        let h1 = vec(p1, a1a - .pi / 2, r1 * d2)
        let h2 = vec(p2, a2a + .pi / 2, r2 * d2)
        let h3 = vec(p3, a2b - .pi / 2, r2 * d2)
        let h4 = vec(p4, a1b + .pi / 2, r1 * d2)
        var path = Path()
        path.move(to: p1)
        path.addCurve(to: p2, control1: h1, control2: h2)
        path.addLine(to: p3)
        path.addCurve(to: p4, control1: h3, control2: h4)
        path.closeSubpath()
        return path
    }
}
