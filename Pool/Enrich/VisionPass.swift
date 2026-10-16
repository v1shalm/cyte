import CoreGraphics
import Foundation
import Vision

nonisolated struct VisionResult: Sendable {
    var text: String?
    var labels: [String] = []
    var palette: [String] = []
    var printData: Data?
}

nonisolated enum VisionPass {
    private static let ignoredLabels: Set<String> = [
        "structure", "material", "document", "text", "screenshot", "adult", "people", "indoor", "outdoor",
        "conveyance", "consumer electronics", "machine", "tool", "wood processed", "textile", "art",
    ]

    @concurrent
    static func analyze(_ url: URL) async -> VisionResult {
        guard let image = ImageFiles.downsample(url, maxPixel: 1600) else { return VisionResult() }
        var result = VisionResult()

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        let classify = VNClassifyImageRequest()
        let featurePrint = VNGenerateImageFeaturePrintRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([textRequest, classify, featurePrint])

        let lines = (textRequest.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { result.text = String(text.prefix(4000)) }

        result.labels = (classify.results ?? [])
            .filter { $0.confidence > 0.35 }
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
            .filter { !ignoredLabels.contains($0) }
            .prefix(6)
            .map { $0 }

        if let observation = featurePrint.results?.first {
            result.printData = try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
        }

        result.palette = Palette.extract(from: image)
        return result
    }

    @concurrent
    static func nearest(to target: Data, among candidates: [(id: String, data: Data)], limit: Int) async -> [String] {
        guard let anchor = unarchive(target) else { return [] }
        var scored: [(id: String, distance: Float)] = []
        scored.reserveCapacity(candidates.count)
        for candidate in candidates {
            guard let other = unarchive(candidate.data) else { continue }
            var distance: Float = 0
            guard (try? anchor.computeDistance(&distance, to: other)) != nil else { continue }
            scored.append((candidate.id, distance))
        }
        return scored.sorted { $0.distance < $1.distance }.prefix(limit).map(\.id)
    }

    private static func unarchive(_ data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }
}

nonisolated enum Palette {
    static func extract(from image: CGImage, count: Int = 5) -> [String] {
        let side = 40
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drew else { return [] }

        var points: [SIMD3<Float>] = []
        points.reserveCapacity(side * side)
        for index in stride(from: 0, to: pixels.count, by: 4) where pixels[index + 3] > 200 {
            points.append(SIMD3(Float(pixels[index]), Float(pixels[index + 1]), Float(pixels[index + 2])))
        }
        guard points.count >= count else { return [] }

        var centers = (0..<count).map { points[($0 * points.count) / count] }
        var sizes = [Int](repeating: 0, count: count)
        for _ in 0..<10 {
            var sums = [SIMD3<Float>](repeating: .zero, count: count)
            sizes = [Int](repeating: 0, count: count)
            for point in points {
                var best = 0
                var bestDistance = Float.greatestFiniteMagnitude
                for (index, center) in centers.enumerated() {
                    let delta = point - center
                    let distance = (delta * delta).sum()
                    if distance < bestDistance { bestDistance = distance; best = index }
                }
                sums[best] += point
                sizes[best] += 1
            }
            for index in 0..<count where sizes[index] > 0 {
                centers[index] = sums[index] / Float(sizes[index])
            }
        }

        var picked: [SIMD3<Float>] = []
        for index in sizes.indices.sorted(by: { sizes[$0] > sizes[$1] }) where sizes[index] > 0 {
            let center = centers[index]
            let distinct = picked.allSatisfy { other in
                let delta = other - center
                return (delta * delta).sum() > 900
            }
            if distinct { picked.append(center) }
        }
        return picked.map { color in
            String(format: "#%02X%02X%02X", Int(color.x.rounded()), Int(color.y.rounded()), Int(color.z.rounded()))
        }
    }

    static func rgb(_ hex: String) -> SIMD3<Float>? {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return SIMD3(Float((value >> 16) & 0xFF), Float((value >> 8) & 0xFF), Float(value & 0xFF))
    }
}
