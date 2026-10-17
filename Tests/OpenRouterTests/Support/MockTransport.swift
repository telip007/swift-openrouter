import Foundation
import HTTPTypes
import OpenAPIRuntime
import Synchronization

@testable import OpenRouter

/// A transport that answers requests from a closure and records them.
final class MockTransport: ClientTransport {
    struct Recorded: Sendable {
        var request: HTTPRequest
        var body: Data
    }

    typealias Handler = @Sendable (_ attempt: Int, _ request: HTTPRequest) async throws -> (HTTPResponse, HTTPBody?)

    private let handler: Handler
    private let recorded = Mutex<[Recorded]>([])

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Always answers with `status` and `body`.
    convenience init(status: HTTPResponse.Status = .ok, json: String, headers: HTTPFields = [:]) {
        self.init { _, _ in Self.response(status: status, json: json, headers: headers) }
    }

    var requests: [Recorded] { recorded.withLock { $0 } }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL _: URL,
        operationID _: String,
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var data = Data()
        if let body {
            data = try await Data(collecting: body, upTo: .max)
        }
        let attempt = recorded.withLock { requests in
            requests.append(Recorded(request: request, body: data))
            return requests.count - 1
        }
        return try await handler(attempt, request)
    }

    static func response(
        status: HTTPResponse.Status = .ok,
        json: String,
        contentType: String = "application/json",
        headers: HTTPFields = [:],
    ) -> (HTTPResponse, HTTPBody?) {
        var fields = headers
        fields[.contentType] = contentType
        return (HTTPResponse(status: status, headerFields: fields), HTTPBody(json))
    }
}

extension OpenRouterClient {
    /// A client wired to `transport`, with instant retries.
    static func mock(_ transport: MockTransport, retryPolicy: RetryPolicy = .disabled) -> Self {
        Self(
            apiKey: "sk-or-test",
            configuration: .init(appURL: "https://example.com", appTitle: "Tests", retryPolicy: retryPolicy),
            transport: transport,
        )
    }
}

enum Fixtures {
    static let chatResult = """
        {
          "id": "gen-123",
          "object": "chat.completion",
          "created": 1700000000,
          "model": "openai/gpt-4o-mini",
          "system_fingerprint": null,
          "choices": [{
            "index": 0,
            "finish_reason": "tool_calls",
            "message": {
              "role": "assistant",
              "content": "Let me look.",
              "tool_calls": [{
                "id": "call_1",
                "type": "function",
                "function": {"name": "read_file", "arguments": "{\\"path\\":\\"README.md\\"}"}
              }]
            }
          }],
          "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        }
        """

    static func chunk(_ delta: String, finishReason: String? = nil, extra: String = "") -> String {
        let reason = finishReason.map { "\"\($0)\"" } ?? "null"
        return """
            {"id":"gen-123","object":"chat.completion.chunk","created":1700000000,\
            "model":"openai/gpt-4o-mini","choices":[{"index":0,"delta":\(delta),\
            "finish_reason":\(reason)}]\(extra)}
            """
    }

    static func sse(_ events: [String]) -> String {
        events.map { "data: \($0)\n\n" }.joined()
    }
}
