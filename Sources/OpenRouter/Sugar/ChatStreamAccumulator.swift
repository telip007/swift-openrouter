/// Assembles streamed chunks into a complete assistant message.
///
/// Tool calls arrive in fragments: the first fragment for a given `index`
/// carries the id and function name, later ones append to the JSON
/// arguments string. The accumulator stitches them back together.
///
/// Only the first choice is tracked; OpenRouter streams one choice.
public struct ChatStreamAccumulator: Sendable {
    /// The generation id; pass it to `generations.get(_:)` for cost details.
    public private(set) var id: String?
    /// The model that actually served the request.
    public private(set) var model: String?
    /// The text received so far.
    public private(set) var text = ""
    /// The reasoning text received so far.
    public private(set) var reasoning = ""
    /// The finish reason, once received. See ``FinishReason``.
    public private(set) var finishReason: String?
    /// Token usage, from the final chunk.
    public private(set) var usage: ChatUsage?

    private var partialToolCalls: [Int: PartialToolCall] = [:]

    private struct PartialToolCall {
        var id = ""
        var name = ""
        var arguments = ""
    }

    /// Creates an empty accumulator.
    public init() {}

    /// Adds a chunk.
    public mutating func add(_ chunk: ChatStreamChunk) {
        id = id ?? chunk.id
        model = model ?? chunk.model
        usage = chunk.usage ?? usage
        guard let choice = chunk.choices.first else { return }
        finishReason = choice.finishReason ?? finishReason
        text += choice.delta.content ?? ""
        reasoning += choice.delta.reasoning ?? ""
        for fragment in choice.delta.toolCalls ?? [] {
            var call = partialToolCalls[fragment.index, default: PartialToolCall()]
            call.id += fragment.id ?? ""
            call.name += fragment.function?.name ?? ""
            call.arguments += fragment.function?.arguments ?? ""
            partialToolCalls[fragment.index] = call
        }
    }

    /// The completed tool calls, in index order.
    public var toolCalls: [ChatToolCall] {
        partialToolCalls.sorted { $0.key < $1.key }.map { _, call in
            ChatToolCall(function: .init(arguments: call.arguments, name: call.name), id: call.id, _type: .function)
        }
    }

    /// The assembled assistant message, ready to append to the conversation.
    public var message: ChatAssistantMessage {
        ChatAssistantMessage(text: text.isEmpty ? nil : text, toolCalls: toolCalls)
    }
}
