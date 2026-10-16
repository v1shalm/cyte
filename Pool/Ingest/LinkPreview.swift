import Foundation
import LinkPresentation
import UniformTypeIdentifiers

nonisolated struct LinkPreviewResult: Sendable {
    var title: String?
    var description: String?
    var imageData: Data?
    var iconData: Data?
}

enum LinkPreview {
    static func fetch(_ url: URL) async -> LinkPreviewResult {
        var result = LinkPreviewResult()

        let provider = LPMetadataProvider()
        provider.timeout = 15
        if let meta = try? await provider.startFetchingMetadata(for: url) {
            result.title = meta.title
            if let image = meta.imageProvider { result.imageData = await loadImage(image) }
            if let icon = meta.iconProvider { result.iconData = await loadImage(icon) }
        }

        if result.imageData == nil || result.title == nil || result.description == nil,
           let page = await PageMeta.fetch(url) {
            if result.title == nil { result.title = page.title }
            result.description = page.description
            if result.imageData == nil, let imageURL = page.image {
                result.imageData = await download(imageURL)
            }
        }
        return result
    }

    private static func loadImage(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    static func download(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(PageMeta.userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 200 < 400,
              ImageFiles.info(data: data) != nil else { return nil }
        return data
    }
}

nonisolated struct PageMeta: Sendable {
    var title: String?
    var description: String?
    var image: URL?

    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    static func fetch(_ url: URL) async -> PageMeta? {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let html = String(decoding: data.prefix(400_000), as: UTF8.self)
        return parse(html, base: url)
    }

    static func parse(_ html: String, base: URL) -> PageMeta {
        var tags: [String: String] = [:]
        for match in html.matches(of: /<meta\s[^>]*>/.ignoresCase()) {
            let tag = String(match.output)
            guard let key = attribute("property", in: tag) ?? attribute("name", in: tag),
                  let content = attribute("content", in: tag) else { continue }
            let lower = key.lowercased()
            if tags[lower] == nil { tags[lower] = decodeEntities(content) }
        }
        var meta = PageMeta()
        meta.title = tags["og:title"] ?? tags["twitter:title"] ?? titleTag(in: html)
        meta.description = tags["og:description"] ?? tags["twitter:description"] ?? tags["description"]
        if let raw = tags["og:image"] ?? tags["og:image:url"] ?? tags["twitter:image"] ?? tags["twitter:image:src"] {
            meta.image = URL(string: raw, relativeTo: base)?.absoluteURL
        }
        return meta
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        let lower = tag.lowercased()
        for quote in ["\"", "'"] {
            guard let start = lower.range(of: "\(name)=\(quote)") else { continue }
            let rest = tag[start.upperBound...]
            guard let end = rest.firstIndex(of: Character(quote)) else { continue }
            return String(rest[..<end])
        }
        return nil
    }

    private static func titleTag(in html: String) -> String? {
        guard let match = html.firstMatch(of: /<title[^>]*>([^<]{1,300})<\/title>/.ignoresCase()) else { return nil }
        let title = decodeEntities(String(match.output.1)).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
