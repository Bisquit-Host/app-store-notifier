import Fluent
import Vapor

final class AppStoreNotificationEvent: Model, Content, @unchecked Sendable {
    static let schema = "app_store_notification_events"

    @ID(key: .id)
    var id: UUID?

    @OptionalField(key: "notification_uuid")
    var notificationUUID: String?

    @Field(key: "verification_status")
    var verificationStatus: String

    @OptionalField(key: "verification_error")
    var verificationError: String?

    @OptionalField(key: "notification_type")
    var notificationType: String?

    @OptionalField(key: "subtype")
    var subtype: String?

    @OptionalField(key: "version")
    var version: String?

    @OptionalField(key: "environment")
    var environment: String?

    @OptionalField(key: "app_apple_id")
    var appAppleId: Int64?

    @OptionalField(key: "bundle_id")
    var bundleId: String?

    @OptionalField(key: "signed_date")
    var signedDate: Date?

    @OptionalField(key: "transaction_id")
    var transactionId: String?

    @OptionalField(key: "original_transaction_id")
    var originalTransactionId: String?

    @OptionalField(key: "web_order_line_item_id")
    var webOrderLineItemId: String?

    @OptionalField(key: "product_id")
    var productId: String?

    @OptionalField(key: "subscription_group_identifier")
    var subscriptionGroupIdentifier: String?

    @OptionalField(key: "purchase_date")
    var purchaseDate: Date?

    @OptionalField(key: "expires_date")
    var expiresDate: Date?

    @OptionalField(key: "renewal_date")
    var renewalDate: Date?

    @OptionalField(key: "raw_signed_payload")
    var rawSignedPayload: String?

    @OptionalField(key: "decoded_payload")
    var decodedPayload: String?

    @OptionalField(key: "decoded_transaction")
    var decodedTransaction: String?

    @OptionalField(key: "decoded_renewal_info")
    var decodedRenewalInfo: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        notificationUUID: String? = nil,
        verificationStatus: String,
        verificationError: String? = nil,
        rawSignedPayload: String? = nil
    ) {
        self.notificationUUID = notificationUUID
        self.verificationStatus = verificationStatus
        self.verificationError = verificationError
        self.rawSignedPayload = rawSignedPayload
    }
}
