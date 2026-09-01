import Smtp
import Vapor

struct EventMailer: Sendable {
    private let configuration: MailerConfiguration?

    init(configuration: MailerConfiguration?) {
        self.configuration = configuration
    }

    func sendIfNeeded(for event: AppStoreNotificationEvent, on request: Request) async throws -> EventMailDeliveryStatus {
        guard let configuration else {
            return .disabled
        }

        guard let notificationType = event.notificationType,
              configuration.allows(notificationType: notificationType) else {
            return .filtered
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
            return .logged
        case .smtp:
            try await send(message, on: request.application)
            return .sent
        }
    }

    func sendTest(on application: Application) async throws -> Int {
        guard let configuration else {
            throw Abort(.serviceUnavailable, reason: "Mail is disabled because MAIL_TO or the sender address is missing")
        }

        guard configuration.transport == .smtp else {
            throw Abort(.serviceUnavailable, reason: "SMTP is not fully configured")
        }

        let message = EmailMessage(
            fromAddress: configuration.fromAddress,
            fromName: configuration.fromName,
            recipients: configuration.recipients,
            subject: "App Store Notifier test",
            text: "SMTP delivery from App Store Notifier is working"
        )
        try await send(message, on: application)
        return message.recipients.count
    }

    private func subject(for event: AppStoreNotificationEvent) -> String {
        let type = event.notificationType ?? "UNKNOWN"
        let product = event.productId.map { " \($0)" } ?? ""
        return "App Store \(type)\(product)"
    }

    func body(for event: AppStoreNotificationEvent) -> String {
        [
            "Notification type: \(event.notificationType ?? "unknown")",
            "Subtype: \(event.subtype ?? "none")",
            "Notification UUID: \(event.notificationUUID ?? "unknown")",
            "Environment: \(event.environment ?? "unknown")",
            "Bundle ID: \(event.bundleId ?? "unknown")",
            "Product ID: \(event.productId ?? "unknown")",
            "App account token: \(event.appAccountToken?.uuidString.lowercased() ?? "not provided")",
            "Billing user ID: \(BillingAppAccountToken.userID(from: event.appAccountToken).map(String.init) ?? "unknown")",
            "Consumption request reason: \(event.consumptionRequestReason ?? "none")",
            "Transaction ID: \(event.transactionId ?? "unknown")",
            "Original transaction ID: \(event.originalTransactionId ?? "unknown")",
            "Signed date: \(event.signedDate?.description ?? "unknown")"
        ].joined(separator: "\n")
    }

    private func send(_ message: EmailMessage, on application: Application) async throws {
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

        try await application.smtp.send(email)
    }
}

private struct EmailMessage: Sendable {
    let fromAddress: String
    let fromName: String
    let recipients: [String]
    let subject: String
    let text: String
}
