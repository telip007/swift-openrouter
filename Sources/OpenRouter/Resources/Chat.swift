import Foundation
import OpenAPIRuntime

extension OpenRouterClient {
    /// Chat completions (`POST /chat/completions`).
    public struct Chat: Sendable {
        let api: Client

        /// Sends a chat request and waits for the complete response.
        ///
        /// `request.stream` is ignored; use ``stream(_:)`` to stream.
        public func send(_ request: ChatRequest) async throws -> ChatResult {
            var request = request
            request.stream = false
            let output = try await unwrappingClientError {
                try await api.sendChatCompletionRequest(
                    headers: .init(accept: [.init(contentType: .json)]),
                    body: .json(request),
                )
            }
            return try output.ok.body.json
        }

        /// Sends a chat request and streams the response chunk by chunk.
        ///
        /// ```swift
        /// var accumulator = ChatStreamAccumulator()
        /// for try await chunk in try await openRouter.chat.stream(request) {
        ///     accumulator.add(chunk)
        ///     print(chunk.textDelta ?? "", terminator: "")
        /// }
        /// messages.append(.assistant(accumulator.message))
        /// ```
        ///
        /// `request.stream` is ignored. The last chunk before `[DONE]` carries
        /// `usage` and repeats the `finish_reason`.
        ///
        /// - Throws: ``OpenRouterError`` when the request is rejected. Errors
        ///   that happen after streaming has started are thrown from the
        ///   sequence with ``OpenRouterError/isMidStream`` set.
        public func stream(_ request: ChatRequest) async throws -> some AsyncSequence<ChatStreamChunk, any Error> {
            var request = request
            request.stream = true
            let output = try await unwrappingClientError {
                try await api.sendChatCompletionRequest(
                    headers: .init(accept: [.init(contentType: .textEventStream)]),
                    body: .json(request),
                )
            }
            return try output.ok.body.textEventStream.chatStreamChunks()
        }
    }
}

extension HTTPBody {
    /// Decodes an OpenRouter server-sent-events body into chunks, stopping at
    /// the `[DONE]` sentinel and turning `error` chunks into thrown errors.
    func chatStreamChunks() -> some AsyncSequence<ChatStreamChunk, any Error> {
        asDecodedServerSentEventsWithJSONData(
            of: ChatStreamChunk.self,
            decoder: JSONDecoder(),
            while: { $0 != ArraySlice("[DONE]".utf8) },
        )
        // Events without data (e.g. `: OPENROUTER PROCESSING` keep-alive
        // comments) carry nothing for the caller.
        .compactMap(\.data)
        .map { chunk in
            if let error = chunk.error {
                throw OpenRouterError(
                    statusCode: Int(error.code),
                    message: error.message,
                    errorType: error.metadata?.errorType,
                    providerCode: error.metadata?.providerCode,
                    isMidStream: true,
                )
            }
            return chunk
        }
    }
}
