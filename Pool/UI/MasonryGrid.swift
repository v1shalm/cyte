import SwiftUI


struct MasonryLayout {
    var frames: [String: CGRect] = [:]
    var order: [String] = []
    var height: CGFloat = 0
    var columnWidth: CGFloat = 0
    var relatedHeader: CGFloat?

    static func make(saves: [Save], related: [Save], width: CGFloat, target: CGFloat, leading: CGFloat = 0, top: CGFloat = Theme.topInset) -> MasonryLayout {
        var layout = MasonryLayout()
        let usable = max(0, width - leading - Theme.sideInset * 2)
        guard usable > 0 else { return layout }
        let columns = max(2, Int((usable + Theme.gap) / (target + Theme.gap)))
        let columnWidth = floor((usable - Theme.gap * CGFloat(columns - 1)) / CGFloat(columns))
        layout.columnWidth = columnWidth

        var heights = [CGFloat](repeating: top, count: columns)
        func place(_ list: [Save]) {
            for save in list {
                let column = heights.indices.min { heights[$0] < heights[$1] } ?? 0
                let height = tileHeight(save, width: columnWidth)
                let x = leading + Theme.sideInset + CGFloat(column) * (columnWidth + Theme.gap)
                layout.frames[save.id] = CGRect(x: x, y: heights[column], width: columnWidth, height: height)
                layout.order.append(save.id)
                heights[column] += height + Theme.gap
            }
        }

        place(saves)
        if !related.isEmpty {
            let belowMain = (heights.max() ?? top) + (saves.isEmpty ? 0 : 24)
            layout.relatedHeader = belowMain
            heights = [CGFloat](repeating: belowMain + 44, count: columns)
            place(related)
        }
        layout.height = (heights.max() ?? 0) + 80
        return layout
    }

    static func tileHeight(_ save: Save, width: CGFloat) -> CGFloat {
        switch save.kind {
        case .image:
            let aspect = save.aspect > 0 ? save.aspect : 1
            return min(width * 2.4, max(width * 0.42, width / aspect)).rounded()
        case .link:
            if save.thumbnail != nil, save.aspect > 0 {
                let aspect = min(2.1, max(1.3, save.aspect))
                return (width / aspect).rounded() + LinkTile.footerHeight
            }
            if save.pending { return 120 }
            let perLine = max(10, (width - 32) / (LinkTile.titleSize * 0.5))
            let lines = min(CGFloat(LinkTile.titleLines), max(1, ceil(CGFloat(save.displayTitle.count) / perLine)))
            var height = 30 + 12 + 10 + lines * 24 + 6
            if !save.note.isEmpty {
                let whyPerLine = max(12, (width - 32) / (TextSize.large * 0.5))
                let whyLines = min(CGFloat(LinkTile.whyLines), max(1, ceil(CGFloat(save.note.count) / whyPerLine)))
                height += 10 + whyLines * 20
            }
            return height.rounded()
        case .note:
            let text = save.text ?? ""
            let perLine = max(12, width / 7.6)
            let wrapped = text.split(separator: "\n", omittingEmptySubsequences: false)
                .reduce(0) { $0 + max(1, Int(ceil(Double($1.count) / perLine))) }
            let lines = min(14, max(2, wrapped))
            return CGFloat(lines) * 19.5 + 34
        }
    }
}

final class ScrollProbe {
    var minY: CGFloat = 0
    private var key = 0
    private(set) var layout = MasonryLayout()
    var viewport: CGFloat = 0
    private var lookup: [String: Save] = [:]

    func resolve(saves: [Save], related: [Save], width: CGFloat, target: CGFloat, leading: CGFloat, top: CGFloat) -> (MasonryLayout, [String: Save]) {
        var hasher = Hasher()
        hasher.combine(width)
        hasher.combine(target)
        hasher.combine(leading)
        hasher.combine(top)
        for save in saves { Self.combine(save, into: &hasher) }
        hasher.combine(-1)
        for save in related { Self.combine(save, into: &hasher) }
        let next = hasher.finalize()
        if next != key {
            key = next
            layout = MasonryLayout.make(saves: saves, related: related, width: width, target: target, leading: leading, top: top)
            lookup = Dictionary(saves.map { ($0.id, $0) } + related.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } else {
            for save in saves + related where lookup[save.id] != save { lookup[save.id] = save }
        }
        return (layout, lookup)
    }

    func frames() -> [String: CGRect] {
        let window = CGRect(x: -10_000, y: minY - 200, width: 100_000, height: 3_000)
        var result: [String: CGRect] = [:]
        for (id, frame) in layout.frames where frame.intersects(window) {
            result[id] = frame.offsetBy(dx: 0, dy: -minY)
        }
        return result
    }

    private static func combine(_ save: Save, into hasher: inout Hasher) {
        hasher.combine(save.id)
        hasher.combine(save.aspect)
        hasher.combine(save.pending)
        hasher.combine(save.thumbnail != nil)
        hasher.combine(save.text?.count ?? 0)
        hasher.combine(save.note.count)
    }
}

struct MasonryGrid: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let namespace: Namespace.ID
    static let step: CGFloat = 300

    @State private var width: CGFloat = 0
    @State private var bucket = 0
    @State private var viewport: CGFloat = 0
    @State private var probe = ScrollProbe()
    @State private var position = ScrollPosition(edge: .top)
    @State private var pinchStart: Double?
    @State private var playBand = 0

    static let band: CGFloat = 60
    static let maxPlaying = 10
    static let maxBeams = 3
    static let maxStagger = 6

