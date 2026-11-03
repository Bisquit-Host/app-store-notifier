@testable import AppStoreNotifier
import VaporTesting
import Testing

@Suite("App Tests")
struct AppStoreNotifierTests {
    @Test("Test Hello World Route")
    func helloWorld() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "hello", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Hello, world!")
            })
        }
    }

    @Test("Mail event types default to all")
    func mailEventTypesDefaultToAll() {
        let configuration = MailerConfiguration(
            enabledEventTypes: nil,
            fromAddress: "sender@example.com",
            fromName: "App Store",
            recipients: ["recipient@example.com"],
            transport: .logOnly
        )

        #expect(configuration.allows(notificationType: "TEST"))
        #expect(configuration.allows(notificationType: "DID_RENEW"))
    }

    @Test("Mail event type allowlist is respected")
    func mailEventTypeAllowlist() {
        let configuration = MailerConfiguration(
            enabledEventTypes: MailerConfiguration.eventTypes(from: "refund, revoke"),
            fromAddress: "sender@example.com",
            fromName: "App Store",
            recipients: ["recipient@example.com"],
            transport: .logOnly
        )

        #expect(configuration.allows(notificationType: "REFUND"))
        #expect(!configuration.allows(notificationType: "DID_RENEW"))
    }

    @Test("Wildcard mail event type means all")
    func wildcardMailEventType() {
        #expect(MailerConfiguration.eventTypes(from: "*") == nil)
    }

    @Test("Only pending and failed mail deliveries retry")
    func mailDeliveryRetries() {
        #expect(EventMailDeliveryStatus.pending.shouldRetry)
        #expect(EventMailDeliveryStatus.failed.shouldRetry)
        #expect(!EventMailDeliveryStatus.sent.shouldRetry)
        #expect(!EventMailDeliveryStatus.filtered.shouldRetry)
    }

    @Test("Event read endpoints are unavailable", arguments: [
        "/app-store/notifications/events",
        "/app-store/notifications/events/00000000-0000-0000-0000-000000000123"
    ])
    func eventReadEndpointsAreUnavailable(path: String) async throws {
        try await withApp(configure: { app in
            try app.register(collection: AppStoreNotificationController())
        }) { app in
            try await app.testing().test(.GET, path, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test("Mail includes purchase account context")
    func mailIncludesPurchaseAccountContext() {
        let token = UUID(uuidString: "00000000-0000-0000-0000-000000000123")
        let event = AppStoreNotificationEvent(verificationStatus: "valid")
        event.appAccountToken = token
        event.consumptionRequestReason = "UNINTENDED_PURCHASE"

        let body = EventMailer(configuration: nil).body(for: event)

        #expect(!body.contains("App account token:"))
        #expect(!body.contains("00000000-0000-0000-0000-000000000123"))
        #expect(body.contains("Billing user ID: 123"))
        #expect(body.contains("Consumption request reason: UNINTENDED_PURCHASE"))
    }

    @Test("Billing user IDs round trip through App Store account tokens")
    func billingUserIdRoundTrip() {
        let token = BillingAppAccountToken.token(for: 123)

        #expect(token?.uuidString.lowercased() == "00000000-0000-0000-0000-000000000123")
        #expect(BillingAppAccountToken.userID(from: token) == 123)
        #expect(BillingAppAccountToken.token(for: 0) == nil)
        #expect(BillingAppAccountToken.userID(from: UUID()) == nil)
    }
}
