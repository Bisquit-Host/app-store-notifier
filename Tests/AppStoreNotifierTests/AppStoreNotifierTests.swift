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

    @Test("Individual event read endpoint is unavailable")
    func individualEventReadEndpointIsUnavailable() async throws {
        try await withApp(configure: { app in
            try app.register(collection: AppStoreNotificationController())
        }) { app in
            try await app.testing().test(.GET, "/app-store/notifications/events/00000000-0000-0000-0000-000000000123", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test("Event reads reject missing and incorrect credentials", arguments: [
        "", "Bearer wrong-token", "Basic test-token"
    ])
    func eventReadsRejectInvalidCredentials(authorization: String) async throws {
        try await withApp(configure: { app in
            try app.register(collection: AppStoreNotificationEventController(token: "test-token"))
        }) { app in
            try await app.testing().test(.GET, "/app-store/notifications/events", headers: ["Authorization": authorization], afterResponse: { res async in
                #expect(res.status == .unauthorized)
                #expect(res.headers.first(name: "WWW-Authenticate") == "Bearer")
            })
        }
    }

    @Test("Event reads fail closed without a configured token", arguments: [nil, "", "  "] as [String?])
    func eventReadsRequireConfiguredToken(token: String?) async throws {
        try await withApp(configure: { app in
            try app.register(collection: AppStoreNotificationEventController(token: token))
        }) { app in
            try await app.testing().test(.GET, "/app-store/notifications/events", headers: ["Authorization": "Bearer test-token"], afterResponse: { res async in
                #expect(res.status == .serviceUnavailable)
            })
        }
    }

    @Test("Bearer token grants access and prevents caching")
    func validEventTokenGrantsAccess() async throws {
        try await withApp(configure: { app in
            app.grouped(EventReadTokenMiddleware(token: "test-token")).get("protected") { _ in
                "authorized"
            }
        }) { app in
            try await app.testing().test(.GET, "/protected", headers: ["Authorization": "Bearer test-token"], afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "authorized")
                #expect(res.headers.first(name: .cacheControl) == "no-store")
            })
        }
    }

    @Test("Authenticated event reads validate pagination before querying", arguments: [
        "page=0", "page=-1", "per=0", "per=251", "page=abc", "page=9223372036854775807"
    ])
    func eventReadsValidatePagination(query: String) async throws {
        try await withApp(configure: { app in
            try app.register(collection: AppStoreNotificationEventController(token: "test-token"))
        }) { app in
            try await app.testing().test(.GET, "/app-store/notifications/events?\(query)", headers: ["Authorization": "Bearer test-token"], afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test("Event responses include delivery diagnostics and omit raw payloads")
    func eventResponsesRedactPayloads() throws {
        let event = AppStoreNotificationEvent(verificationStatus: "valid", rawSignedPayload: "signed-secret")
        event.decodedPayload = "decoded-secret"
        event.decodedTransaction = "transaction-secret"
        event.decodedRenewalInfo = "renewal-secret"
        event.mailStatus = "failed"
        event.mailError = "SMTP connection failed"
        let data = try JSONEncoder().encode(AppStoreNotificationEventResponse(event: event))
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("signed-secret"))
        #expect(!json.contains("decoded-secret"))
        #expect(!json.contains("transaction-secret"))
        #expect(!json.contains("renewal-secret"))
        #expect(json.contains("SMTP connection failed"))
        #expect(json.contains("failed"))
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
