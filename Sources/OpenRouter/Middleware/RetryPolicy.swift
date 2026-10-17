import Foundation

/// Exponential backoff with jitter.
///
/// The delay before retry *n* (0-based) is
/// `initialInterval * (n + 1) ^ exponent`, randomly shifted by up to ±25 % and
/// capped at ``maxInterval``. `Retry-After-Ms` and `Retry-After` response
/// headers take precedence over the computed delay.
public struct RetryPolicy: Hashable, Sendable {
    /// Delay before the first retry.
    public var initialInterval: Duration
    /// Upper bound for any single delay.
    public var maxInterval: Duration
    /// Growth exponent of the delay.
    public var exponent: Double
    /// Stop retrying once this much time has passed since the first attempt.
    public var maxElapsedTime: Duration
    /// HTTP status codes that trigger a retry.
    public var retryableStatusCodes: Set<Int>
    /// Whether transient network failures (timeouts, unreachable host, lost
    /// connection) are retried.
    public var retryConnectionErrors: Bool

    /// Creates a policy.
    public init(
        initialInterval: Duration = .milliseconds(500),
        maxInterval: Duration = .seconds(60),
        exponent: Double = 1.5,
        maxElapsedTime: Duration = .seconds(300),
        retryableStatusCodes: Set<Int> = Self.defaultRetryableStatusCodes,
        retryConnectionErrors: Bool = true,
    ) {
        self.initialInterval = initialInterval
        self.maxInterval = maxInterval
        self.exponent = exponent
        self.maxElapsedTime = maxElapsedTime
        self.retryableStatusCodes = retryableStatusCodes
        self.retryConnectionErrors = retryConnectionErrors
    }

    /// `429` and all `5xx` codes.
    ///
    /// OpenRouter sends `Retry-After` with 429 and 503, so waiting and retrying
    /// is the right default. 402 is never retried automatically; see
    /// ``OpenRouterError/retryAfter``.
    public static let defaultRetryableStatusCodes: Set<Int> = Set([429]).union(500...599)

    /// 500 ms initial delay, growing to at most 60 s, giving up after 5 minutes.
    public static let `default` = Self()

    /// Never retry. (Not named `none` to avoid confusion with `Optional.none`.)
    public static let disabled = Self(maxElapsedTime: .zero, retryableStatusCodes: [], retryConnectionErrors: false)

    /// The backoff delay before retry number `attempt` (0-based), before any
    /// `Retry-After` override.
    ///
    /// - Parameters:
    ///   - attempt: The 0-based retry number.
    ///   - random: Returns a value in `0..<1`; injectable for tests.
    /// - Returns: The delay, between ``initialInterval`` and ``maxInterval``.
    func delay(forAttempt attempt: Int, random: () -> Double = { Double.random(in: 0..<1) }) -> Duration {
        let initial = initialInterval.seconds
        var interval = initial * pow(Double(attempt + 1), exponent)
        let jitter = random() * 0.25 * interval
        interval += random() < 0.5 ? -jitter : jitter
        if interval <= 0 {
            interval = initial
        }
        return .seconds(min(interval, maxInterval.seconds))
    }
}

extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
