import Foundation
import HTTPTypes
import OpenAPIRuntime
import Synchronization
import Testing

@testable import OpenRouter

@Suite("Retries")
struct RetryTests {
    /// Records requested delays instead of sleeping.
    final class SleepRecorder: Sendable {
        private let delays = Mutex<[Duration]>([])
        var recorded: [Duration] { delays.withLock { $0 } }
        func sleep(_ duration: Duration) { delays.withLock { $0.append(duration) } }
    }

    private func client(_ transport: MockTransport, policy: RetryPolicy, sleeper: SleepRecorder) -> Client {
        Client(
            serverURL: .openRouterProduction,
            transport: transport,
            middlewares: [
                ErrorMiddleware(),
                RetryMiddleware(policy: policy, sleep: { sleeper.sleep($0) }, random: { 0.75 }),
            ],
        )
    }

    @Test("retries 5xx until success, using backoff delays")
    func retriesServerErrors() async throws {
        let transport = MockTransport { attempt, _ in
            attempt < 2
                ? MockTransport.response(status: .serviceUnavailable, json: "{}")
                : MockTransport.response(json: #"{"data":{"count":7}}"#)
        }
        let sleeper = SleepRecorder()
        let output = try await client(transport, policy: .default, sleeper: sleeper).listModelsCount()

        #expect(try output.ok.body.json.data.count == 7)
        #expect(transport.requests.count == 3)
        // 0.5s * 1^1.5 and 0.5s * 2^1.5, each +18.75% jitter (random == 0.75).
        #expect(sleeper.recorded.map { ($0.seconds * 1000).rounded() } == [594, 1679])
    }

    @Test("Retry-After headers override the backoff")
    func honoursRetryAfter() async throws {
        let transport = MockTransport { attempt, _ in
            switch attempt {
            case 0: MockTransport.response(status: .tooManyRequests, json: "{}", headers: [.retryAfter: "3"])
            case 1:
                MockTransport.response(status: .tooManyRequests, json: "{}", headers: [.retryAfterMilliseconds: "250"])
            default: MockTransport.response(json: #"{"data":{"count":1}}"#)
            }
        }
        let sleeper = SleepRecorder()
        _ = try await client(transport, policy: .default, sleeper: sleeper).listModelsCount()
        #expect(sleeper.recorded == [.seconds(3), .milliseconds(250)])
    }

    @Test("4xx responses are not retried")
    func doesNotRetryClientErrors() async throws {
        let transport = MockTransport(status: .badRequest, json: #"{"error":{"code":400,"message":"bad"}}"#)
        let sleeper = SleepRecorder()
        await #expect(throws: ClientError.self) {
            try await client(transport, policy: .default, sleeper: sleeper).listModelsCount()
        }
        #expect(transport.requests.count == 1)
    }

    @Test("gives up once maxElapsedTime would be exceeded and surfaces the last error")
    func givesUp() async throws {
        let transport = MockTransport(status: .badGateway, json: #"{"error":{"code":502,"message":"down"}}"#)
        let policy = RetryPolicy(maxElapsedTime: .seconds(2))
        let sleeper = SleepRecorder()
        let error = await #expect(throws: ClientError.self) {
            try await client(transport, policy: policy, sleeper: sleeper).listModelsCount()
        }
        #expect((error?.underlyingError as? OpenRouterError)?.kind == .badGateway)
        // Sleeps are mocked, so only the next delay counts against the budget:
        // 0.59s and 1.68s fit into 2s, the third delay (3.08s) does not.
        #expect(transport.requests.count == 3)
    }

    @Test("transient network errors are retried, others are not")
    func networkErrors() async throws {
        let transport = MockTransport { attempt, _ in
            if attempt == 0 { throw URLError(.timedOut) }
            return MockTransport.response(json: #"{"data":{"count":1}}"#)
        }
        _ = try await client(transport, policy: .default, sleeper: SleepRecorder()).listModelsCount()
        #expect(transport.requests.count == 2)

        #expect(RetryMiddleware.isTransient(URLError(.networkConnectionLost), method: .get))
        #expect(!RetryMiddleware.isTransient(URLError(.networkConnectionLost), method: .post))
        #expect(!RetryMiddleware.isTransient(URLError(.badURL), method: .get))
        #expect(!RetryMiddleware.isTransient(CancellationError(), method: .get))
    }

    @Test("RetryPolicy.disabled never retries")
    func noneNeverRetries() async throws {
        let transport = MockTransport(status: .internalServerError, json: "{}")
        await #expect(throws: ClientError.self) {
            try await client(transport, policy: .disabled, sleeper: SleepRecorder()).listModelsCount()
        }
        #expect(transport.requests.count == 1)
    }

    @Test("Retry-After accepts HTTP dates")
    func retryAfterDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let response = HTTPResponse(
            status: .tooManyRequests,
            headerFields: [.retryAfter: "Tue, 14 Nov 2023 22:13:30 GMT"],
        )
        #expect(RetryMiddleware.retryAfter(from: response, now: now) == .seconds(10))
    }

    @Test("backoff delays are capped by maxInterval")
    func backoffCap() {
        let policy = RetryPolicy(maxInterval: .seconds(2))
        #expect(policy.delay(forAttempt: 10, random: { 0.75 }) == .seconds(2))
    }
}
