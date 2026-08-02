import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(status: Int, message: String)
    case decodingError(String)
    case emptyResponse
    case invalidAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Could not build the request URL."
        case .unauthorized, .invalidAPIKey:
            "Invalid or missing API key. Add your key in Profile → Settings."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "Rate limit exceeded. Retry in \(Int(retryAfter)) seconds."
            } else {
                "Rate limit exceeded. Please wait and try again."
            }
        case .serverError(let status, let message):
            "Server error (\(status)): \(message)"
        case .decodingError(let message):
            "Failed to decode response: \(message)"
        case .emptyResponse:
            "The server returned an empty response."
        }
    }
}

