import AppKit
import SwiftUI

enum IconSize {
    static let xs: CGFloat = 12
    static let sm: CGFloat = 14
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
}

struct HugeIcon: View {
    let name: String
    var size: CGFloat
    var fill: Double

    init(_ name: String, size: CGFloat = IconSize.md, fill: Double = 0) {
        self.name = name
        self.size = size
        self.fill = fill
    }

    var body: some View {
        ZStack {
            if let asset = Self.fillAsset(name), fill > 0 {
                Self.image(asset).opacity(fill)
            }
            Self.image(Self.asset(name))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static func image(_ asset: String) -> some View {
        Image(asset)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }

    private static let slugs: [String: String] = [
        "folder": "folder-01",
        "folder.fill": "folder-01",
        "folder.badge.plus": "folder-add",
        "xmark": "cancel-01",
        "xmark.circle.fill": "cancel-circle",
        "link": "link-01",
        "checkmark": "tick-02",
        "trash": "delete-02",
        "mic": "mic-01",
        "waveform": "audio-wave-01",
        "doc.on.clipboard": "clipboard",
        "return": "arrow-turn-backward",
        "plus": "plus-sign",
        "magnifyingglass": "search-01",
        "arrow.right": "arrow-right-02",
        "text.alignleft": "text-align-left",
        "photo": "image-01",
        "photo.on.rectangle": "image-02",
        "number": "hashtag",
        "bookmark": "bookmark-01",
        "bookmark.fill": "bookmark-01",
        "arrow.up.right": "arrow-up-right-01",
        "square.grid.3x3": "grid-3x-3",
        "square.grid.2x2": "grid-2x-2",
        "square.grid.2x2.fill": "grid-view",
        "sidebar.left": "sidebar-left",
        "line.3.horizontal.decrease": "filter-horizontal",
        "chevron.left": "arrow-left-01",
        "chevron.right": "arrow-right-01",
        "chevron.down": "arrow-down-01",
        "arrow.down": "arrow-down-02",
        "arrow.up": "arrow-up-02",
        "arrow.up.arrow.down": "arrow-up-down",
        "sparkles": "sparkles",
        "square.on.square.dashed": "search-visual",
        "square.and.pencil": "note-edit",
        "shuffle": "shuffle",
        "gearshape": "settings-01",
        "gearshape.fill": "settings-01",
        "doc.on.doc": "copy-01",
        "speaker.wave.2.fill": "volume-high",
        "speaker.slash.fill": "volume-off",
    ]

    private static let fillSlugs: Set<String> = ["folder-01", "bookmark-01", "grid-view", "settings-01"]

    static func asset(_ name: String) -> String { "hi-" + (slugs[name] ?? name) }

    static func fillAsset(_ name: String) -> String? {
        let slug = slugs[name] ?? name
        return fillSlugs.contains(slug) ? "hi-" + slug + "-fill" : nil
    }

    static func nsImage(_ name: String, size: CGFloat = IconSize.md) -> NSImage? {
        guard let image = NSImage(named: asset(name))?.copy() as? NSImage else { return nil }
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        return image
    }
}
