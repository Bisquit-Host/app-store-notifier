import Vapor

struct AppStoreNotificationController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let notifications = routes.grouped("app-store", "notifications")
        notifications.post("production", use: receiveProduction)
        notifications.post("sandbox", use: receiveSandbox)
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
}
