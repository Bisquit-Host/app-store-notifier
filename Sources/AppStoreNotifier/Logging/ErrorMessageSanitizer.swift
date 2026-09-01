import Vapor

enum ErrorMessageSanitizer {
    static func message(for error: any Error) -> String {
        var message = String(describing: error)

        for variableName in secretEnvironmentVariableNames {
            guard let secret = Environment.get(variableName), !secret.isEmpty else {
                continue
            }

            message = message.replacing(secret, with: "[REDACTED]")
        }

        return String(message.prefix(1_000))
    }

    private static let secretEnvironmentVariableNames = [
        "DATABASE_URL",
        "POSTGRES_PASSWORD",
        "SMTP_PASSWORD"
    ]
}
