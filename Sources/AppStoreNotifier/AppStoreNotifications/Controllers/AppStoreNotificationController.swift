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
        let payload = try request.content.decode(AppStoreNotificationPayload.self)
        _ = try await request.appStoreNotificationServices.production.handle(signedPayload: payload.signedPayload, on: request)
        return .ok
    }

    private func receiveSandbox(request: Request) async throws -> HTTPStatus {
        let payload = try request.content.decode(AppStoreNotificationPayload.self)
        _ = try await request.appStoreNotificationServices.sandbox.handle(signedPayload: payload.signedPayload, on: request)
        return .ok
    }

    private func listEvents(request: Request) async throws -> [AppStoreNotificationEvent] {
        let limit = min(request.query[Int.self, at: "limit"] ?? 100, 250)
        var query = AppStoreNotificationEvent.query(on: request.db)

        if let notificationType = request.query[String.self, at: "type"] {
            query = query.filter(\.$notificationType == notificationType)
        }

        if let productId = request.query[String.self, at: "productId"] {
            query = query.filter(\.$productId == productId)
        }

        if let environment = request.query[String.self, at: "environment"] {
            query = query.filter(\.$environment == environment)
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
    }

    private func getEvent(request: Request) async throws -> AppStoreNotificationEvent {
        guard let notificationUUID = request.parameters.get("notificationUUID") else {
            throw Abort(.badRequest, reason: "Missing notification UUID")
        }

        guard let event = try await AppStoreNotificationEvent.query(on: request.db)
            .filter(\.$notificationUUID == notificationUUID)
            .first()
        else {
            throw Abort(.notFound)
        }

        return event
    }
}

private struct AppStoreNotificationPayload: Content {
    let signedPayload: String
}
