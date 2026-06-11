import Smtp
import Vapor

extension Environment {
    static var smtpConfigurationAvailable: Bool {
        Environment.get("SMTP_HOSTNAME") != nil &&
            Environment.get("SMTP_USERNAME") != nil &&
            Environment.get("SMTP_PASSWORD") != nil &&
            Environment.get("SMTP_PORT") != nil
    }

    static func smtpConfiguration() throws -> SmtpServerConfiguration? {
        guard smtpConfigurationAvailable else {
            return nil
        }

        return SmtpServerConfiguration(
            hostname: try getString("SMTP_HOSTNAME"),
            port: try getInt("SMTP_PORT"),
            signInMethod: .credentials(
                username: try getString("SMTP_USERNAME"),
                password: try getString("SMTP_PASSWORD")
            ),
            helloMethod: .ehlo
        )
    }

    static func getString(_ name: String) throws -> String {
        guard let variable = get(name) else {
            throw Abort(.internalServerError, reason: "Environment variable not set \(name)")
        }

        return variable
    }

    static func getInt(_ name: String) throws -> Int {
        guard let variable = get(name).flatMap(Int.init) else {
            throw Abort(.internalServerError, reason: "Environment variable not set \(name)")
        }

        return variable
    }
}
