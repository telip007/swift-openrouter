/// Assembles streamed chunks into a complete assistant message.
///
/// Tool calls arrive in fragments: the first fragment for a given `index`
/// carries the id and function name, later ones append to the JSON
/// arguments string. The accumulator stitches them back together, and
/// likewise merges `reasoning_details` fragments, so the message can be sent
/// back with its reasoning intact.
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
    /// The structured reasoning received so far, fragments merged. See
    /// [reasoning tokens](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens).
    public private(set) var reasoningDetails: [ReasoningDetail] = []
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
        for detail in choice.delta.reasoningDetails ?? [] {
            if let last = reasoningDetails.indices.last, let merged = reasoningDetails[last].merging(detail) {
                reasoningDetails[last] = merged
            } else {
                reasoningDetails.append(detail)
            }
        }
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

    /// The assembled assistant message, ready to append to the conversation,
    /// with its reasoning so the model can continue from it.
    public var message: ChatAssistantMessage {
        var message = ChatAssistantMessage(text: text.isEmpty ? nil : text, toolCalls: toolCalls)
        message.reasoning = reasoning.isEmpty ? nil : reasoning
        message.reasoningDetails = reasoningDetails.isEmpty ? nil : reasoningDetails
        return message
    }
}

extension ReasoningDetail {
    /// This detail with `fragment` appended, when `fragment` continues it: a
    /// text or summary of the same index. `nil` otherwise.
    fileprivate func merging(_ fragment: Self) -> Self? {
        switch (self, fragment) {
        case (.reasoning_text(var detail), .reasoning_text(let next)) where detail.index == next.index:
            detail.text = (detail.text ?? "") + (next.text ?? "")
            detail.signature = next.signature ?? detail.signature
            detail.id = detail.id ?? next.id
            detail.format = detail.format ?? next.format
            return .reasoning_text(detail)
        case (.reasoning_summary(var detail), .reasoning_summary(let next)) where detail.index == next.index:
            detail.summary += next.summary
            detail.id = detail.id ?? next.id
            detail.format = detail.format ?? next.format
            return .reasoning_summary(detail)
        default:
            return nil
        }
    }
}
