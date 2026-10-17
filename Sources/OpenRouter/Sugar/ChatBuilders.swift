public import Foundation

// MARK: - Messages

extension Components.Schemas.ChatMessages {
    /// A system message.
    public static func system(_ text: String) -> Self {
        .system(.init(content: .init(value1: text), role: .system))
    }

    /// A developer message (the newer name for system instructions).
    public static func developer(_ text: String) -> Self {
        .developer(.init(content: .init(value1: text), role: .developer))
    }

    /// A plain-text user message.
    public static func user(_ text: String) -> Self {
        .user(.init(content: .init(value1: text), role: .user))
    }

    /// A user message made of parts, e.g. text plus images.
    public static func user(_ parts: [Components.Schemas.ChatContentItems]) -> Self {
        .user(.init(content: .init(value2: parts), role: .user))
    }

    /// A plain-text assistant message, e.g. for few-shot examples.
    public static func assistant(_ text: String) -> Self {
        .assistant(.init(content: .init(value1: text), role: .assistant))
    }

    /// The result of a tool call, answering the assistant's `ChatToolCall`
    /// with the same `id`.
    public static func tool(callID: String, content: String) -> Self {
        .tool(.init(content: .init(value1: content), role: .tool, toolCallId: callID))
    }
}

extension Components.Schemas.ChatContentItems {
    /// A text part.
    public static func text(_ text: String) -> Self {
        .text(.init(text: text, _type: .text))
    }

    /// An image part from a URL or a `data:` URL.
    public static func image(url: String) -> Self {
        .imageUrl(.init(imageUrl: .init(url: url), _type: .imageUrl))
    }
}

// MARK: - Tools

extension Components.Schemas.ChatFunctionTool {
    /// A function the model may call.
    ///
    /// ```swift
    /// ChatTool.function(
    ///     name: "read_file",
    ///     description: "Read a UTF-8 file from disk",
    ///     parameters: [
    ///         "type": "object",
    ///         "properties": ["path": ["type": "string"]],
    ///         "required": ["path"],
    ///     ]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - name: The name the model uses to call the function.
    ///   - description: What the function does and when to use it.
    ///   - parameters: A JSON Schema object describing the arguments.
    ///   - strict: Ask the provider to enforce the schema exactly.
    /// - Returns: A function tool definition.
    public static func function(
        name: String,
        description: String? = nil,
        parameters: [String: JSONValue]? = nil,
        strict: Bool? = nil,
    ) -> Self {
        let function = Value1Payload.FunctionPayload(
            description: description,
            name: name,
            parameters: parameters.map { .init(additionalProperties: $0.mapValues(\.container)) },
            strict: strict,
        )
        return Self(value1: .init(function: function, _type: .function))
    }
}

extension Components.Schemas.ChatToolChoice {
    /// The model decides whether to call tools.
    public static let auto = Self(value2: .auto)
    /// The model must not call tools (`"none"` on the wire; not named `none`
    /// because `toolChoice: .none` would mean `nil`).
    public static let disabled = Self(value1: Value1Payload.none)
    /// The model must call at least one tool.
    public static let required = Self(value3: .required)

    /// The model must call the named function.
    public static func function(_ name: String) -> Self {
        Self(value4: .init(function: .init(name: name), _type: .function))
    }
}

extension Components.Schemas.ChatToolCall {
    /// Decodes the JSON-encoded arguments into `type`.
    public func decodeArguments<Arguments: Decodable>(
        as type: Arguments.Type = Arguments.self,
        decoder: JSONDecoder = JSONDecoder(),
    ) throws -> Arguments {
        try decoder.decode(type, from: Data(function.arguments.utf8))
    }
}

// MARK: - Results

/// Well-known `finish_reason` values. The API may add more.
public enum FinishReason {
    /// The model finished its answer or hit a stop sequence.
    public static let stop = "stop"
    /// The model wants tool results before continuing.
    public static let toolCalls = "tool_calls"
    /// `max_tokens` or the context window was reached.
    public static let length = "length"
    /// Output was withheld by a content filter.
    public static let contentFilter = "content_filter"
    /// The provider failed mid-generation.
    public static let error = "error"
}

extension Components.Schemas.ChatAssistantMessage {
    /// The text content, joining text parts if the content is multi-part.
    public var text: String? {
        guard let content else { return nil }
        if let text = content.value1 {
            return text
        }
        let parts = content.value2?.compactMap { item -> String? in
            if case .text(let part) = item { part.text } else { nil }
        }
        return parts?.joined()
    }

    /// Creates an assistant message that can be sent back as history.
    public init(text: String?, toolCalls: [ChatToolCall]?) {
        self.init(
            content: text.map { .init(value1: $0) },
            role: .assistant,
            toolCalls: toolCalls?.isEmpty == true ? nil : toolCalls,
        )
    }
}

extension Components.Schemas.ChatResult {
    /// The first choice's message.
    public var message: ChatAssistantMessage? { choices.first?.message }
    /// The first choice's text.
    public var text: String? { message?.text }
    /// The first choice's tool calls (empty if none).
    public var toolCalls: [ChatToolCall] { message?.toolCalls ?? [] }
    /// The first choice's finish reason. See ``FinishReason``.
    public var finishReason: String? { choices.first?.finishReason }
}

extension Components.Schemas.ChatStreamChunk {
    /// The text added by this chunk's first choice.
    public var textDelta: String? { choices.first?.delta.content }
    /// The reasoning text added by this chunk's first choice.
    public var reasoningDelta: String? { choices.first?.delta.reasoning }
}
