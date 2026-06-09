import Fluent
import FluentPostgresDriver
import Vapor

enum PostgresConfiguration {
    static func configure(_ app: Application) throws {
        if let databaseURL = Environment.get("DATABASE_URL") {
            try app.databases.use(.postgres(url: databaseURL), as: .psql)
            return
        }

        guard let hostname = Environment.get("POSTGRES_HOST") else {
            app.logger.warning("Postgres is not configured. Set DATABASE_URL or POSTGRES_HOST before handling App Store notifications")
            return
        }

        let port = Environment.get("POSTGRES_PORT").flatMap(Int.init) ?? SQLPostgresConfiguration.ianaPortNumber
        let username = Environment.get("POSTGRES_USERNAME") ?? "vapor_username"
        let password = Environment.get("POSTGRES_PASSWORD") ?? "vapor_password"
        let database = Environment.get("POSTGRES_DATABASE") ?? "vapor_database"

        app.databases.use(.postgres(
            configuration: SQLPostgresConfiguration(
                hostname: hostname,
                port: port,
                username: username,
                password: password,
                database: database,
                tls: .disable
            ),
            encodingContext: .default
        ), as: .psql)
    }
}
