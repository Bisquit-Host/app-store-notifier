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
            from: configuration.from,
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
        case .mailgun(let apiKey, let domain):
            try await send(message, apiKey: apiKey, domain: domain, on: request)
        }
    }

    private func send(_ message: EmailMessage, apiKey: String, domain: String, on request: Request) async throws {
        var headers = HTTPHeaders()
        headers.basicAuthorization = BasicAuthorization(username: "api", password: apiKey)

        let response = try await request.client.post(URI(string: "https://api.mailgun.net/v3/\(domain)/messages"), headers: headers) { clientRequest in
            try clientRequest.content.encode(MailgunMessage(
                from: message.from.value,
                to: message.recipients.map(\.value).joined(separator: ","),
                subject: message.subject,
                text: message.text
            ), as: .urlEncodedForm)
        }

        guard response.status.code >= 200 && response.status.code < 300 else {
            throw Abort(.badGateway, reason: "Mailgun rejected App Store notification email with status \(response.status.code)")
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
}

private struct EmailMessage: Sendable {
    let from: EmailAddress
    let recipients: [EmailAddress]
    let subject: String
    let text: String
}

private struct MailgunMessage: Content {
    let from: String
    let to: String
    let subject: String
    let text: String
}
