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

        let port = try getInt("SMTP_PORT")
        return SmtpServerConfiguration(
            hostname: try getString("SMTP_HOSTNAME"),
            port: port,
            signInMethod: .credentials(
                username: try getString("SMTP_USERNAME"),
                password: try getString("SMTP_PASSWORD")
            ),
            secure: try smtpSecureChannel(port: port),
            helloMethod: .ehlo
        )
    }

    private static func smtpSecureChannel(port: Int) throws -> SmtpSecureChannel {
        let defaultSecurity = switch port {
        case 465: "ssl"
        case 587: "starttls"
        default: "none"
        }

        switch Environment.get("SMTP_SECURITY")?.lowercased() ?? defaultSecurity {
        case "none":
            return .none
        case "ssl", "tls":
            return .ssl
        case "starttls":
            return .startTls
        case "starttls-when-available", "opportunistic":
            return .startTlsWhenAvailable
        default:
            throw Abort(
                .internalServerError,
                reason: "SMTP_SECURITY must be none, ssl, starttls, or starttls-when-available"
            )
        }
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
