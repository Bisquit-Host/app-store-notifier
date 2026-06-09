import Vapor
import Fluent
import AppStoreServerLibrary

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    try PostgresConfiguration.configure(app)
    app.migrations.add(CreateAppStoreNotificationEvent())

    if
        let productionConfiguration = try AppleNotificationsConfiguration.load(environment: .production),
        let sandboxConfiguration = try AppleNotificationsConfiguration.load(environment: .sandbox)
    {
        let mailer = EventMailer(configuration: MailerConfiguration.load())
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
    }

    // register routes
    try routes(app)
    try app.register(collection: AppStoreNotificationController())
}
