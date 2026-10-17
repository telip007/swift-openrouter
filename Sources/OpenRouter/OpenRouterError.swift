public import OpenAPIRuntime

/// An error reported by the OpenRouter API: a non-2xx HTTP response, or an
/// error reported after a `200 OK` was already sent (a mid-stream SSE error
/// event, or an error body on a non-streaming request).
///
/// See https://openrouter.ai/docs/api_reference/errors-and-debugging
///
/// ```swift
/// do {
///     _ = try await openRouter.chat.send(request)
/// } catch let error as OpenRouterError where error.kind == .paymentRequired {
///     print("Top up at https://openrouter.ai/credits")
/// }
/// ```
public struct OpenRouterError: Error, Hashable, Sendable, CustomStringConvertible {
    /// The error category, derived from ``statusCode``.
    public enum Kind: Hashable, Sendable {
        case badRequest
        case unauthorized
        case paymentRequired
        case forbidden
        case notFound
        case requestTimeout
        case payloadTooLarge
        case unprocessableEntity
        case rateLimited
        case clientClosedRequest
        case internalServerError
        case badGateway
        case serviceUnavailable
        case gatewayTimeout
        case edgeNetworkTimeout
        case providerOverloaded
        case other

        init(statusCode: Int) {
            switch statusCode {
            case 400: self = .badRequest
            case 401: self = .unauthorized
            case 402: self = .paymentRequired
            case 403: self = .forbidden
            case 404: self = .notFound
            case 408: self = .requestTimeout
            case 413: self = .payloadTooLarge
            case 422: self = .unprocessableEntity
            case 429: self = .rateLimited
            case 499: self = .clientClosedRequest
            case 500: self = .internalServerError
            case 502: self = .badGateway
            case 503: self = .serviceUnavailable
            case 504: self = .gatewayTimeout
            case 524: self = .edgeNetworkTimeout
            case 529: self = .providerOverloaded
            default: self = .other
            }
        }
    }

    /// The HTTP status code, or the `code` of a mid-stream error.
    public var statusCode: Int
    /// The human-readable message from the API.
    public var message: String
    /// Provider-specific details, e.g. `provider_name` or `raw` upstream output.
    public var metadata: OpenAPIObjectContainer?
    /// OpenRouter's typed error code (`error.metadata.error_type`), stable
    /// across providers, e.g. `context_length_exceeded`,
    /// `rate_limit_exceeded`, `provider_overloaded`, `content_policy_violation`.
    public var errorType: String?
    /// The upstream provider's own error code, when available (never on 500s).
    public var providerCode: String?
    /// How long the server asked to wait before retrying (`Retry-After`).
    ///
    /// Sent with 429 and 503, and with 402 when the in-flight spending budget
    /// is exhausted. The client retries 429/503 itself; a 402 is never retried
    /// automatically, so callers who want to wait it out use this value.
    public var retryAfter: Duration?
    /// `true` if the error was reported after the server had already sent
    /// `200 OK`: as an SSE error event mid-stream, or as an error body on a
    /// non-streaming request. Partial output may already have been produced.
    public var isMidStream: Bool
    /// The raw response body, when it could not be parsed as an API error.
    public var rawBody: String?

    /// The error category.
    public var kind: Kind { Kind(statusCode: statusCode) }

    /// Whether retrying the same request later might succeed.
    public var isRetryable: Bool {
        statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
    }

    /// A human-readable description of the error.
    public var description: String {
        let origin = isMidStream ? "OpenRouter stream error" : "OpenRouter error"
        return "\(origin) \(statusCode) (\(kind)): \(message)"
    }

    /// Creates an error.
    public init(
        statusCode: Int,
        message: String,
        metadata: OpenAPIObjectContainer? = nil,
        errorType: String? = nil,
        providerCode: String? = nil,
        retryAfter: Duration? = nil,
        isMidStream: Bool = false,
        rawBody: String? = nil,
    ) {
        self.statusCode = statusCode
        self.message = message
        self.metadata = metadata
        self.errorType = errorType ?? metadata?.value["error_type"] as? String
        self.providerCode = providerCode ?? metadata?.value["provider_code"] as? String
        self.retryAfter = retryAfter
        self.isMidStream = isMidStream
        self.rawBody = rawBody
    }
}

/// Runs a generated-client call and surfaces the interesting error.
///
/// The generated client wraps everything thrown by middlewares and the
/// transport in `ClientError`. Callers care about the cause (an API error,
/// cancellation, a network failure), not the wrapper.
func unwrappingClientError<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let error as ClientError {
        throw error.underlyingError
    }
}
