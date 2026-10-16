import Foundation
import Testing
@testable import Cyte

struct XParserTests {
    private func entry(_ id: String, text: String, media: [[String: Any]]) -> [String: Any] {
        [
            "entryId": "tweet-\(id)",
            "content": [
                "itemContent": [
                    "tweet_results": [
                        "result": [
                            "rest_id": id,
                            "core": ["user_results": ["result": ["core": ["screen_name": "studio", "name": "Studio"]]]],
                            "legacy": [
                                "full_text": text,
                                "entities": ["urls": []],
                                "extended_entities": ["media": media],
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }

    private func timeline(_ entries: [[String: Any]]) throws -> Data {
        let json: [String: Any] = [
            "data": ["bookmark_timeline_v2": ["timeline": ["instructions": [["type": "TimelineAddEntries", "entries": entries + [["entryId": "cursor-bottom-1", "content": ["value": "next"]]]]]]]],
        ]
        return try JSONSerialization.data(withJSONObject: json)
    }

    private let photo: [String: Any] = [
        "type": "photo",
        "url": "https://t.co/photo",
        "media_url_https": "https://pbs.twimg.com/media/photo.jpg",
        "original_info": ["width": 1200.0, "height": 800.0],
    ]

    private let video: [String: Any] = [
        "type": "video",
        "url": "https://t.co/video",
        "media_url_https": "https://pbs.twimg.com/ext_tw_video_thumb/1/pu/img/poster.jpg",
        "original_info": ["width": 720.0, "height": 1280.0],
        "video_info": ["variants": [
            ["content_type": "application/x-mpegURL", "url": "https://video.twimg.com/pl/list.m3u8"],
            ["content_type": "video/mp4", "bitrate": 632000, "url": "https://video.twimg.com/vid/320x568/low.mp4"],
            ["content_type": "video/mp4", "bitrate": 2176000, "url": "https://video.twimg.com/vid/720x1280/high.mp4"],
        ]],
    ]

    @Test func `parses photos, videos and text-only posts`() throws {
        let data = try timeline([
            entry("1", text: "A poster https://t.co/photo", media: [photo]),
            entry("2", text: "Motion study", media: [video]),
            entry("3", text: "Just words", media: []),
        ])
        let tweets = XParser.tweets(in: data)
        #expect(tweets.map(\.id) == ["1", "2", "3"])
        #expect(tweets[0].text == "A poster")
        #expect(tweets[0].handle == "studio")
        #expect(tweets[2].media.isEmpty)
    }

    @Test func `picks the highest bitrate mp4 for a video`() throws {
        let tweets = XParser.tweets(in: try timeline([entry("2", text: "", media: [video])]))
        let media = try #require(tweets.first?.media.first)
        #expect(media.isVideo)
        #expect(media.videoURL?.absoluteString == "https://video.twimg.com/vid/720x1280/high.mp4")
        #expect(abs(media.aspect - 0.5625) < 0.0001)
        #expect(tweets[0].mediaURL(0).path().hasSuffix("/status/2/video/1"))
    }

    @Test func `photos carry no video url`() throws {
        let tweets = XParser.tweets(in: try timeline([entry("1", text: "", media: [photo])]))
        let media = try #require(tweets.first?.media.first)
        #expect(!media.isVideo)
        #expect(media.videoURL == nil)
        #expect(media.url.query()?.contains("name=large") == true)
        #expect(tweets[0].mediaURL(0).path().hasSuffix("/photo/1"))
    }

    @Test func `ignores responses that are not json`() {
        #expect(XParser.tweets(in: Data("<html>".utf8)).isEmpty)
    }

    @Test func `reads a tweet id from x and twitter urls only`() {
        #expect(XTweet.id(in: URL(string: "https://x.com/a/status/42/video/1")) == "42")
        #expect(XTweet.id(in: URL(string: "https://twitter.com/a/status/7")) == "7")
        #expect(XTweet.id(in: URL(string: "https://example.com/a/status/7")) == nil)
    }
}
