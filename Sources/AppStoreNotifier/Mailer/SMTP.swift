import Smtp
import Vapor

extension Request {
    func send(_ email: Email, logHandler: ((String) -> Void)? = nil) async throws {
        let result = try await smtp.send(email, logHandler: logHandler).get()

        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}
