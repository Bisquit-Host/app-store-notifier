enum AppStoreServerAPIErrorMessage {
    static func message(
        operation: String,
        statusCode: Int?,
        rawApiError: Int64?,
        errorMessage: String?,
        causedBy: (any Error)?
    ) -> String {
        let status = statusCode.map(String.init) ?? "unknown"
        let apiError = rawApiError.map(String.init) ?? "unknown"
        let cause = causedBy.map(ErrorMessageSanitizer.message(for:)) ?? "none"
        return "Apple failed to \(operation), HTTP \(status), API error \(apiError), message \(errorMessage ?? "none"), cause \(cause)"
    }
}
