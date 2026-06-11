import Vapor

struct MailerConfiguration: Sendable {
    let enabledEventTypes: Set<String>
    let fromAddress: String
    let fromName: String
    let recipients: [String]
    let transport: MailTransport

    static func load() -> MailerConfiguration? {
        guard
            let fromRaw = Environment.get("MAIL_FROM") ?? Environment.get("SMTP_USERNAME"),
            let recipientsRaw = Environment.get("MAIL_TO")
        else {
            return nil
        }

        let recipients = recipientsRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !recipients.isEmpty else {
            return nil
        }

        let enabledEventTypes = Environment.get("MAIL_EVENT_TYPES")
            .map(Self.eventTypes(from:)) ?? Self.defaultEventTypes

        return MailerConfiguration(
            enabledEventTypes: enabledEventTypes,
            fromAddress: fromRaw,
            fromName: Environment.get("SMTP_FROM_NAME") ?? "App Store Notifier",
            recipients: recipients,
            transport: MailTransport.load()
        )
    }

    private static let defaultEventTypes: Set<String> = [
        "CONSUMPTION_REQUEST",
        "DID_FAIL_TO_RENEW",
        "EXPIRED",
        "PRICE_INCREASE",
        "REFUND",
        "REFUND_DECLINED",
        "REVOKE"
    ]

    private static func eventTypes(from rawValue: String) -> Set<String> {
        Set(rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty })
    }
}

enum MailTransport: Sendable {
    case logOnly
    case smtp

    static func load() -> MailTransport {
        guard Environment.smtpConfigurationAvailable else {
            return .logOnly
        }

        return .smtp
    }
}
