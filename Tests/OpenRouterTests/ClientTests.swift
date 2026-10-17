import Foundation
import HTTPTypes
import Testing

@testable import OpenRouter

@Suite("Client")
struct ClientTests {
    @Test("fromEnvironment reads OPENROUTER_API_KEY")
    func fromEnvironment() throws {
        #expect(throws: MissingAPIKeyError.self) { try OpenRouterClient.fromEnvironment([:]) }
        #expect(throws: MissingAPIKeyError.self) { try OpenRouterClient.fromEnvironment(["OPENROUTER_API_KEY": ""]) }
        _ = try OpenRouterClient.fromEnvironment(["OPENROUTER_API_KEY": "sk-or-x"])
    }

    @Test("platform endpoints unwrap their payloads")
    func platformEndpoints() async throws {
        let transport = MockTransport { _, request in
            switch request.path {
            case "/credits":
                MockTransport.response(json: #"{"data":{"total_credits":10.5,"total_usage":2}}"#)
            case "/models/count":
                MockTransport.response(json: #"{"data":{"count":321}}"#)
            default:
                MockTransport.response(status: .notFound, json: #"{"error":{"code":404,"message":"nope"}}"#)
            }
        }
        let client = OpenRouterClient.mock(transport)

        let credits = try await client.credits.get()
        #expect(credits.totalCredits == 10.5)
        #expect(try await client.models.count() == 321)

        let error = try await #require(throws: OpenRouterError.self) {
            try await client.generations.get("gen-missing")
        }
        #expect(error.kind == .notFound)
        #expect(transport.requests.last?.request.path == "/generation?id=gen-missing")
    }

    @Test("dates decode with and without fractional seconds")
    func lenientDates() throws {
        let transcoder = LenientISO8601DateTranscoder()
        let whole = try transcoder.decode("2027-12-31T23:59:59Z")
        let fractional = try transcoder.decode("2027-12-31T23:59:59.250Z")
        #expect(fractional.timeIntervalSince(whole) == 0.25)
        #expect(try transcoder.decode(transcoder.encode(fractional)) == fractional)
        #expect(throws: DecodingError.self) { try transcoder.decode("yesterday") }
    }

    @Test("non-JSON error bodies keep the raw text")
    func rawErrorBody() {
        let error = OpenRouterError(statusCode: 503, body: Data("upstream down".utf8))
        #expect(error.kind == .serviceUnavailable)
        #expect(error.message == "HTTP 503")
        #expect(error.rawBody == "upstream down")
        #expect(error.isRetryable)
        #expect(error.description == "OpenRouter error 503 (serviceUnavailable): HTTP 503")
    }

    @Test(
        "status codes map to kinds",
        arguments: [
            (400, OpenRouterError.Kind.badRequest), (401, .unauthorized), (402, .paymentRequired),
            (403, .forbidden), (404, .notFound), (408, .requestTimeout), (413, .payloadTooLarge),
            (422, .unprocessableEntity), (429, .rateLimited), (499, .clientClosedRequest),
            (500, .internalServerError), (502, .badGateway), (503, .serviceUnavailable),
            (504, .gatewayTimeout), (524, .edgeNetworkTimeout), (529, .providerOverloaded), (418, .other),
        ]
    )
    func kinds(statusCode: Int, kind: OpenRouterError.Kind) {
        #expect(OpenRouterError(statusCode: statusCode, message: "").kind == kind)
    }
}
