enum EventMailDeliveryStatus: String, Sendable {
    case pending, disabled, filtered, logged, sent, failed

    var shouldRetry: Bool {
        switch self {
        case .pending, .failed:
            true
        case .disabled, .filtered, .logged, .sent:
            false
        }
    }
}
