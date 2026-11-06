import Vapor
import Fluent
import AppStoreServerLibrary
import Smtp

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    try PostgresConfiguration.configure(app)
    let mailerConfiguration = MailerConfiguration.load()
    let mailer = EventMailer(configuration: mailerConfiguration)
    if let smtpConfiguration = try Environment.smtpConfiguration() {
        app.smtp.configuration = smtpConfiguration
    }
    app.asyncCommands.use(TestEmailCommand(mailer: mailer), as: "test-email")
    app.asyncCommands.use(RequestAppleTestNotificationCommand(), as: "request-test-notification")
    app.asyncCommands.use(AppleTestNotificationStatusCommand(), as: "test-notification-status")
    app.migrations.add(CreateAppStoreNotificationEvent())
    app.migrations.add(AddMailDeliveryState())
    app.migrations.add(AddPurchaseAccountContext())

    if
        let productionConfiguration = try AppleNotificationsConfiguration.load(environment: .production),
        let sandboxConfiguration = try AppleNotificationsConfiguration.load(environment: .sandbox)
    {
        app.appStoreNotificationServices = try AppStoreNotificationServices(
            production: AppStoreNotificationService(
                configuration: productionConfiguration,
                mailer: mailer
            ),
            sandbox: AppStoreNotificationService(
                configuration: sandboxConfiguration,
                mailer: mailer
            )
        )
        app.logger.info("App Store notification handling configured", metadata: [
            "event_name": "app_store_notification_startup",
            "mail_event_types": .string(mailerConfiguration?.eventTypeSummary ?? "disabled"),
            "mail_recipient_count": .stringConvertible(mailerConfiguration?.recipients.count ?? 0),
            "mail_transport": .string(mailerConfiguration?.transport.name ?? "disabled"),
            "outcome": "configured",
            "service": "app-store-notifier"
        ])
    } else {
        app.logger.warning("App Store notification handling is disabled because APPLE_BUNDLE_ID is not configured", metadata: [
            "event_name": "app_store_notification_startup",
            "outcome": "disabled",
            "service": "app-store-notifier"
        ])
    }

    // register routes
    try routes(app)
    try app.register(collection: AppStoreNotificationController())
    try app.register(collection: AppStoreNotificationEventController())
}
