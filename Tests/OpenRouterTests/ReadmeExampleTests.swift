import Foundation
import Testing

@testable import OpenRouter

/// The code samples from README.md, compiled and run against the mock
/// transport so the README can't silently drift from the API.
/// Keep these in sync with README.md.
@Suite("README examples")
struct ReadmeExampleTests {
    private let openRouter = OpenRouterClient.mock(MockTransport(json: Fixtures.chatResult))

    @Test("quick start")
    func quickStart() async throws {
        let result = try await openRouter.chat.send(
            ChatRequest(
                messages: [.system("Be concise."), .user("What is OpenRouter?")],
                model: "openai/gpt-4o-mini"
            )
        )
        #expect(result.text != nil)
        #expect(result.usage?.totalTokens != nil)
    }

    @Test("tools loop")
    func tools() async throws {
        let readFile = ChatTool.function(
            name: "read_file",
            description: "Read a UTF-8 text file",
            parameters: [
                "type": "object",
                "properties": ["path": ["type": "string"]],
                "required": ["path"],
            ]
        )

        var messages: [ChatMessage] = [.user("What's in README.md?")]
        let result = try await openRouter.chat.send(
            ChatRequest(messages: messages, model: "anthropic/claude-sonnet-4", toolChoice: .auto, tools: [readFile])
        )

        if result.finishReason == FinishReason.toolCalls, let message = result.message {
            messages.append(.assistant(message))
            for call in result.toolCalls {
                struct Arguments: Decodable { var path: String }
                let path = try call.decodeArguments(as: Arguments.self).path
                messages.append(.tool(callID: call.id, content: "contents of \(path)"))
            }
        }
        #expect(messages.count == 3)
    }

    @Test("error handling compiles and classifies")
    func errors() {
        let error = OpenRouterError(
            statusCode: 400,
            message: "too long",
            metadata: nil,
            errorType: "context_length_exceeded",
        )
        var handled = false
        switch error.errorType {
        case "context_length_exceeded": handled = true
        case "rate_limit_exceeded": break
        default: print(error.kind, error.statusCode, error.message)
        }
        #expect(handled)
    }

    @Test("configuration")
    func configuration() {
        _ = OpenRouterClient(
            apiKey: "sk-or-test",
            configuration: .init(
                appURL: "https://example.com",
                appTitle: "My App",
                retryPolicy: .init(maxElapsedTime: .seconds(30)),
                timeout: .seconds(120)
            ),
            transport: nil,
            middlewares: []
        )
    }

    @Test("everything else via api")
    func lowLevel() async throws {
        let transport = MockTransport(json: #"{"data":[]}"#)
        let providers = try await OpenRouterClient.mock(transport).api.listProviders().ok.body.json
        #expect(providers.data.isEmpty)
    }
}
