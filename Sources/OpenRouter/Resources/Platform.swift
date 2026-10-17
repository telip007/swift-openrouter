extension OpenRouterClient {
    /// Model catalogue (`/models`).
    public struct Models: Sendable {
        let api: Client

        /// Lists one page of models.
        public func list(_ query: ModelsListQuery = .init()) async throws -> Components.Schemas.ModelsListResponse {
            try await unwrappingClientError {
                try await api.getModels(query: query)
            }.ok.body.json
        }

        /// Lists every model matching `query`, following pagination.
        public func all(_ query: ModelsListQuery = .init()) async throws -> [ModelInfo] {
            var query = query
            var models: [ModelInfo] = []
            while true {
                let page = try await list(query)
                models += page.data
                guard page.links.next != nil, !page.data.isEmpty else {
                    return models
                }
                query.offset = (query.offset ?? 0) + page.data.count
            }
        }

        /// Fetches one model by its id, e.g. `"anthropic/claude-sonnet-4"`.
        public func get(_ id: String) async throws -> ModelInfo {
            let parts = id.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            let author = parts.count == 2 ? String(parts[0]) : ""
            let slug = String(parts.last ?? "")
            return try await unwrappingClientError {
                try await api.getModel(path: .init(author: author, slug: slug))
            }.ok.body.json.data
        }

        /// The number of available models.
        public func count() async throws -> Int {
            try await unwrappingClientError {
                try await api.listModelsCount()
            }.ok.body.json.data.count
        }
    }

    /// Account credits (`GET /credits`). Requires a management key.
    public struct Credits: Sendable {
        let api: Client

        /// Total credits purchased and used.
        public func get() async throws -> CreditBalance {
            try await unwrappingClientError {
                try await api.getCredits()
            }.ok.body.json.data
        }
    }

    /// Generation metadata (`GET /generation`).
    public struct Generations: Sendable {
        let api: Client

        /// Cost, token counts and provider details of a past generation. `id`
        /// is ``ChatResult``'s `id`.
        public func get(_ id: String) async throws -> Generation {
            try await unwrappingClientError {
                try await api.getGeneration(query: .init(id: id))
            }.ok.body.json.data
        }
    }

    /// The API key used by this client (`GET /key`).
    public struct APIKeys: Sendable {
        let api: Client

        /// Label, limits and usage of the current key.
        public func current() async throws -> APIKeyInfo {
            try await unwrappingClientError {
                try await api.getCurrentKey()
            }.ok.body.json.data
        }
    }
}
