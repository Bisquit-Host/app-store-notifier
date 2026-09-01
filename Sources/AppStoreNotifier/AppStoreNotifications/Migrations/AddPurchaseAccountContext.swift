import Fluent

struct AddPurchaseAccountContext: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(AppStoreNotificationEvent.schema)
            .field("app_account_token", .uuid)
            .field("consumption_request_reason", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(AppStoreNotificationEvent.schema)
            .deleteField("app_account_token")
            .deleteField("consumption_request_reason")
            .update()
    }
}
