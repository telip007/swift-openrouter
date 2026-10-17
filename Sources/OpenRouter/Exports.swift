// `import OpenRouter` is all a client needs: the generated API surface is
// re-exported, and the most common generated types get short names.
@_exported public import OpenRouterAPI

// MARK: - Chat

/// A chat completion request.
public typealias ChatRequest = Components.Schemas.ChatRequest
/// One message in a conversation. Build with `.system(_:)`, `.user(_:)`, `.tool(callID:content:)`, …
public typealias ChatMessage = Components.Schemas.ChatMessages
/// A message produced by the model.
public typealias ChatAssistantMessage = Components.Schemas.ChatAssistantMessage
/// A complete (non-streamed) chat completion.
public typealias ChatResult = Components.Schemas.ChatResult
/// One choice of a ``ChatResult``.
public typealias ChatChoice = Components.Schemas.ChatChoice
/// One server-sent event of a streamed chat completion.
public typealias ChatStreamChunk = Components.Schemas.ChatStreamChunk
/// The incremental content of a ``ChatStreamChunk``.
public typealias ChatStreamDelta = Components.Schemas.ChatStreamDelta
/// A tool the model may call. Build with `.function(name:description:parameters:strict:)`.
public typealias ChatTool = Components.Schemas.ChatFunctionTool
/// A tool call requested by the model.
public typealias ChatToolCall = Components.Schemas.ChatToolCall
/// Whether and which tools the model must call: `.auto`, `.disabled`, `.required`, `.function(_:)`.
public typealias ChatToolChoice = Components.Schemas.ChatToolChoice
/// Token counts and cost of a completion.
public typealias ChatUsage = Components.Schemas.ChatUsage

// MARK: - Platform

/// A model in the OpenRouter catalogue.
public typealias ModelInfo = Components.Schemas.Model
/// Filters and pagination for listing models.
public typealias ModelsListQuery = Operations.GetModels.Input.Query
/// Credits purchased and used by the account.
public typealias CreditBalance = Operations.GetCredits.Output.Ok.Body.JsonPayload.DataPayload
/// Metadata, token counts and cost of a past generation.
public typealias Generation = Components.Schemas.GenerationResponse.DataPayload
/// Label, limits and usage of an API key.
public typealias APIKeyInfo = Operations.GetCurrentKey.Output.Ok.Body.JsonPayload.DataPayload
