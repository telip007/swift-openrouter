import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Turns every API error into an ``OpenRouterError``.
///
/// Doing this once, here, means callers never have to switch over the
/// per-operation `Output` enums for error cases: if an operation returns, it
/// succeeded. Handles non-2xx responses and, for chat completions, error
/// bodies sent after `200 OK` (see `wiki/concepts/errors.md`).
struct ErrorMiddleware: ClientMiddleware {
    /// Upper bound for buffering an error body.
    private static let maxErrorBodyBytes = 1 << 20
    /// Upper bound for buffering a non-streaming chat completion.
    private static let maxResultBodyBytes = 64 << 20
    /// Operations whose `200 OK` JSON body may be an error envelope instead.
    private static let inBandErrorOperations: Set = ["sendChatCompletionRequest"]

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?),
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)
        guard response.status.kind == .successful else {
            var data = Data()
            if let responseBody {
                data = try await Data(collecting: responseBody, upTo: Self.maxErrorBodyBytes)
            }
            throw OpenRouterError(
                statusCode: response.status.code,
                body: data,
                retryAfter: RetryMiddleware.retryAfter(from: response),
            )
        }
        guard Self.inBandErrorOperations.contains(operationID), let responseBody,
            response.headerFields[.contentType]?.hasPrefix("application/json") == true
        else {
            return (response, responseBody)
        }
        let data = try await Data(collecting: responseBody, upTo: Self.maxResultBodyBytes)
        if let error = OpenRouterError(inBandBody: data) {
            throw error
        }
        return (response, HTTPBody(data))
    }
}

/// The `{"error": {...}}` envelope shared by every OpenRouter error response
/// and by mid-stream error chunks.
struct ErrorEnvelope: Decodable {
    struct Payload: Decodable {
        var code: Int?
        var message: String
        var metadata: OpenAPIObjectContainer?
    }

    var error: Payload
}

extension OpenRouterError {
    init(statusCode: Int, body: Data, retryAfter: Duration? = nil) {
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: body) {
            self.init(
                statusCode: statusCode,
                message: envelope.error.message,
                metadata: envelope.error.metadata,
                retryAfter: retryAfter,
            )
        } else {
            let text = String(data: body, encoding: .utf8)
            self.init(
                statusCode: statusCode,
                message: "HTTP \(statusCode)",
                retryAfter: retryAfter,
                rawBody: text?.isEmpty == false ? text : nil,
            )
        }
    }

    /// An error envelope in a `200 OK` body, or `nil` for a regular result.
    init?(inBandBody body: Data) {
        guard let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: body) else {
            return nil
        }
        self.init(
            statusCode: envelope.error.code ?? 500,
            message: envelope.error.message,
            metadata: envelope.error.metadata,
            isMidStream: true,
        )
    }
}
