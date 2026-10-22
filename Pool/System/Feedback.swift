import Foundation
import Observation

@Observable
final class Feedback {
    let why: WhyPrompt

    init(why: WhyPrompt) {
        self.why = why
    }

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        var actionTitle: String?
        var action: (() -> Void)?
    }

    private(set) var toast: Toast?
    var focusID: String?

    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    func toast(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        toast = Toast(message: message, actionTitle: actionTitle, action: action)
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(action == nil ? 2.4 : 4.5))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }

    func holdToast(_ held: Bool) {
        guard let id = toast?.id else { return }
        dismissTask?.cancel()
        guard !held else { return }
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled, toast?.id == id else { return }
            toast = nil
        }
    }

    func dismissToast() {
        dismissTask?.cancel()
        toast = nil
    }

    func saved(count: Int = 1, message: String? = nil) {
        SoundEngine.shared.play(.drop)
        toast(message ?? (count == 1 ? L.Toast.saved : L.Toast.savedMany(count)))
    }

    func saved(_ saves: [Save], message: String? = nil, takesFocus: Bool = true) {
        guard !saves.isEmpty else { return }
        let askable = saves.filter { $0.kind != .note }.map(\.id)
        guard WhyPrompt.enabled, !askable.isEmpty else {
            saved(count: saves.count, message: message)
            return
        }
        SoundEngine.shared.play(.drop)
        dismissToast()
        why.present(askable, message: message ?? (saves.count == 1 ? L.Toast.saved : L.Toast.savedMany(saves.count)), takesFocus: takesFocus)
    }

    func focus(_ id: String) { focusID = id }
}
