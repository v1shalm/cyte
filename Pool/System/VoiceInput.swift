import AVFoundation
import Foundation
import Observation
import Speech

@Observable
final class VoiceInput {
    enum Phase: Equatable { case idle, starting, listening, denied, failed }

    private(set) var phase: Phase = .idle
    private(set) var transcript = ""
    private(set) var level: Double = 0

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var silenceTask: Task<Void, Never>?
    @ObservationIgnored private var onSilence: (() -> Void)?

    var isListening: Bool { phase == .listening || phase == .starting }

    func start(stopAfterSilence: Bool = false, onSilence: (() -> Void)? = nil) async {
        guard !isListening else { return }
        transcript = ""
        level = 0
        phase = .starting
        guard await Self.authorize() else {
            phase = .denied
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            phase = .failed
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format,
                         block: Self.tap(request: request) { [weak self] value in self?.receive(level: value) })
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            phase = .failed
            return
        }

        self.engine = engine
        self.request = request
        self.onSilence = stopAfterSilence ? onSilence : nil
        task = recognizer.recognitionTask(with: request, resultHandler: Self.handler { [weak self] text, final in
            self?.receive(text: text, final: final)
        })
        phase = .listening
        if stopAfterSilence { armSilence() }
    }

    @discardableResult
    func stop() -> String {
        silenceTask?.cancel()
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        engine = nil
        request = nil
        task = nil
        onSilence = nil
        level = 0
        if phase != .denied && phase != .failed { phase = .idle }
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancel() {
        stop()
        transcript = ""
    }

    private func receive(text: String, final: Bool) {
        guard isListening else { return }
        transcript = text
        if onSilence != nil { armSilence() }
    }

    private func receive(level value: Double) {
        guard isListening else { return }
        level = level * 0.6 + value * 0.4
    }

    private func armSilence() {
        silenceTask?.cancel()
        silenceTask = Task {
            try? await Task.sleep(for: .seconds(transcript.isEmpty ? 6 : 1.6))
            guard !Task.isCancelled, isListening else { return }
            let callback = onSilence
            stop()
            callback?()
        }
    }

    nonisolated private static func tap(request: SFSpeechAudioBufferRecognitionRequest,
                                         level: @escaping @MainActor (Double) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var sum: Float = 0
            for index in 0..<count { sum += channel[index] * channel[index] }
            let rms = (sum / Float(count)).squareRoot()
            let normalized = Double(min(1, max(0, (20 * log10(max(rms, 0.000_01)) + 50) / 45)))
            Task { @MainActor in level(normalized) }
        }
    }

    nonisolated private static func handler(_ deliver: @escaping @MainActor (String, Bool) -> Void)
        -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, _ in
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            let final = result.isFinal
            Task { @MainActor in deliver(text, final) }
        }
    }

    nonisolated private static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status == .authorized) }
        }
        guard speech else { return false }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }
}
