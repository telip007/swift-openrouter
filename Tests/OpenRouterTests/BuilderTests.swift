import Foundation
import Testing

@testable import OpenRouter

@Suite("Builders")
struct BuilderTests {
    private func json(_ value: some Encodable) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }

    @Test("message builders encode the expected roles")
    func messages() throws {
        #expect(try json(ChatMessage.system("s")) == ["role": "system", "content": "s"])
        #expect(try json(ChatMessage.developer("d")) == ["role": "developer", "content": "d"])
        #expect(try json(ChatMessage.assistant("a")) == ["role": "assistant", "content": "a"])
        #expect(
            try json(ChatMessage.tool(callID: "c1", content: "ok"))
                == ["role": "tool", "content": "ok", "tool_call_id": "c1"])
        #expect(
            try json(ChatMessage.user([.text("look"), .image(url: "https://x/y.png")])) == [
                "role": "user",
                "content": [
                    ["type": "text", "text": "look"],
                    ["type": "image_url", "image_url": ["url": "https://x/y.png"]],
                ],
            ])
    }

    @Test("function tools carry their JSON Schema")
    func functionTool() throws {
        let tool = ChatTool.function(
            name: "read_file",
            description: "Read a file",
            parameters: [
                "type": "object",
                "properties": ["path": ["type": "string"], "limit": ["type": "integer", "minimum": 1]],
                "required": ["path"],
                "additionalProperties": false,
            ],
            strict: true,
        )
        #expect(
            try json(tool) == [
                "type": "function",
                "function": [
                    "name": "read_file",
                    "description": "Read a file",
                    "strict": true,
                    "parameters": [
                        "type": "object",
                        "properties": ["path": ["type": "string"], "limit": ["type": "integer", "minimum": 1]],
                        "required": ["path"],
                        "additionalProperties": false,
                    ],
                ],
            ])
    }

    @Test("tool choices encode as strings or a named function")
    func toolChoice() throws {
        #expect(try json(ChatToolChoice.auto) == "auto")
        #expect(try json(ChatToolChoice.disabled) == "none")
        #expect(try json(ChatToolChoice.required) == "required")
        #expect(try json(ChatToolChoice.function("f")) == ["type": "function", "function": ["name": "f"]])
    }

    @Test("JSONValue round-trips through JSON")
    func jsonValueRoundTrip() throws {
        let value: JSONValue = ["a": [1, 2.5, "x", true, nil], "b": ["c": nil]]
        #expect(try json(value) == value)
    }

    @Test("assistant text joins multi-part content")
    func assistantText() {
        let message = ChatAssistantMessage(
            content: .init(value2: [.text("a"), .image(url: "u"), .text("b")]),
            role: .assistant,
        )
        #expect(message.text == "ab")
        #expect(ChatAssistantMessage(text: nil, toolCalls: []).toolCalls == nil)
    }
}
