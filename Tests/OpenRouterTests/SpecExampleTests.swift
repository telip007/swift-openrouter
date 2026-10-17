import Foundation
import HTTPTypes
import Testing

@testable import OpenRouter

/// Serves the response examples published in `openapi/openapi.json` and
/// checks that the generated (and patched) types decode them. A spec update
/// whose examples no longer decode fails here before it reaches users.
@Suite("Spec examples")
struct SpecExampleTests {
    private static let specData: Data = {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "openapi/openapi.json")
        guard let data = try? Data(contentsOf: url) else {
            preconditionFailure("Cannot read \(url.path)")
        }
        return data
    }()

    private static func serialized(_ object: Any) throws -> String {
        try #require(String(data: try JSONSerialization.data(withJSONObject: object), encoding: .utf8))
    }

    /// The `200` example for `GET <path>`, re-serialised as JSON.
    private static func example(_ path: String) throws -> String {
        let spec = try #require(try JSONSerialization.jsonObject(with: specData) as? [String: Any])
        let paths = try #require(spec["paths"] as? [String: Any])
        let operation = try #require((paths[path] as? [String: Any])?["get"] as? [String: Any])
        let responses = try #require(operation["responses"] as? [String: Any])
        let content = try #require((responses["200"] as? [String: Any])?["content"] as? [String: Any])
        let json = try #require(content["application/json"] as? [String: Any])
        let schema = json["schema"] as? [String: Any]
        let example = try #require(json["example"] ?? schema?["example"])
        return try serialized(example)
    }

    private func client(_ routes: [String: String]) -> OpenRouterClient {
        .mock(
            MockTransport { _, request in
                let path = request.path?.split(separator: "?").first.map(String.init) ?? ""
                guard let json = routes[path] else {
                    return MockTransport.response(status: .notFound, json: #"{"error":{"code":404,"message":"no"}}"#)
                }
                return MockTransport.response(json: json)
            }
        )
    }

    @Test("GET /key example decodes through apiKey.current()")
    func currentKey() async throws {
        let key = try await client(["/key": Self.example("/key")]).apiKey.current()
        #expect(key.label.hasPrefix("sk-or-"))
        #expect(key.usage >= 0)
    }

    @Test("GET /models example decodes as published")
    func modelsExampleAsPublished() async throws {
        let client = client(["/models": try Self.example("/models")])
        // Upstream's example omits the required `links` and `total_count`; the live API
        // returns it (checked 2026-10-17). This starts failing, i.e. passing,
        // once upstream fixes the example. Then remove `completingPage` below.
        await withKnownIssue("Spec example for GET /models lacks required 'links' and 'total_count'") {
            _ = try await client.models.list()
        }
    }

    @Test("GET /models example decodes through models.list() and models.all()")
    func models() async throws {
        let client = client(["/models": try Self.completingPage(Self.example("/models"))])
        let page = try await client.models.list()
        #expect(!page.data.isEmpty)
        #expect(try await client.models.all().count == page.data.count)
    }

    @Test("GET /model/{author}/{slug} example decodes through models.get()")
    func model() async throws {
        let model = try await client(["/model/openai/gpt-4": Self.example("/model/{author}/{slug}")])
            .models.get("openai/gpt-4")
        #expect(!model.id.isEmpty)
    }

    @Test("GET /generation example decodes through generations.get()")
    func generation() async throws {
        let generation = try await client(["/generation": Self.example("/generation")]).generations.get("gen-1")
        #expect(!generation.id.isEmpty)
    }

    @Test("GET /credits example decodes through credits.get()")
    func credits() async throws {
        let credits = try await client(["/credits": Self.example("/credits")]).credits.get()
        #expect(credits.totalCredits >= credits.totalUsage)
    }

    @Test("models.all() follows pagination until there is no next page")
    func pagination() async throws {
        let model = try Self.firstModel()
        let transport = MockTransport { attempt, _ in
            let next = attempt == 0 ? #""/api/v1/models?offset=1""# : "null"
            return MockTransport.response(
                json: #"{"data":[\#(model)],"links":{"next":\#(next)},"total_count":2}"#
            )
        }
        let models = try await OpenRouterClient.mock(transport).models.all()
        #expect(models.count == 2)
        #expect(transport.requests.map(\.request.path) == ["/models", "/models?offset=1"])
    }

    private static func completingPage(_ page: String) throws -> String {
        var object = try #require(try JSONSerialization.jsonObject(with: Data(page.utf8)) as? [String: Any])
        object["links"] = object["links"] ?? ["next": NSNull()]
        object["total_count"] = object["total_count"] ?? (object["data"] as? [Any])?.count ?? 0
        return try serialized(object)
    }

    private static func firstModel() throws -> String {
        let page = try #require(
            try JSONSerialization.jsonObject(with: Data(example("/models").utf8)) as? [String: Any]
        )
        let first = try #require((page["data"] as? [Any])?.first)
        return try serialized(first)
    }
}
