import Foundation
import Testing

@testable import OpenRouter

@Suite("ChatStreamAccumulator")
struct StreamAccumulatorTests {
    private func chunk(_ delta: String, finishReason: String? = nil, extra: String = "") throws -> ChatStreamChunk {
        try JSONDecoder().decode(
            ChatStreamChunk.self,
            from: Data(Fixtures.chunk(delta, finishReason: finishReason, extra: extra).utf8),
        )
    }

    @Test("assembles text, reasoning and fragmented parallel tool calls")
    func assemblesMessage() throws {
        var accumulator = ChatStreamAccumulator()
        let deltas = [
            #"{"role":"assistant","reasoning":"Need "}"#,
            #"{"reasoning":"files.","content":"Reading"}"#,
            #"{"tool_calls":[{"index":0,"id":"call_a","type":"function","function":{"name":"read","arguments":""}}]}"#,
            #"{"tool_calls":[{"index":1,"id":"call_b","type":"function","function":{"name":"list","arguments":"{}"}}]}"#,
            #"{"tool_calls":[{"index":0,"function":{"arguments":"{\"path\":"}}]}"#,
            #"{"tool_calls":[{"index":0,"function":{"arguments":"\"a\"}"}}]}"#,
        ]
        for delta in deltas {
            accumulator.add(try chunk(delta))
        }
        accumulator.add(
            try chunk(
                "{}",
                finishReason: "tool_calls",
                extra: #","usage":{"prompt_tokens":1,"completion_tokens":2,"total_tokens":3}"#,
            ))

        #expect(accumulator.id == "gen-123")
        #expect(accumulator.model == "openai/gpt-4o-mini")
        #expect(accumulator.text == "Reading")
        #expect(accumulator.reasoning == "Need files.")
        #expect(accumulator.finishReason == FinishReason.toolCalls)
        #expect(accumulator.usage?.totalTokens == 3)
        #expect(accumulator.toolCalls.map(\.id) == ["call_a", "call_b"])
        #expect(accumulator.toolCalls.map(\.function.name) == ["read", "list"])
        #expect(accumulator.toolCalls.map(\.function.arguments) == [#"{"path":"a"}"#, "{}"])
        #expect(accumulator.message.text == "Reading")
        #expect(accumulator.message.toolCalls?.count == 2)
    }

    @Test("a text-only stream produces no tool calls")
    func textOnly() throws {
        var accumulator = ChatStreamAccumulator()
        accumulator.add(try chunk(#"{"content":"Hi"}"#, finishReason: "stop"))
        #expect(accumulator.message.toolCalls == nil)
        #expect(accumulator.message.text == "Hi")
    }
}
