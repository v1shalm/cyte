import Foundation
import Observation
import Sparkle

@Observable
final class Updater {
    static let shared = Updater()

    @ObservationIgnored private let controller: SPUStandardUpdaterController?

    var isAvailable: Bool { controller != nil }

    var checksAutomatically: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = checksAutomatically }
    }

    private init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        if key.isEmpty || Identity.isTesting {
            controller = nil
            checksAutomatically = false
        } else {
            let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            self.controller = controller
            checksAutomatically = controller.updater.automaticallyChecksForUpdates
        }
    }

    func checkNow() {
        controller?.checkForUpdates(nil)
    }
}
