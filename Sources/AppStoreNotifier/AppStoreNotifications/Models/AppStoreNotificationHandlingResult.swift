struct AppStoreNotificationHandlingResult: Sendable {
    let event: AppStoreNotificationEvent
    let inserted: Bool
}
