import Fluent

struct AddMailDeliveryState: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(AppStoreNotificationEvent.schema)
            .field("mail_status", .string)
            .field("mail_error", .string)
            .field("mail_attempted_at", .datetime)
            .field("mail_sent_at", .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(AppStoreNotificationEvent.schema)
            .deleteField("mail_status")
            .deleteField("mail_error")
            .deleteField("mail_attempted_at")
            .deleteField("mail_sent_at")
            .update()
    }
}
