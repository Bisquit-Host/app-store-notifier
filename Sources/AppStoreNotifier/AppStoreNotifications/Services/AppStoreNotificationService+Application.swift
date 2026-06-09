import Vapor

struct AppStoreNotificationServices: Sendable {
    let production: AppStoreNotificationService
    let sandbox: AppStoreNotificationService
}

private struct AppStoreNotificationServicesKey: StorageKey {
    typealias Value = AppStoreNotificationServices
}

extension Application {
    var appStoreNotificationServices: AppStoreNotificationServices? {
        get {
            storage[AppStoreNotificationServicesKey.self]
        }
        set {
            storage[AppStoreNotificationServicesKey.self] = newValue
        }
    }
}

extension Request {
    var appStoreNotificationServices: AppStoreNotificationServices {
        get throws {
            guard let services = application.appStoreNotificationServices else {
                throw Abort(.serviceUnavailable, reason: "App Store notification handling is not configured")
            }

            return services
        }
    }
}
