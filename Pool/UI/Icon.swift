import AppKit
import SwiftUI

enum IconSize {
    static let xs: CGFloat = 12
    static let sm: CGFloat = 14
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
}

struct Icon: View {
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
            Self.image(Self.asset(name)).opacity(1 - fill)
            if let asset = Self.fillAsset(name), fill > 0 {
                Self.image(asset).opacity(fill)
            }
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
        "folder": "folder",
        "folder.fill": "folder",
        "folder.badge.plus": "folder-add",
        "xmark": "cancel",
        "xmark.circle.fill": "cancel-circle",
        "link": "link",
        "checkmark": "tick",
        "trash": "trash",
        "mic": "mic",
        "waveform": "wave",
        "doc.on.clipboard": "clipboard",
        "return": "return",
        "plus": "plus",
        "magnifyingglass": "search",
        "arrow.right": "arrow-right",
        "text.alignleft": "text-left",
        "photo": "image",
        "photo.on.rectangle": "image-stack",
        "number": "hashtag",
        "bookmark": "bookmark",
        "bookmark.fill": "bookmark",
        "arrow.up.right": "arrow-up-right",
        "square.grid.3x3": "grid-3x3",
        "square.grid.2x2": "grid-2x2",
        "square.grid.2x2.fill": "grid-2x2",
        "sidebar.left": "sidebar-left",
        "line.3.horizontal.decrease": "filter",
        "chevron.left": "chevron-left",
        "chevron.right": "chevron-right",
        "chevron.down": "chevron-down",
        "arrow.down": "arrow-down",
        "arrow.up": "arrow-up",
        "arrow.up.arrow.down": "sort",
        "sparkles": "sparkles",
        "square.on.square.dashed": "search-visual",
        "square.and.pencil": "edit",
        "shuffle": "shuffle",
        "gearshape": "settings",
        "gearshape.fill": "settings",
        "doc.on.doc": "copy",
        "speaker.wave.2.fill": "volume-high",
        "speaker.slash.fill": "volume-off",
    ]

    private static let fillSlugs: [String: String] = [
        "folder": "folder-fill",
        "bookmark": "bookmark-fill",
        "grid-2x2": "grid-fill",
        "settings": "settings-fill",
    ]

    static func asset(_ name: String) -> String { "ph-" + (slugs[name] ?? name) }

    static func fillAsset(_ name: String) -> String? {
        fillSlugs[slugs[name] ?? name].map { "ph-" + $0 }
    }

    static func nsImage(_ name: String, size: CGFloat = IconSize.md) -> NSImage? {
        guard let image = NSImage(named: asset(name))?.copy() as? NSImage else { return nil }
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        return image
    }
}
