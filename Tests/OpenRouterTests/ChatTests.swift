import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import OpenRouter

@Suite("Chat")
struct ChatTests {
    @Test("send decodes the result and exposes convenience accessors")
    func sendDecodesResult() async throws {
        let transport = MockTransport(json: Fixtures.chatResult)
        let result = try await OpenRouterClient.mock(transport).chat.send(
            ChatRequest(messages: [.user("Hi")], model: "openai/gpt-4o-mini")
        )

        #expect(result.text == "Let me look.")
        #expect(result.finishReason == FinishReason.toolCalls)
        #expect(result.toolCalls.map(\.function.name) == ["read_file"])
        #expect(result.systemFingerprint == nil)
        #expect(result.usage?.totalTokens == 15)

        struct Arguments: Decodable { var path: String }
        let arguments = try result.toolCalls[0].decodeArguments(as: Arguments.self)
        #expect(arguments.path == "README.md")
    }

    @Test("send adds auth and attribution headers and forces stream: false")
    func sendSetsHeadersAndBody() async throws {
        let transport = MockTransport(json: Fixtures.chatResult)
        var request = ChatRequest(messages: [.user("Hi")], model: "m")
        request.stream = true
        _ = try await OpenRouterClient.mock(transport).chat.send(request)

        let recorded = try #require(transport.requests.first)
        #expect(recorded.request.headerFields[.authorization] == "Bearer sk-or-test")
        #expect(recorded.request.headerFields[.httpReferer] == "https://example.com")
        #expect(recorded.request.headerFields[.openRouterTitle] == "Tests")
        #expect(recorded.request.headerFields[.userAgent] == HeadersMiddleware.userAgent)
        #expect(recorded.request.path == "/chat/completions")

        let body = try JSONDecoder().decode(JSONValue.self, from: recorded.body)
        guard case .object(let object) = body else {
            Issue.record("Body is not a JSON object")
            return
        }
        #expect(object["stream"] == false)
        #expect(object["messages"] == [["role": "user", "content": "Hi"]])
    }

    @Test("API errors surface as OpenRouterError, not ClientError")
    func sendThrowsOpenRouterError() async throws {
        let transport = MockTransport(
            status: .init(code: 402),
            json: #"{"error":{"code":402,"message":"Insufficient credits","metadata":{"needed":1}}}"#,
        )
        let error = try await #require(throws: OpenRouterError.self) {
            try await OpenRouterClient.mock(transport).chat.send(ChatRequest(messages: [.user("Hi")]))
        }
        #expect(error.kind == .paymentRequired)
        #expect(error.message == "Insufficient credits")
        #expect(error.metadata?.value["needed"] as? Int == 1)
        #expect(!error.isRetryable)
        #expect(!error.isMidStream)
    }

    @Test("an error body after 200 OK on a non-streaming request is thrown")
    func sendThrowsInBandError() async throws {
        let transport = MockTransport(
            json:
                #"{"error":{"code":502,"message":"Provider disconnected","metadata":{"error_type":"provider_unavailable","provider_code":"upstream_eof"}}}"#
        )
        let error = try await #require(throws: OpenRouterError.self) {
            try await OpenRouterClient.mock(transport).chat.send(ChatRequest(messages: [.user("Hi")]))
        }
        #expect(error.isMidStream)
        #expect(error.kind == .badGateway)
        #expect(error.errorType == "provider_unavailable")
        #expect(error.providerCode == "upstream_eof")
    }

    @Test("Retry-After is exposed on errors that aren't retried automatically")
    func retryAfterOnPaymentRequired() async throws {
        let transport = MockTransport(
            status: .init(code: 402),
            json:
                #"{"error":{"code":402,"message":"In-flight budget exhausted","metadata":{"limit_source":"openrouter_in_flight_budget"}}}"#,
            headers: [.retryAfter: "7"],
        )
        let error = try await #require(throws: OpenRouterError.self) {
            try await OpenRouterClient.mock(transport).chat.send(ChatRequest(messages: [.user("Hi")]))
        }
        #expect(error.retryAfter == .seconds(7))
        #expect(!error.isRetryable)
    }

    @Test("stream yields chunks until [DONE] and skips comments")
    func streamYieldsChunks() async throws {
        let body =
            ": OPENROUTER PROCESSING\n\n"
            + Fixtures.sse([
                Fixtures.chunk(#"{"role":"assistant","content":"Hel"}"#),
                Fixtures.chunk(#"{"content":"lo"}"#, finishReason: "stop"),
                "[DONE]",
                Fixtures.chunk(#"{"content":"never"}"#),
            ])
        let transport = MockTransport { _, _ in
            MockTransport.response(json: body, contentType: "text/event-stream")
        }

        var text = ""
        for try await chunk in try await OpenRouterClient.mock(transport).chat.stream(ChatRequest(messages: [])) {
            text += chunk.textDelta ?? ""
        }
        #expect(text == "Hello")
    }

    @Test("an error chunk mid-stream is thrown")
    func streamThrowsMidStreamError() async throws {
        let body = Fixtures.sse([
            Fixtures.chunk(#"{"content":"Hi"}"#),
            Fixtures.chunk(
                #"{"content":""}"#,
                finishReason: "error",
                extra:
                    #","error":{"code":429,"message":"Rate limit exceeded","metadata":{"error_type":"rate_limit_exceeded"}}"#,
            ),
        ])
        let transport = MockTransport { _, _ in
            MockTransport.response(json: body, contentType: "text/event-stream")
        }
        let stream = try await OpenRouterClient.mock(transport).chat.stream(ChatRequest(messages: []))

        let error = await #expect(throws: OpenRouterError.self) {
            for try await _ in stream {}
        }
        #expect(error?.isMidStream == true)
        #expect(error?.kind == .rateLimited)
        #expect(error?.errorType == "rate_limit_exceeded")
    }
}
