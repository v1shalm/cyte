import Foundation
import Observation

@Observable
final class Feedback {
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

    func dismissToast() {
        dismissTask?.cancel()
        toast = nil
    }

    func saved(count: Int = 1, message: String? = nil) {
        SoundEngine.shared.play(.drop)
        toast(message ?? (count == 1 ? L.Toast.saved : L.Toast.savedMany(count)))
    }

    func focus(_ id: String) { focusID = id }
}
