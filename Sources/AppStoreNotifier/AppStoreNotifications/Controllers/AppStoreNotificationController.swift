import Fluent
import Vapor

struct AppStoreNotificationController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let notifications = routes.grouped("app-store", "notifications")
        notifications.post("production", use: receiveProduction)
        notifications.post("sandbox", use: receiveSandbox)
        notifications.get("events", use: listEvents)
        notifications.get("events", ":notificationUUID", use: getEvent)
    }

    private func receiveProduction(request: Request) async throws -> HTTPStatus {
        try await receive(
            environment: "production",
            service: request.appStoreNotificationServices.production,
            request: request
        )
    }

    private func receiveSandbox(request: Request) async throws -> HTTPStatus {
        try await receive(
            environment: "sandbox",
            service: request.appStoreNotificationServices.sandbox,
            request: request
        )
    }

    private func receive(
        environment: String,
        service: AppStoreNotificationService,
        request: Request
    ) async throws -> HTTPStatus {
        let start = ContinuousClock.now

        do {
            let payload = try request.content.decode(AppStoreNotificationPayload.self)
            let result = try await service.handle(signedPayload: payload.signedPayload, on: request)
            var metadata = baseMetadata(environment: environment, request: request, start: start)
            metadata["bundle_id"] = .string(result.event.bundleId ?? "unknown")
            metadata["duplicate"] = .stringConvertible(!result.inserted)
            metadata["mail_status"] = .string(result.event.mailStatus ?? "unknown")
            metadata["notification_type"] = .string(result.event.notificationType ?? "unknown")
            metadata["notification_uuid"] = .string(result.event.notificationUUID ?? "unknown")
            metadata["outcome"] = "success"
            metadata["product_id"] = .string(result.event.productId ?? "unknown")
            metadata["status_code"] = .stringConvertible(HTTPStatus.ok.code)
            metadata["subtype"] = .string(result.event.subtype ?? "none")
            metadata["transaction_id"] = .string(result.event.transactionId ?? "unknown")
            request.logger.info("App Store notification processed", metadata: metadata)
            return .ok
        } catch {
            var metadata = baseMetadata(environment: environment, request: request, start: start)
            let status = (error as? any AbortError)?.status ?? .internalServerError
            metadata["error_message_sanitized"] = .string(ErrorMessageSanitizer.message(for: error))
            metadata["error_type"] = .string(String(reflecting: type(of: error)))
            metadata["outcome"] = "error"
            metadata["status_code"] = .stringConvertible(status.code)
            request.logger.error("App Store notification failed", metadata: metadata)
            throw error
        }
    }

    private func baseMetadata(
        environment: String,
        request: Request,
        start: ContinuousClock.Instant
    ) -> Logger.Metadata {
        let duration = start.duration(to: .now).components
        let durationMilliseconds = duration.seconds * 1_000 + duration.attoseconds / 1_000_000_000_000_000

        return [
            "app_store_environment": .string(environment),
            "deployment_environment": .string(request.application.environment.name),
            "duration_ms": .stringConvertible(durationMilliseconds),
            "event_name": "app_store_notification_request",
            "http_method": .string(request.method.rawValue),
            "operation": "receive_app_store_notification",
            "request_id": .string(request.id),
            "route": .string(request.route?.description ?? request.url.path),
            "service": "app-store-notifier"
        ]
    }

    private func listEvents(request: Request) async throws -> [AppStoreNotificationEventResponse] {
        let limit = min(max(request.query[Int.self, at: "limit"] ?? 100, 1), 250)
        var query = AppStoreNotificationEvent.query(on: request.db)

        if let notificationType = request.query[String.self, at: "type"] {
            query = query.filter(\.$notificationType == notificationType)
        }

        if let productId = request.query[String.self, at: "productId"] {
            query = query.filter(\.$productId == productId)
        }

        if let token = request.query[String.self, at: "appAccountToken"] {
            guard let appAccountToken = UUID(uuidString: token) else {
                throw Abort(.badRequest, reason: "appAccountToken must be a UUID")
            }
            query = query.filter(\.$appAccountToken == appAccountToken)
        }

        if let environment = request.query[String.self, at: "environment"] {
            query = query.filter(\.$environment == environment)
        }

        if let verificationStatus = request.query[String.self, at: "verificationStatus"] {
            query = query.filter(\.$verificationStatus == verificationStatus)
        }

        if let mailStatus = request.query[String.self, at: "mailStatus"] {
            query = query.filter(\.$mailStatus == mailStatus)
        }

        if let transactionId = request.query[String.self, at: "transactionId"] {
            query = query.group(.or) {
                $0.filter(\.$transactionId == transactionId)
                $0.filter(\.$originalTransactionId == transactionId)
            }
        }

        return try await query
            .sort(\.$createdAt, .descending)
            .limit(limit)
            .all()
            .map(AppStoreNotificationEventResponse.init(event:))
    }

    private func getEvent(request: Request) async throws -> AppStoreNotificationEventResponse {
        guard let notificationUUID = request.parameters.get("notificationUUID") else {
            throw Abort(.badRequest, reason: "Missing notification UUID")
        }

        guard let event = try await AppStoreNotificationEvent.query(on: request.db)
            .filter(\.$notificationUUID == notificationUUID)
            .first()
        else {
            throw Abort(.notFound)
        }

        return AppStoreNotificationEventResponse(event: event)
    }
}
