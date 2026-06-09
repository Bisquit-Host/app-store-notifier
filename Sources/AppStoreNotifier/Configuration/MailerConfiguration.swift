import Vapor

struct MailerConfiguration: Sendable {
    let enabledEventTypes: Set<String>
    let from: EmailAddress
    let recipients: [EmailAddress]
    let transport: MailTransport

    static func load() -> MailerConfiguration? {
        guard
            let fromRaw = Environment.get("MAIL_FROM"),
            let recipientsRaw = Environment.get("MAIL_TO")
        else {
            return nil
        }

        let recipients = recipientsRaw
            .split(separator: ",")
            .map { EmailAddress($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.value.isEmpty }

        guard !recipients.isEmpty else {
            return nil
        }

        let enabledEventTypes = Environment.get("MAIL_EVENT_TYPES")
            .map(Self.eventTypes(from:)) ?? Self.defaultEventTypes

        return MailerConfiguration(
            enabledEventTypes: enabledEventTypes,
            from: EmailAddress(fromRaw),
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

struct EmailAddress: Sendable {
    let value: String

    init(_ value: String) {
        self.value = value
    }
}

enum MailTransport: Sendable {
    case logOnly
    case mailgun(apiKey: String, domain: String)

    static func load() -> MailTransport {
        guard
            Environment.get("MAILER_PROVIDER")?.lowercased() == "mailgun",
            let apiKey = Environment.get("MAILGUN_API_KEY"),
            let domain = Environment.get("MAILGUN_DOMAIN")
        else {
            return .logOnly
        }

        return .mailgun(apiKey: apiKey, domain: domain)
    }
}
