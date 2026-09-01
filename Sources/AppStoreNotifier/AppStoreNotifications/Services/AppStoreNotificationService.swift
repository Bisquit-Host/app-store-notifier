import AppStoreServerLibrary
import Fluent
import Vapor

struct AppStoreNotificationService: Sendable {
    private let verifier: SignedDataVerifier
    private let mailer: EventMailer

    init(configuration: AppleNotificationsConfiguration, mailer: EventMailer) throws {
        self.verifier = try SignedDataVerifier(
            rootCertificates: configuration.rootCertificates,
            bundleId: configuration.bundleId,
            appAppleId: configuration.appAppleId,
            environment: configuration.environment,
            enableOnlineChecks: configuration.enableOnlineChecks
        )
        self.mailer = mailer
    }

    func handle(signedPayload: String, on request: Request) async throws -> AppStoreNotificationHandlingResult {
        let event = AppStoreNotificationEvent(
            verificationStatus: "pending",
            rawSignedPayload: signedPayload
        )

        let notification = try await verifyNotification(signedPayload, event: event, on: request)
        try await decodeTransaction(from: notification, into: event)
        try await decodeRenewalInfo(from: notification, into: event)

        if event.verificationStatus == "invalid" {
            _ = try await save(event, on: request.db)
            throw Abort(.unauthorized, reason: event.verificationError ?? "App Store notification verification failed")
        }

        event.verificationStatus = "valid"
        let (savedEvent, inserted) = try await save(event, on: request.db)

        let mailStatus = savedEvent.mailStatus.flatMap(EventMailDeliveryStatus.init(rawValue:)) ?? .pending
        if inserted || mailStatus.shouldRetry {
            try await deliverMail(for: savedEvent, on: request)
        }

        return AppStoreNotificationHandlingResult(event: savedEvent, inserted: inserted)
    }

    private func deliverMail(for event: AppStoreNotificationEvent, on request: Request) async throws {
        event.mailAttemptedAt = .now
        event.mailError = nil

        do {
            let status = try await mailer.sendIfNeeded(for: event, on: request)
            event.mailStatus = status.rawValue
            if status == .sent {
                event.mailSentAt = .now
            }
            try await event.update(on: request.db)
        } catch {
            event.mailStatus = EventMailDeliveryStatus.failed.rawValue
            event.mailError = ErrorMessageSanitizer.message(for: error)
            try await event.update(on: request.db)
            throw error
        }
    }

    private func verifyNotification(
        _ signedPayload: String,
        event: AppStoreNotificationEvent,
        on request: Request
    ) async throws -> ResponseBodyV2DecodedPayload {
        switch await verifier.verifyAndDecodeNotification(signedPayload: signedPayload) {
        case .valid(let notification):
            try populate(event, with: notification)
            return notification
        case .invalid(let error):
            event.verificationStatus = "invalid"
            event.verificationError = String(describing: error)
            _ = try await save(event, on: request.db)
            throw Abort(.unauthorized, reason: "App Store notification verification failed: \(error)")
        }
    }

    private func decodeTransaction(
        from notification: ResponseBodyV2DecodedPayload,
        into event: AppStoreNotificationEvent
    ) async throws {
        guard let signedTransactionInfo = notification.data?.signedTransactionInfo else {
            return
        }

        switch await verifier.verifyAndDecodeTransaction(signedTransaction: signedTransactionInfo) {
        case .valid(let transaction):
            event.transactionId = transaction.transactionId
            event.originalTransactionId = transaction.originalTransactionId
            event.webOrderLineItemId = transaction.webOrderLineItemId
            event.productId = transaction.productId
            event.appAccountToken = transaction.appAccountToken
            event.subscriptionGroupIdentifier = transaction.subscriptionGroupIdentifier
            event.purchaseDate = transaction.purchaseDate
            event.expiresDate = transaction.expiresDate
            event.decodedTransaction = try jsonString(from: transaction)
        case .invalid(let error):
            event.verificationStatus = "invalid"
            event.verificationError = "Transaction verification failed: \(error)"
        }
    }

    private func decodeRenewalInfo(
        from notification: ResponseBodyV2DecodedPayload,
        into event: AppStoreNotificationEvent
    ) async throws {
        guard let signedRenewalInfo = notification.data?.signedRenewalInfo else {
            return
        }

        switch await verifier.verifyAndDecodeRenewalInfo(signedRenewalInfo: signedRenewalInfo) {
        case .valid(let renewalInfo):
            event.renewalDate = renewalInfo.renewalDate
            event.appAccountToken = event.appAccountToken ?? renewalInfo.appAccountToken
            event.decodedRenewalInfo = try jsonString(from: renewalInfo)
        case .invalid(let error):
            event.verificationStatus = "invalid"
            event.verificationError = "Renewal info verification failed: \(error)"
        }
    }

    private func populate(_ event: AppStoreNotificationEvent, with notification: ResponseBodyV2DecodedPayload) throws {
        event.notificationUUID = notification.notificationUUID
        event.notificationType = notification.rawNotificationType
        event.subtype = notification.rawSubtype
        event.version = notification.version
        event.signedDate = notification.signedDate
        event.decodedPayload = try jsonString(from: notification)

        if let data = notification.data {
            event.environment = data.rawEnvironment
            event.appAppleId = data.appAppleId
            event.bundleId = data.bundleId
            event.consumptionRequestReason = data.rawConsumptionRequestReason
            return
        }

        if let summary = notification.summary {
            event.environment = summary.environment?.rawValue
            event.appAppleId = summary.appAppleId
            event.bundleId = summary.bundleId
            return
        }

        if let externalPurchaseToken = notification.externalPurchaseToken {
            event.appAppleId = externalPurchaseToken.appAppleId
            event.bundleId = externalPurchaseToken.bundleId
            event.environment = externalPurchaseToken.externalPurchaseId?.starts(with: "SANDBOX") == true ? "Sandbox" : "Production"
            return
        }

        if let appData = notification.appData {
            event.environment = appData.environment?.rawValue
            event.appAppleId = appData.appAppleId
            event.bundleId = appData.bundleId
        }
    }

    private func save(_ event: AppStoreNotificationEvent, on database: any Database) async throws -> (AppStoreNotificationEvent, Bool) {
        if let notificationUUID = event.notificationUUID,
           let existing = try await AppStoreNotificationEvent.query(on: database)
            .filter(\.$notificationUUID == notificationUUID)
            .first() {
            return (existing, false)
        }

        try await event.save(on: database)
        return (event, true)
    }

    private func jsonString<T: Encodable>(from value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