    private func arrival(_ rank: Int) -> AnyTransition {
        guard !reduceMotion else { return .opacity.animation(Theme.fade) }
        let delay = 0.06 + Double(min(rank, Self.maxStagger)) * 0.04
        return .modifier(active: Arrival(landed: false), identity: Arrival(landed: true))
            .animation(Theme.settle.delay(delay))
    }

    var body: some View {
        let (layout, lookup) = probe.resolve(saves: model.results, related: model.related, width: width, target: model.columnWidth, leading: model.contentLeading, top: model.topInset)
        let _ = { if layout.columnWidth > 0 { model.tileWidth = layout.columnWidth } }()
        let window = CGRect(x: -10_000, y: CGFloat(bucket) * Self.step - 900, width: 100_000, height: max(viewport, 1600) + 1800 + Self.step)
        let visibleIDs = layout.order.filter { layout.frames[$0]?.intersects(window) ?? false }
        let playing = playingIDs(visibleIDs, layout: layout, lookup: lookup)
        let fresh = model.store.freshIDs
        let arrivals = Dictionary(uniqueKeysWithValues: layout.order.filter(fresh.contains).enumerated().map { ($0.element, $0.offset) })

        ScrollView {
            ZStack(alignment: .topLeading) {
                Color.clear.frame(width: max(width, 1), height: max(layout.height, 1))

                if let header = layout.relatedHeader {
                    HStack(spacing: 10) {
                        Text(L.Search.related)
                            .font(Theme.ui(12, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }
                    .frame(width: max(0, width - model.contentLeading - Theme.sideInset * 2))
                    .position(x: model.contentLeading + (width - model.contentLeading) / 2, y: header + 16)
                }

                ForEach(visibleIDs, id: \.self) { id in
                    if let save = lookup[id], let frame = layout.frames[id] {
                        let rank = arrivals[id]
                        Tile(save: save, namespace: namespace, fresh: rank != nil, beams: (rank ?? 0) < Self.maxBeams, playing: playing.contains(id))
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                            .transition(.asymmetric(
                                insertion: rank.map(arrival) ?? (reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity)),
                                removal: .opacity.combined(with: .scale(scale: 0.97))
                            ))
                    }
                }
            }
            .animation(reduceMotion ? nil : Theme.reflow, value: reflowKey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollPosition($position)
        .scrollIndicators(.automatic)
        .onScrollGeometryChange(for: Int.self, of: { Int(floor($0.visibleRect.minY / MasonryGrid.step)) }, action: { _, next in bucket = next })
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.visibleRect.minY }, action: { _, y in probe.minY = y })
        .onScrollGeometryChange(for: Int.self, of: { Int(($0.visibleRect.minY / MasonryGrid.band).rounded()) }, action: { _, next in playBand = next })
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.visibleRect.height }, action: { _, h in viewport = h; probe.viewport = h })
        .onAppear {
            model.tileFrames = { [probe] in probe.frames() }
            model.layoutFrames = { [probe] in probe.layout.frames }
            let scroll = $position
            model.scrollToTile = { [probe] id in
                guard let frame = probe.layout.frames[id] else { return }
                let top = probe.minY + model.topInset - 24
                let bottom = probe.minY + probe.viewport - 120
                if frame.minY < top {
                    withAnimation(Theme.open) { scroll.wrappedValue.scrollTo(y: max(0, frame.minY - model.topInset + 24)) }
                } else if frame.maxY > bottom {
                    withAnimation(Theme.open) { scroll.wrappedValue.scrollTo(y: frame.maxY - probe.viewport + 120) }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width = $0 })
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    if pinchStart == nil { pinchStart = model.columnWidth }
                    model.columnWidth = min(440, max(140, (pinchStart ?? 248) * value.magnification))
                }
                .onEnded { _ in pinchStart = nil }
        )
        .onChange(of: model.feedback.focusID) { _, id in
            guard let id, let frame = layout.frames[id] else { return }
            withAnimation(Theme.open) { position.scrollTo(y: max(0, frame.minY - model.topInset)) }
            model.feedback.focusID = nil
        }
        .onChange(of: model.query) { _, _ in position.scrollTo(edge: .top) }
    }

    private func playingIDs(_ ids: [String], layout: MasonryLayout, lookup: [String: Save]) -> Set<String> {
        guard model.selectedID == nil, viewport > 0 else { return [] }
        let top = CGFloat(playBand) * Self.band
        let visible = CGRect(x: -10_000, y: top + 24, width: 100_000, height: max(0, viewport - 48))
        let center = visible.midY
        let candidates = ids.compactMap { id -> (String, CGFloat)? in
            guard lookup[id]?.motion != nil, let frame = layout.frames[id], frame.intersects(visible) else { return nil }
            return (id, abs(frame.midY - center))
        }
        return Set(candidates.sorted { $0.1 < $1.1 }.prefix(Self.maxPlaying).map(\.0))
    }

    private var reflowKey: String {
        "\(model.kind?.rawValue ?? "all")-\(model.filterCount)-\(model.folderID ?? "")-\(model.sidebarShown)-\(model.store.saves.count)-\(model.store.saves.first?.id ?? "")"
    }
}

private struct Arrival: ViewModifier {
    let landed: Bool

    func body(content: Content) -> some View {
        content
            .opacity(landed ? 1 : 0)
            .scaleEffect(landed ? 1 : 0.96)
            .offset(y: landed ? 0 : -12)
    }
}
