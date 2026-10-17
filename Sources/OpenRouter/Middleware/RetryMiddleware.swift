import Foundation
import HTTPTypes
import OpenAPIRuntime

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(AsyncHTTPClient)
import AsyncHTTPClient
#endif

/// Retries failed requests according to a ``RetryPolicy``.
struct RetryMiddleware: ClientMiddleware {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    let policy: RetryPolicy
    let clock: ContinuousClock
    let sleep: Sleep
    let random: @Sendable () -> Double

    init(
        policy: RetryPolicy,
        clock: ContinuousClock = .continuous,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
        random: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) },
    ) {
        self.policy = policy
        self.clock = clock
        self.sleep = sleep
        self.random = random
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?),
    ) async throws -> (HTTPResponse, HTTPBody?) {
        // A streamed request body can only be sent once.
        if let body, body.iterationBehavior == .single {
            return try await next(request, body, baseURL)
        }

        let start = clock.now
        var attempt = 0
        while true {
            do {
                let (response, responseBody) = try await next(request, body, baseURL)
                guard policy.retryableStatusCodes.contains(response.status.code) else {
                    return (response, responseBody)
                }
                let delay = Self.retryAfter(from: response) ?? policy.delay(forAttempt: attempt, random: random)
                guard clock.now - start + delay < policy.maxElapsedTime else {
                    return (response, responseBody)
                }
                try await sleep(delay)
            } catch {
                guard policy.retryConnectionErrors, Self.isTransient(error, method: request.method) else {
                    throw error
                }
                let delay = policy.delay(forAttempt: attempt, random: random)
                guard clock.now - start + delay < policy.maxElapsedTime else {
                    throw error
                }
                try await sleep(delay)
            }
            attempt += 1
        }
    }

    /// Parses `Retry-After-Ms` (milliseconds) or `Retry-After` (seconds or an
    /// HTTP date).
    static func retryAfter(from response: HTTPResponse, now: Date = Date()) -> Duration? {
        if let value = response.headerFields[.retryAfterMilliseconds], let milliseconds = Int(value), milliseconds >= 0
        {
            return .milliseconds(milliseconds)
        }
        guard let value = response.headerFields[.retryAfter] else {
            return nil
        }
        if let seconds = Int(value) {
            return seconds >= 0 ? .seconds(seconds) : nil
        }
        guard let date = httpDateFormatter().date(from: value) else {
            return nil
        }
        return .seconds(max(0, date.timeIntervalSince(now)))
    }

    /// Network failures worth retrying. A dropped connection is only retried
    /// for idempotent methods since the server may already have acted on the
    /// request.
    static func isTransient(_ error: any Error, method: HTTPRequest.Method) -> Bool {
        // The generated client wraps transport errors before middlewares see them.
        if let clientError = error as? ClientError {
            return isTransient(clientError.underlyingError, method: method)
        }
        let idempotent = [.get, .head, .options, .put, .delete].contains(method)
        #if canImport(AsyncHTTPClient)
        if let httpClientError = error as? HTTPClientError {
            switch httpClientError {
            case .connectTimeout, .readTimeout, .writeTimeout:
                return true
            case .remoteConnectionClosed:
                return idempotent
            default:
                return false
            }
        }
        #endif
        guard let urlError = error as? URLError else {
            return false
        }
        switch urlError.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .notConnectedToInternet:
            return true
        case .networkConnectionLost:
            return idempotent
        default:
            return false
        }
    }

    /// `DateFormatter` isn't `Sendable`, so make one per (rare) use.
    private static func httpDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }
}
