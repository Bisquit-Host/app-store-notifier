import AppStoreServerLibrary
import Vapor

enum AppStoreServerAPIConfiguration {
    static func client(environment: AppStoreEnvironment) throws -> AppStoreServerAPIClient {
        let privateKeyPath = try Environment.getString("APPLE_IAP_PRIVATE_KEY_PATH")
        let signingKey = try String(contentsOf: URL(filePath: privateKeyPath), encoding: .utf8)

        return try AppStoreServerAPIClient(
            signingKey: signingKey,
            keyId: try Environment.getString("APPLE_IAP_KEY_ID"),
            issuerId: try Environment.getString("APPLE_IAP_ISSUER_ID"),
            bundleId: try Environment.getString("APPLE_BUNDLE_ID"),
            environment: environment
        )
    }

    static func environment(from value: String?) throws -> AppStoreEnvironment {
        switch value?.lowercased() ?? "sandbox" {
        case "sandbox":
            return .sandbox
        case "production":
            return .production
        default:
            throw Abort(.badRequest, reason: "Environment must be sandbox or production")
        }
    }
}
