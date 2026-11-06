import Fluent
import Vapor

struct AppStoreNotificationEventController: RouteCollection {
    let token: String?

    init(token: String? = Environment.get("EVENTS_API_TOKEN")) {
        self.token = token
    }

    func boot(routes: any RoutesBuilder) throws {
        routes.grouped("app-store", "notifications")
            .grouped(EventReadTokenMiddleware(token: token))
            .get("events", use: listEvents)
    }

    private func listEvents(request: Request) async throws -> Page<AppStoreNotificationEventResponse> {
        let query = try request.query.decode(EventPageQuery.self)
        let page = query.page ?? 1
        let per = query.per ?? 100
        guard page > 0, (1...250).contains(per), page <= Int.max / per else {
            throw Abort(.badRequest, reason: "page must be positive and per must be between 1 and 250")
        }

        return try await AppStoreNotificationEvent.query(on: request.db)
            .sort(\.$createdAt, .ascending)
            .sort(\.$id, .ascending)
            .paginate(PageRequest(page: page, per: per))
            .map(AppStoreNotificationEventResponse.init(event:))
    }
}

private struct EventPageQuery: Decodable {
    let page: Int?
    let per: Int?
}

struct EventReadTokenMiddleware: AsyncMiddleware {
    let token: String?

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.serviceUnavailable, reason: "Event access is not configured")
        }
        guard let supplied = request.headers.bearerAuthorization?.token,
              Array(token.utf8).secureCompare(to: Array(supplied.utf8)) else {
            throw Abort(.unauthorized, headers: ["WWW-Authenticate": "Bearer"])
        }

        let response = try await next.respond(to: request)
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-store")
        return response
    }
}
