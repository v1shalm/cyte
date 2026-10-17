import AppKit
import SwiftUI

actor DecodeGate {
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private let limit = 3

    func acquire() async {
        if running < limit { running += 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty { running -= 1 } else { waiters.removeLast().resume() }
    }
}

final class ThumbCache {
    static let shared = ThumbCache()
    private let cache = NSCache<NSString, NSImage>()
    private let gate = DecodeGate()

    private init() { cache.totalCostLimit = 192 * 1024 * 1024 }

    func image(_ key: String) -> NSImage? { cache.object(forKey: key as NSString) }

    func store(_ image: NSImage, key: String, cost: Int) { cache.setObject(image, forKey: key as NSString, cost: cost) }

    func load(_ url: URL, maxPixel: Int) async -> NSImage? {
        let key = "\(url.path(percentEncoded: false))#\(maxPixel)"
        if let hit = image(key) { return hit }
        await gate.acquire()
        guard !Task.isCancelled else { await gate.release(); return nil }
        let decoded = await Self.decode(url, maxPixel: maxPixel)
        await gate.release()
        guard let decoded else { return nil }
        let image = NSImage(cgImage: decoded, size: NSSize(width: decoded.width, height: decoded.height))
        store(image, key: key, cost: decoded.bytesPerRow * decoded.height)
        return image
    }

    @concurrent
    private static func decode(_ url: URL, maxPixel: Int) async -> CGImage? {
        ImageFiles.downsample(url, maxPixel: maxPixel)
    }
}

struct Key: Hashable {
    let url: URL?
    let maxPixel: Int
}

struct Thumb: View {
    let url: URL?
    var maxPixel: Int = 900
    var contentMode: ContentMode = .fill
    var tint: Color?

    @State private var image: NSImage?

    var body: some View {
        Theme.fill
            .overlay {
                if let tint { tint.opacity(0.3) }
            }
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity.animation(Theme.fade))
                }
            }
            .clipped()
        .task(id: Key(url: url, maxPixel: maxPixel)) {
            guard let url else { image = nil; return }
            let key = "\(url.path(percentEncoded: false))#\(maxPixel)"
            if let hit = ThumbCache.shared.image(key) {
                image = hit
                return
            }
            image = await ThumbCache.shared.load(url, maxPixel: maxPixel)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

extension Save {
    var tint: Color? { palette.first.map { Theme.color(hex: $0) } }
}
