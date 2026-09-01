import AppStoreServerLibrary
import Vapor

struct RequestAppleTestNotificationCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "environment", short: "e", help: "Apple environment: sandbox or production")
        var environment: String?
    }

    let help = "Ask Apple to send a signed TEST server notification"

    func run(using context: CommandContext, signature: Signature) async throws {
        let environment = try AppStoreServerAPIConfiguration.environment(from: signature.environment)
        let client = try AppStoreServerAPIConfiguration.client(environment: environment)

        switch await client.requestTestNotification() {
        case .success(let response):
            guard let token = response.testNotificationToken else {
                throw Abort(.badGateway, reason: "Apple returned no test notification token")
            }

            context.console.success("Apple accepted the \(environment.rawValue) test notification")
            context.console.output("Test notification token: \(token)")
            context.console.output("Check it with: test-notification-status \(token) --environment \(environment.rawValue.lowercased())")
        case .failure(let statusCode, let rawApiError, _, let errorMessage, let causedBy):
            throw Abort(
                .badGateway,
                reason: AppStoreServerAPIErrorMessage.message(
                    operation: "request test notification",
                    statusCode: statusCode,
                    rawApiError: rawApiError,
                    errorMessage: errorMessage,
                    causedBy: causedBy
                )
            )
        }
    }
}
