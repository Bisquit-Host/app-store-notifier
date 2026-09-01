import Vapor

struct TestEmailCommand: AsyncCommand {
    struct Signature: CommandSignature {}

    let help = "Send a diagnostic email using the configured SMTP server"
    let mailer: EventMailer

    func run(using context: CommandContext, signature: Signature) async throws {
        let recipientCount = try await mailer.sendTest(on: context.application)
        context.console.success("Test email sent to \(recipientCount) recipient(s)")
    }
}
