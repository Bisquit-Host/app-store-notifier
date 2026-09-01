import Vapor

struct MailerConfiguration: Sendable {
    let enabledEventTypes: Set<String>?
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
            .flatMap(Self.eventTypes(from:))

        return MailerConfiguration(
            enabledEventTypes: enabledEventTypes,
            fromAddress: fromRaw,
            fromName: Environment.get("SMTP_FROM_NAME") ?? "App Store Notifier",
            recipients: recipients,
            transport: MailTransport.load()
        )
    }

    func allows(notificationType: String) -> Bool {
        enabledEventTypes?.contains(notificationType) ?? true
    }

    var eventTypeSummary: String {
        enabledEventTypes?.sorted().joined(separator: ",") ?? "all"
    }

    static func eventTypes(from rawValue: String) -> Set<String>? {
        let eventTypes = Set(rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty })

        return eventTypes.contains("*") ? nil : eventTypes
    }
}

enum MailTransport: Sendable, Equatable {
    case logOnly
    case smtp

    static func load() -> MailTransport {
        guard Environment.smtpConfigurationAvailable else {
            return .logOnly
        }

        return .smtp
    }

    var name: String {
        switch self {
        case .logOnly: "log_only"
        case .smtp: "smtp"
        }
    }
}
