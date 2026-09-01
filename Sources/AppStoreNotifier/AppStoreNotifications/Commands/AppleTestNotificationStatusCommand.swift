import AppStoreServerLibrary
import Vapor

struct AppleTestNotificationStatusCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "token", help: "Token returned by request-test-notification")
        var token: String

        @Option(name: "environment", short: "e", help: "Apple environment: sandbox or production")
        var environment: String?
    }

    let help = "Show Apple's delivery attempts for a TEST server notification"

    func run(using context: CommandContext, signature: Signature) async throws {
        let environment = try AppStoreServerAPIConfiguration.environment(from: signature.environment)
        let client = try AppStoreServerAPIConfiguration.client(environment: environment)

        switch await client.getTestNotificationStatus(testNotificationToken: signature.token) {
        case .success(let response):
            let attempts = response.sendAttempts ?? []
            guard !attempts.isEmpty else {
                context.console.warning("Apple has not recorded a delivery attempt yet")
                return
            }

            for (index, attempt) in attempts.enumerated() {
                let date = attempt.attemptDate.map(String.init(describing:)) ?? "unknown"
                let result = attempt.rawSendAttemptResult ?? "unknown"
                let message: String = "Attempt \(index + 1): \(result) at \(date)"
                context.console.output(message, style: .plain)
            }
        case .failure(let statusCode, let rawApiError, _, let errorMessage, let causedBy):
            throw Abort(
                .badGateway,
                reason: AppStoreServerAPIErrorMessage.message(
                    operation: "get test notification status",
                    statusCode: statusCode,
                    rawApiError: rawApiError,
                    errorMessage: errorMessage,
                    causedBy: causedBy
                )
            )
        }
    }
}
