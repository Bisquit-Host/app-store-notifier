import Fluent

struct CreateAppStoreNotificationEvent: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(AppStoreNotificationEvent.schema)
            .id()
            .field("notification_uuid", .string)
            .field("verification_status", .string, .required)
            .field("verification_error", .string)
            .field("notification_type", .string)
            .field("subtype", .string)
            .field("version", .string)
            .field("environment", .string)
            .field("app_apple_id", .int64)
            .field("bundle_id", .string)
            .field("signed_date", .datetime)
            .field("transaction_id", .string)
            .field("original_transaction_id", .string)
            .field("web_order_line_item_id", .string)
            .field("product_id", .string)
            .field("subscription_group_identifier", .string)
            .field("purchase_date", .datetime)
            .field("expires_date", .datetime)
            .field("renewal_date", .datetime)
            .field("raw_signed_payload", .string)
            .field("decoded_payload", .string)
            .field("decoded_transaction", .string)
            .field("decoded_renewal_info", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "notification_uuid")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(AppStoreNotificationEvent.schema).delete()
    }
}
