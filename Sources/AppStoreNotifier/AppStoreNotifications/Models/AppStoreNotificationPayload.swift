import Vapor

struct AppStoreNotificationPayload: Content {
    let signedPayload: String
}
