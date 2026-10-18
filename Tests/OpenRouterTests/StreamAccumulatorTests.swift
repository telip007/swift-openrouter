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

    @Test("merges reasoning detail fragments and keeps them on the message")
    func reasoningDetails() throws {
        var accumulator = ChatStreamAccumulator()
        let deltas = [
            #"{"reasoning":"Let ","reasoning_details":[{"type":"reasoning.text","text":"Let ","id":"r1","format":"anthropic-claude-v1","index":0}]}"#,
            #"{"reasoning":"me.","reasoning_details":[{"type":"reasoning.text","text":"me.","index":0}]}"#,
            #"{"reasoning_details":[{"type":"reasoning.text","signature":"sig","index":0}]}"#,
            #"{"reasoning_details":[{"type":"reasoning.summary","summary":"Short ","index":1}]}"#,
            #"{"reasoning_details":[{"type":"reasoning.summary","summary":"plan.","index":1}]}"#,
            #"{"reasoning_details":[{"type":"reasoning.encrypted","data":"abc","index":2}]}"#,
            #"{"reasoning_details":[{"type":"reasoning.text","text":"Again.","index":3}]}"#,
            #"{"content":"Done"}"#,
        ]
        for delta in deltas {
            accumulator.add(try chunk(delta))
        }

        let details = accumulator.reasoningDetails
        #expect(details.count == 4)
        guard case .reasoning_text(let text) = details[0], case .reasoning_summary(let summary) = details[1],
            case .reasoning_encrypted(let encrypted) = details[2], case .reasoning_text(let again) = details[3]
        else {
            Issue.record("unexpected details: \(details)")
            return
        }
        #expect(text.text == "Let me.")
        #expect(text.signature == "sig")
        #expect(text.id == "r1")
        #expect(text.format == "anthropic-claude-v1")
        #expect(summary.summary == "Short plan.")
        #expect(encrypted.data == "abc")
        #expect(again.text == "Again.")
        #expect(accumulator.message.reasoning == "Let me.")
        #expect(accumulator.message.reasoningDetails == details)
        #expect(accumulator.message.text == "Done")
    }

    @Test("a stream without reasoning leaves it off the message")
    func noReasoning() throws {
        var accumulator = ChatStreamAccumulator()
        accumulator.add(try chunk(#"{"content":"Hi"}"#, finishReason: "stop"))
        #expect(accumulator.message.reasoning == nil)
        #expect(accumulator.message.reasoningDetails == nil)
    }
}
