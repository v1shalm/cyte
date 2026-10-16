import Foundation

nonisolated enum Identity {
    static let bundleID = "app.cyte.mac"
    static let legacyBundleID = "in.tistmedia.pool"
    static let subsystem = bundleID
    static let saveType = "app.cyte.mac.save"
    static let scheme = "cyte"
    static let schemes: Set<String> = ["cyte", "pool"]
    static let libraryFolder = "Cyte"
    static let libraryFolderNames: Set<String> = ["cyte", "pool"]

    static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func migrateLegacyDefaults(into defaults: UserDefaults = .standard, domain: String = bundleID, from legacy: [String: Any]? = UserDefaults.standard.persistentDomain(forName: legacyBundleID)) {
        guard let legacy, !legacy.isEmpty else { return }
        let saved = defaults.persistentDomain(forName: domain) ?? [:]
        guard saved["cyte.migrated"] == nil else { return }
        var merged = saved
        for (key, value) in legacy where key.hasPrefix("pool.") && saved[key] == nil {
            merged[key] = value
        }
        merged["cyte.migrated"] = true
        defaults.setPersistentDomain(merged, forName: domain)
    }
}
