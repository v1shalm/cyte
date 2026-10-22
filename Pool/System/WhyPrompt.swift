import AppKit
import Foundation
import Observation

@Observable
final class WhyPrompt {
    enum Stage: Equatable { case saved, asking, noted }

    struct Ask: Identifiable, Equatable {
        let id = UUID()
        var saveIDs: [String]
        var message: String
        let floating: Bool
        let takesFocus: Bool
    }

    private(set) var ask: Ask?
    private(set) var stage: Stage = .saved
    private(set) var elapsed: TimeInterval = 0
    private(set) var runningSince: Date?
    var text = "" { didSet { if text != oldValue { syncTimer() } } }
    var hovering = false { didSet { if hovering != oldValue { syncTimer() } } }
    var focused = false { didSet { if focused != oldValue { syncTimer() } } }
    let voice = VoiceInput()

    static let patience: TimeInterval = 8
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "pool.askWhy") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "pool.askWhy") }
    }

    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private var stageTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    init(store: LibraryStore) {
        self.store = store
    }

    var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isPaused: Bool { hovering || voice.isListening || (focused && hasText) }
    var count: Int { ask?.saveIDs.count ?? 0 }

    func present(_ ids: [String], message: String, takesFocus: Bool) {
        if var current = ask, stage == .asking, hasText || voice.isListening {
            current.saveIDs += ids.filter { !current.saveIDs.contains($0) }
            ask = current
            return
        }
        reset()
        let floating = !Self.libraryWindowIsFront
        ask = Ask(saveIDs: ids, message: message, floating: floating,
                  takesFocus: floating ? takesFocus : !Self.typingElsewhere)
        if floating { WhyPanel.shared.show(self) }
        stageTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            stage = .asking
            syncTimer()
        }
    }

    func submit() {
        if voice.isListening {
            let said = voice.stop()
            if !said.isEmpty { text = said }
        }
        let reason = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ask, !reason.isEmpty else {
            dismiss()
            return
        }
        for id in ask.saveIDs {
            store.modify(id) { save in
                save.note = save.note.isEmpty ? reason : save.note + "\n" + reason
            }
        }
        timerTask?.cancel()
        runningSince = nil
        stage = .noted
        SoundEngine.shared.play(.chime, volume: 0.45)
        stageTask = Task {
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            reset()
        }
    }

    func dismiss() {
        reset()
    }

    func toggleVoice() {
        if voice.isListening {
            let said = voice.stop()
            if !said.isEmpty { text = said }
            syncTimer()
            return
        }
        Task {
            await voice.start(stopAfterSilence: true) { [weak self] in
                guard let self else { return }
                let said = voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !said.isEmpty { text = said }
                syncTimer()
            }
            syncTimer()
        }
        syncTimer()
    }

    func remaining(at date: Date) -> Double {
        let spent = elapsed + (runningSince.map { date.timeIntervalSince($0) } ?? 0)
        return min(1, max(0, 1 - spent / Self.patience))
    }

    private func syncTimer() {
        guard stage == .asking else { return }
        if isPaused {
            if let since = runningSince {
                elapsed += Date().timeIntervalSince(since)
                runningSince = nil
            }
            timerTask?.cancel()
        } else if runningSince == nil {
            runningSince = Date()
            let left = max(0, Self.patience - elapsed)
            timerTask?.cancel()
            timerTask = Task {
                try? await Task.sleep(for: .seconds(left))
                guard !Task.isCancelled else { return }
                if hasText { submit() } else { dismiss() }
            }
        }
    }

    private func reset() {
        stageTask?.cancel()
        timerTask?.cancel()
        if voice.isListening { voice.cancel() }
        let wasFloating = ask?.floating == true
        ask = nil
        stage = .saved
        text = ""
        hovering = false
        focused = false
        elapsed = 0
        runningSince = nil
        if wasFloating { WhyPanel.shared.hide() }
    }

    static var libraryWindowIsFront: Bool {
        guard NSApp.isActive, let window = NSApp.keyWindow ?? NSApp.mainWindow else { return false }
        return window.isVisible && window.canBecomeMain && !(window is NSPanel)
    }

    private static var typingElsewhere: Bool {
        NSApp.keyWindow?.firstResponder is NSText
    }
}
