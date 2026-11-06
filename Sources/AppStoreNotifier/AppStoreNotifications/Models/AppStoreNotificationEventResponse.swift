import Vapor

struct AppStoreNotificationEventResponse: Content {
    let id: UUID?
    let notificationUUID: String?
    let verificationStatus: String
    let verificationError: String?
    let notificationType: String?
    let subtype: String?
    let version: String?
    let environment: String?
    let appAppleId: Int64?
    let bundleId: String?
    let signedDate: Date?
    let transactionId: String?
    let originalTransactionId: String?
    let webOrderLineItemId: String?
    let productId: String?
    let subscriptionGroupIdentifier: String?
    let appAccountToken: UUID?
    let billingUserId: Int64?
    let consumptionRequestReason: String?
    let purchaseDate: Date?
    let expiresDate: Date?
    let renewalDate: Date?
    let mailStatus: String?
    let mailError: String?
    let mailAttemptedAt: Date?
    let mailSentAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    init(event: AppStoreNotificationEvent) {
        id = event.id
        notificationUUID = event.notificationUUID
        verificationStatus = event.verificationStatus
        verificationError = event.verificationError
        notificationType = event.notificationType
        subtype = event.subtype
        version = event.version
        environment = event.environment
        appAppleId = event.appAppleId
        bundleId = event.bundleId
        signedDate = event.signedDate
        transactionId = event.transactionId
        originalTransactionId = event.originalTransactionId
        webOrderLineItemId = event.webOrderLineItemId
        productId = event.productId
        subscriptionGroupIdentifier = event.subscriptionGroupIdentifier
        appAccountToken = event.appAccountToken
        billingUserId = BillingAppAccountToken.userID(from: event.appAccountToken)
        consumptionRequestReason = event.consumptionRequestReason
        purchaseDate = event.purchaseDate
        expiresDate = event.expiresDate
        renewalDate = event.renewalDate
        mailStatus = event.mailStatus
        mailError = event.mailError
        mailAttemptedAt = event.mailAttemptedAt
        mailSentAt = event.mailSentAt
        createdAt = event.createdAt
        updatedAt = event.updatedAt
    }
}
