import CoreGraphics
import Foundation
import Testing
@testable import Cyte

struct MediaTests {
    private func image(original: String?) -> Save {
        var save = Save(kind: .image)
        save.original = original
        return save
    }

    @Test(arguments: [
        ("original.mp4", MotionKind?.some(.video)),
        ("original.MOV", .some(.video)),
        ("original.m4v", .some(.video)),
        ("original.gif", .some(.gif)),
        ("original.png", nil),
        ("original.jpg", nil),
    ])
    func `motion follows the original file`(file: String, expected: MotionKind?) {
        #expect(image(original: file).motion == expected)
    }

    @Test func `links and notes never play`() {
        var link = Save(kind: .link)
        link.original = "original.mp4"
        #expect(link.motion == nil)
        #expect(image(original: nil).motion == nil)
    }

    @Test func `detects mp4 and mov from file headers`() {
        func header(_ brand: String) -> Data {
            Data([0, 0, 0, 0x18]) + Data("ftyp".utf8) + Data(brand.utf8) + Data(count: 8)
        }
        #expect(ImageFiles.videoExtension(for: header("isom")) == "mp4")
        #expect(ImageFiles.videoExtension(for: header("qt  ")) == "mov")
        #expect(ImageFiles.videoExtension(for: Data("GIF89a-not-a-video".utf8)) == nil)
        #expect(ImageFiles.videoExtension(for: Data([0, 1])) == nil)
    }

    @Test(arguments: [(0.0, "0:00"), (9.6, "0:09"), (75, "1:15"), (-1, "0:00"), (.nan, "0:00")])
    func `clock reads minutes and seconds`(seconds: Double, text: String) {
        #expect(VideoControls.clock(seconds) == text)
    }

    @Test func `recognises web links and video links`() {
        #expect(Ingestor.webURL(in: "https://example.com/a/1")?.host() == "example.com")
        #expect(Ingestor.webURL(in: "not a link") == nil)
        #expect(Ingestor.webURL(in: "ftp://files.example.com") == nil)
        #expect(Ingestor.looksLikeVideo(URL(string: "https://cdn.example.com/clip.MP4")!))
        #expect(!Ingestor.looksLikeVideo(URL(string: "https://cdn.example.com/clip.gif")!))
    }
}

struct MasonryTests {
    private func image(aspect: Double) -> Save { Save(kind: .image, aspect: aspect) }

    @Test func `tall and wide images stay within bounds`() {
        #expect(MasonryLayout.tileHeight(image(aspect: 0.1), width: 200) == 480)
        #expect(MasonryLayout.tileHeight(image(aspect: 10), width: 200) == 84)
        #expect(MasonryLayout.tileHeight(image(aspect: 1), width: 200) == 200)
    }

    @Test func `places every save once without overlaps`() {
        let saves = (0..<30).map { image(aspect: [0.6, 1, 1.7][$0 % 3]) }
        let layout = MasonryLayout.make(saves: saves, related: [], width: 1200, target: 248)
        #expect(layout.order.count == saves.count)
        #expect(Set(layout.order).count == saves.count)
        let frames = layout.order.compactMap { layout.frames[$0] }
        for (i, a) in frames.enumerated() {
            for b in frames[(i + 1)...] { #expect(!a.insetBy(dx: 1, dy: 1).intersects(b)) }
        }
    }
}
