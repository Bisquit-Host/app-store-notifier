import Smtp
import Vapor

struct EventMailer: Sendable {
    private let configuration: MailerConfiguration?

    init(configuration: MailerConfiguration?) {
        self.configuration = configuration
    }

    func sendIfNeeded(for event: AppStoreNotificationEvent, on request: Request) async throws {
        guard
            let configuration,
            let notificationType = event.notificationType,
            configuration.enabledEventTypes.contains(notificationType)
        else {
            return
        }

        let message = EmailMessage(
            fromAddress: configuration.fromAddress,
            fromName: configuration.fromName,
            recipients: configuration.recipients,
            subject: subject(for: event),
            text: body(for: event)
        )

        switch configuration.transport {
        case .logOnly:
            request.logger.info("App Store notification email", metadata: [
                "notificationType": .string(notificationType),
                "notificationUUID": .string(event.notificationUUID ?? "unknown"),
                "subject": .string(message.subject)
            ])
        case .smtp:
            try await send(message, on: request)
        }
    }

    private func subject(for event: AppStoreNotificationEvent) -> String {
        let type = event.notificationType ?? "UNKNOWN"
        let product = event.productId.map { " \($0)" } ?? ""
        return "App Store \(type)\(product)"
    }

    private func body(for event: AppStoreNotificationEvent) -> String {
        [
            "Notification type: \(event.notificationType ?? "unknown")",
            "Subtype: \(event.subtype ?? "none")",
            "Notification UUID: \(event.notificationUUID ?? "unknown")",
            "Environment: \(event.environment ?? "unknown")",
            "Bundle ID: \(event.bundleId ?? "unknown")",
            "Product ID: \(event.productId ?? "unknown")",
            "Transaction ID: \(event.transactionId ?? "unknown")",
            "Original transaction ID: \(event.originalTransactionId ?? "unknown")",
            "Signed date: \(event.signedDate?.description ?? "unknown")"
        ].joined(separator: "\n")
    }

    private func send(_ message: EmailMessage, on request: Request) async throws {
        let email = try Email(
            from: EmailAddress(
                address: message.fromAddress,
                name: MailHeaderEncoder.encode(message.fromName)
            ),
            to: message.recipients.map { EmailAddress(address: $0) },
            subject: MailHeaderEncoder.encode(message.subject),
            body: message.text,
            isBodyHtml: false
        )

        try await request.send(email) { result in
            request.logger.info("Email sending result: \(result)")
        }
    }
}

private struct EmailMessage: Sendable {
    let fromAddress: String
    let fromName: String
    let recipients: [String]
    let subject: String
    let text: String
}
