import AVFoundation
import Foundation

final class SoundEngine {
    static let shared = SoundEngine()

    enum Cue { case drop, delete, chime, whoosh, flip }

    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "pool.sound") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "pool.sound") }
    }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var started = false
    private var taps: [AVAudioPCMBuffer] = []
    private var cues: [Cue: AVAudioPCMBuffer] = [:]
    private var lastTap = Date.distantPast
    private var tapsThisWindow = 0

    private init() {
        for _ in 0..<12 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.9
        taps = [2100, 2500, 2900, 3400].map { makeTap(frequency: $0) }
        cues[.drop] = makeDrop()
        cues[.delete] = makeSweep(from: 880, to: 420, length: 0.07, level: 0.22)
        cues[.chime] = makeChime()
        cues[.whoosh] = makeWhoosh()
        cues[.flip] = makeTap(frequency: 4200, length: 0.012)
    }

    func play(_ cue: Cue, volume: Float = 1) {
        guard enabled, let buffer = cues[cue] else { return }
        schedule(buffer, volume: volume)
    }

    func tap(intensity: Double, size: Double) {
        guard enabled else { return }
        let now = Date()
        if now.timeIntervalSince(lastTap) > 0.05 { tapsThisWindow = 0; lastTap = now }
        guard tapsThisWindow < 3 else { return }
        tapsThisWindow += 1
        let level = Float(min(1, max(0.06, intensity)))
        let index = min(taps.count - 1, max(0, Int((1 - min(size, 1)) * Double(taps.count))))
        schedule(taps[index], volume: level * 0.55)
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, volume: Float) {
        startIfNeeded()
        guard started else { return }
        let player = players[next]
        next = (next + 1) % players.count
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    private func startIfNeeded() {
        guard !started else { return }
        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    private func buffer(seconds: Double, _ sample: (Double, Int) -> Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let channel = buffer.floatChannelData![0]
        for index in 0..<Int(frames) {
            channel[index] = Float(sample(Double(index) / format.sampleRate, index))
        }
        return buffer
    }

    private func makeTap(frequency: Double, length: Double = 0.03) -> AVAudioPCMBuffer {
        var low = 0.0
        return buffer(seconds: length) { t, _ in
            let envelope = exp(-t / (length / 5))
            let attack = min(1, t / 0.0008)
            let noise = Double.random(in: -1...1)
            low += 0.35 * (noise - low)
            let tone = sin(2 * .pi * frequency * t) * 0.5
            return (tone + low * 0.8) * envelope * attack * 0.6
        }
    }

    private func makeDrop() -> AVAudioPCMBuffer {
        var phase = 0.0
        return buffer(seconds: 0.16) { t, _ in
            let frequency = 380 + 1500 * pow(min(t / 0.05, 1), 1.6)
            phase += 2 * .pi * frequency / 44_100
            let attack = min(1, t / 0.003)
            let envelope = exp(-t / 0.035)
            return sin(phase) * attack * envelope * 0.42
        }
    }

    private func makeSweep(from: Double, to: Double, length: Double, level: Double) -> AVAudioPCMBuffer {
        var phase = 0.0
        return buffer(seconds: length) { t, _ in
            let progress = t / length
            let frequency = from + (to - from) * progress
            phase += 2 * .pi * frequency / 44_100
            return sin(phase) * min(1, t / 0.002) * (1 - progress) * level
        }
    }

    private func makeChime() -> AVAudioPCMBuffer {
        let partials: [(Double, Double, Double)] = [(659.25, 0.30, 1.1), (987.77, 0.18, 0.8), (1318.5, 0.10, 0.6), (1975.5, 0.04, 0.35)]
        return buffer(seconds: 1.4) { t, _ in
            let attack = min(1, t / 0.006)
            return partials.reduce(0) { sum, partial in
                sum + sin(2 * .pi * partial.0 * t) * partial.1 * exp(-t / partial.2)
            } * attack * 0.7
        }
    }

    private func makeWhoosh() -> AVAudioPCMBuffer {
        var low = 0.0
        var lower = 0.0
        let length = 0.7
        return buffer(seconds: length) { t, _ in
            let progress = t / length
            let swell = sin(.pi * progress)
            let cutoff = 0.02 + 0.10 * swell
            low += cutoff * (Double.random(in: -1...1) - low)
            lower += cutoff * (low - lower)
            return lower * swell * 1.4
        }
    }
}
