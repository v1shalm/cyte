import CommonCrypto
import Foundation
import Security
import SQLite3

nonisolated struct BrowserLogin: Sendable {
    nonisolated struct Browser: Sendable {
        let name: String
        let folder: String
        let service: String
        let account: String
    }

    static let browsers = [
        Browser(name: "Dia", folder: "Dia/User Data", service: "Dia Safe Storage", account: "Dia"),
        Browser(name: "Chrome", folder: "Google/Chrome", service: "Chrome Safe Storage", account: "Chrome"),
        Browser(name: "Arc", folder: "Arc/User Data", service: "Arc Safe Storage", account: "Arc"),
        Browser(name: "Brave", folder: "BraveSoftware/Brave-Browser", service: "Brave Safe Storage", account: "Brave"),
        Browser(name: "Edge", folder: "Microsoft Edge", service: "Microsoft Edge Safe Storage", account: "Microsoft Edge"),
    ]

    let browser: Browser
    let cookies: [HTTPCookie]

    static func find() -> (browser: Browser, database: URL)? {
        let support = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        for browser in browsers {
            let root = support.appending(path: browser.folder)
            guard let profiles = try? FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false)) else { continue }
            let ordered = profiles.filter { $0 == "Default" || $0.hasPrefix("Profile ") }.sorted { $0 == "Default" || ($1 != "Default" && $0 < $1) }
            for profile in ordered {
                let database = root.appending(path: "\(profile)/Cookies")
                if let rows = rows(in: database), rows.contains(where: { $0.name == "auth_token" }) {
                    return (browser, database)
                }
            }
        }
        return nil
    }

    static func load() -> BrowserLogin? {
        guard let (browser, database) = find(), let rows = rows(in: database), let key = key(for: browser) else { return nil }
        let version = Int(meta("version", in: database) ?? "") ?? 0
        let cookies: [HTTPCookie] = rows.compactMap { row in
            guard let value = row.plain.isEmpty ? decrypt(row.encrypted, key: key, stripHash: version >= 24) : row.plain,
                  !value.isEmpty else { return nil }
            var properties: [HTTPCookiePropertyKey: Any] = [
                .domain: row.host,
                .path: row.path.isEmpty ? "/" : row.path,
                .name: row.name,
                .value: value,
            ]
            if row.secure { properties[.secure] = "TRUE" }
            if row.httpOnly { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
            if row.expires > 0 {
                properties[.expires] = Date(timeIntervalSince1970: Double(row.expires) / 1_000_000 - 11_644_473_600)
            }
            return HTTPCookie(properties: properties)
        }
        guard cookies.contains(where: { $0.name == "auth_token" }) else { return nil }
        return BrowserLogin(browser: browser, cookies: cookies)
    }

    private struct Row {
        let host: String
        let name: String
        let path: String
        let plain: String
        let encrypted: Data
        let expires: Int64
        let secure: Bool
        let httpOnly: Bool
    }

    private static func open(_ database: URL) -> OpaquePointer? {
        var handle: OpaquePointer?
        let uri = "file:\(database.path(percentEncoded: true))?immutable=1"
        guard sqlite3_open_v2(uri, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            return nil
        }
        return handle
    }

    private static func rows(in database: URL) -> [Row]? {
        guard let handle = open(database) else { return nil }
        defer { sqlite3_close(handle) }
        let sql = "SELECT host_key, name, path, value, encrypted_value, expires_utc, is_secure, is_httponly FROM cookies WHERE host_key LIKE '%x.com' OR host_key LIKE '%twitter.com'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        var rows: [Row] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let blob = sqlite3_column_blob(statement, 4)
            let length = Int(sqlite3_column_bytes(statement, 4))
            rows.append(Row(
                host: text(statement, 0),
                name: text(statement, 1),
                path: text(statement, 2),
                plain: text(statement, 3),
                encrypted: blob.map { Data(bytes: $0, count: length) } ?? Data(),
                expires: sqlite3_column_int64(statement, 5),
                secure: sqlite3_column_int(statement, 6) != 0,
                httpOnly: sqlite3_column_int(statement, 7) != 0
            ))
        }
        return rows
    }

    private static func meta(_ key: String, in database: URL) -> String? {
        guard let handle = open(database) else { return nil }
        defer { sqlite3_close(handle) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "SELECT value FROM meta WHERE key = '\(key)'", -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW ? text(statement, 0) : nil
    }

    private static func text(_ statement: OpaquePointer?, _ column: Int32) -> String {
        sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
    }

    private static func key(for browser: Browser) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: browser.service,
            kSecAttrAccount as String: browser.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let password = item as? Data else { return nil }
        var derived = Data(count: kCCKeySizeAES128)
        let salt = Data("saltysalt".utf8)
        let status = derived.withUnsafeMutableBytes { out in
            password.withUnsafeBytes { pass in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                         pass.baseAddress?.assumingMemoryBound(to: Int8.self), password.count,
                                         saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                                         CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 1003,
                                         out.baseAddress?.assumingMemoryBound(to: UInt8.self), kCCKeySizeAES128)
                }
            }
        }
        return status == kCCSuccess ? derived : nil
    }

    private static func decrypt(_ data: Data, key: Data, stripHash: Bool) -> String? {
        guard data.count > 3, data.prefix(3) == Data("v10".utf8) else { return nil }
        let payload = data.dropFirst(3)
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        var output = Data(count: payload.count + kCCBlockSizeAES128)
        var written = 0
        let capacity = output.count
        let status = output.withUnsafeMutableBytes { out in
            payload.withUnsafeBytes { input in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                keyBytes.baseAddress, key.count, ivBytes.baseAddress,
                                input.baseAddress, payload.count, out.baseAddress, capacity, &written)
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        var plain = output.prefix(written)
        if stripHash, plain.count >= 32 { plain = plain.dropFirst(32) }
        return String(data: plain, encoding: .utf8)
    }
}
