import Foundation

nonisolated struct XTweet: Sendable, Hashable {
    struct Media: Sendable, Hashable {
        let url: URL
        let videoURL: URL?
        let aspect: Double
        let isVideo: Bool
    }

    let id: String
    let handle: String
    let name: String
    let text: String
    let media: [Media]

    var url: URL { URL(string: "https://x.com/\(handle)/status/\(id)") ?? URL(string: "https://x.com")! }

    func mediaURL(_ index: Int) -> URL {
        url.appending(path: media[index].isVideo ? "video/1" : "photo/\(index + 1)")
    }

    static func id(in url: URL?) -> String? {
        guard let url, let host = url.host(), host.hasSuffix("x.com") || host.hasSuffix("twitter.com") else { return nil }
        let parts = url.pathComponents
        guard let index = parts.firstIndex(of: "status"), parts.indices.contains(index + 1) else { return nil }
        return parts[index + 1]
    }
}

nonisolated enum XParser {
    static func tweets(in data: Data) -> [XTweet] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var entries: [[String: Any]] = []
        collectEntries(json, into: &entries)
        return entries.compactMap { entry in
            guard let entryID = entry["entryId"] as? String, entryID.hasPrefix("tweet-") else { return nil }
            let result = dig(entry, "content", "itemContent", "tweet_results", "result")
            return tweet(from: result)
        }
    }

    private static func collectEntries(_ node: Any, into entries: inout [[String: Any]]) {
        if let dict = node as? [String: Any] {
            if let list = dict["entries"] as? [[String: Any]] { entries += list }
            if let entry = dict["entry"] as? [String: Any], entry["entryId"] != nil { entries.append(entry) }
            for (key, value) in dict where key != "entries" && key != "entry" {
                collectEntries(value, into: &entries)
            }
        } else if let array = node as? [Any] {
            for value in array { collectEntries(value, into: &entries) }
        }
    }

    private static func tweet(from node: Any?) -> XTweet? {
        guard var node = node as? [String: Any] else { return nil }
        if let inner = node["tweet"] as? [String: Any] { node = inner }
        guard let legacy = node["legacy"] as? [String: Any],
              let id = (node["rest_id"] as? String) ?? (legacy["id_str"] as? String) else { return nil }

        let user = dig(node, "core", "user_results", "result") as? [String: Any] ?? [:]
        let handle = (dig(user, "core", "screen_name") as? String) ?? (dig(user, "legacy", "screen_name") as? String) ?? "i"
        let name = (dig(user, "core", "name") as? String) ?? (dig(user, "legacy", "name") as? String) ?? handle

        let long = dig(node, "note_tweet", "note_tweet_results", "result", "text") as? String
        var text = long ?? (legacy["full_text"] as? String) ?? ""
        let entities = legacy["entities"] as? [String: Any] ?? [:]
        for link in entities["urls"] as? [[String: Any]] ?? [] {
            if let short = link["url"] as? String, let expanded = link["expanded_url"] as? String {
                text = text.replacingOccurrences(of: short, with: expanded)
            }
        }
        let mediaList = (dig(legacy, "extended_entities", "media") as? [[String: Any]]) ?? (entities["media"] as? [[String: Any]]) ?? []
        for item in mediaList {
            if let short = item["url"] as? String { text = text.replacingOccurrences(of: short, with: "") }
        }
        text = decode(text).trimmingCharacters(in: .whitespacesAndNewlines)

        let media: [XTweet.Media] = mediaList.compactMap { item in
            guard let raw = item["media_url_https"] as? String, var parts = URLComponents(string: raw) else { return nil }
            parts.queryItems = [URLQueryItem(name: "name", value: "large")]
            guard let url = parts.url else { return nil }
            let width = dig(item, "original_info", "width") as? Double ?? 0
            let height = dig(item, "original_info", "height") as? Double ?? 0
            let type = item["type"] as? String ?? "photo"
            let isVideo = type != "photo"
            let videoURL = isVideo ? bestVideoURL(in: item) : nil
            return XTweet.Media(url: url, videoURL: videoURL, aspect: height > 0 ? width / height : 0, isVideo: isVideo)
        }

        return XTweet(id: id, handle: handle, name: name, text: text, media: media)
    }

    private static func bestVideoURL(in item: [String: Any]) -> URL? {
        guard let variants = dig(item, "video_info", "variants") as? [[String: Any]] else { return nil }
        let mp4s = variants.compactMap { variant -> (bitrate: Int, url: URL)? in
            let contentType = (variant["content_type"] as? String)?.lowercased() ?? ""
            guard contentType == "video/mp4" || (variant["url"] as? String)?.contains(".mp4") == true,
                  let raw = variant["url"] as? String,
                  let url = URL(string: raw) else { return nil }
            let bitrate = (variant["bitrate"] as? Int) ?? (variant["bitrate"] as? NSNumber)?.intValue ?? 0
            return (bitrate, url)
        }
        return mp4s.max(by: { $0.bitrate < $1.bitrate })?.url
    }

    private static func dig(_ node: Any?, _ keys: String...) -> Any? {
        var current = node
        for key in keys { current = (current as? [String: Any])?[key] }
        return current
    }

    private static func decode(_ text: String) -> String {
        text.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
