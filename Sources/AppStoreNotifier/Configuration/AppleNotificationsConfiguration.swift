import AppStoreServerLibrary
import Vapor

struct AppleNotificationsConfiguration: Sendable {
    let bundleId: String
    let appAppleId: Int64?
    let environment: AppStoreEnvironment
    let enableOnlineChecks: Bool
    let rootCertificates: [Data]

    static func load(environment appStoreEnvironment: AppStoreEnvironment) throws -> AppleNotificationsConfiguration? {
        guard let bundleId = Environment.get("APPLE_BUNDLE_ID") else {
            return nil
        }

        let appAppleId = Environment.get("APPLE_APP_APPLE_ID").flatMap(Int64.init)
        let enableOnlineChecks = Environment.get("APPLE_ENABLE_ONLINE_CHECKS").flatMap(Bool.init) ?? true
        let certificates = try rootCertificates(from: Environment.get("APPLE_ROOT_CERTIFICATE_PATHS")) ?? bundledRootCertificates()
        guard !certificates.isEmpty else {
            throw Abort(.internalServerError, reason: "At least one Apple root certificate must be bundled or configured with APPLE_ROOT_CERTIFICATE_PATHS")
        }

        return AppleNotificationsConfiguration(
            bundleId: bundleId,
            appAppleId: appAppleId,
            environment: appStoreEnvironment,
            enableOnlineChecks: enableOnlineChecks,
            rootCertificates: certificates
        )
    }

    private static func rootCertificates(from rawValue: String?) throws -> [Data]? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        return try rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { try Data(contentsOf: URL(fileURLWithPath: $0)) }
    }

    private static func bundledRootCertificates() throws -> [Data] {
        let url = Bundle.module.url(forResource: "AppleRootCA-G3", withExtension: "cer")
            ?? Bundle.module.url(forResource: "AppleRootCA-G3", withExtension: "cer", subdirectory: "Certificates")
        guard let url else {
            return []
        }

        return [try Data(contentsOf: url)]
    }
}
