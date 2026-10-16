import AppKit
import CryptoKit
import MetricKit
import Observation

@Observable
final class Diagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = Diagnostics()

    private(set) var reports: [URL] = []
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let defaults: UserDefaults
    private static let dismissedKey = "pool.reports.dismissed"

    static var supportEmail: String {
        Bundle.main.object(forInfoDictionaryKey: "CyteSupportEmail") as? String ?? ""
    }

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Cyte/Diagnostics", directoryHint: .isDirectory), defaults: UserDefaults = .standard) {
        self.directory = directory
        self.defaults = defaults
        super.init()
    }

    func start() {
        MXMetricManager.shared.add(self)
        store(MXMetricManager.shared.pastDiagnosticPayloads)
        reload()
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let data = payloads.map { $0.jsonRepresentation() }
        Task { @MainActor in
            self.write(data)
            self.reload()
        }
    }

    private func store(_ payloads: [MXDiagnosticPayload]) {
        write(payloads.map { $0.jsonRepresentation() })
    }

    func write(_ payloads: [Data]) {
        guard !payloads.isEmpty else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dismissed = Set(defaults.stringArray(forKey: Self.dismissedKey) ?? [])
        for data in payloads {
            let digest = SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
            guard !dismissed.contains(digest) else { continue }
            let name = "report-\(digest).json"
            let url = directory.appending(path: name)
            if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        let cutoff = Date().addingTimeInterval(-90 * 86_400)
        var kept: [URL] = []
        for file in files where file.pathExtension == "json" {
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if date < cutoff { try? FileManager.default.removeItem(at: file) } else { kept.append(file) }
        }
        reports = kept.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
    }

    func send() {
        guard !reports.isEmpty else { return }
        let email = Self.supportEmail
        if !email.isEmpty, let service = NSSharingService(named: .composeEmail) {
            service.recipients = [email]
            service.subject = L.Settings.reportSubject(version: Self.version)
            let items: [Any] = [L.Settings.reportBody] + reports.map { $0 as NSURL }
            if service.canPerform(withItems: items) {
                service.perform(withItems: items)
                return
            }
        }
        reveal()
    }

    func reveal() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let first = reports.first {
            NSWorkspace.shared.activateFileViewerSelecting([first])
        } else {
            NSWorkspace.shared.open(directory)
        }
    }

    func clear() {
        var dismissed = defaults.stringArray(forKey: Self.dismissedKey) ?? []
        for report in reports {
            dismissed.append(String(report.deletingPathExtension().lastPathComponent.dropFirst("report-".count)))
            try? FileManager.default.removeItem(at: report)
        }
        defaults.set(Array(dismissed.suffix(200)), forKey: Self.dismissedKey)
        reload()
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }
}
