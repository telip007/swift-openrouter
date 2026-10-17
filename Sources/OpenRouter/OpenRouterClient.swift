public import Foundation
public import OpenAPIRuntime

#if canImport(OpenAPIURLSession)
import OpenAPIURLSession
#else
import AsyncHTTPClient
import NIOCore
import OpenAPIAsyncHTTPClient
#endif

/// Entry point to the OpenRouter API.
///
/// ```swift
/// let openRouter = try OpenRouterClient.fromEnvironment()
/// let result = try await openRouter.chat.send(
///     ChatRequest(messages: [.user("Hi!")], model: "openai/gpt-4o-mini")
/// )
/// print(result.text ?? "")
/// ```
///
/// Operations without a convenience wrapper are available on ``api``, the
/// generated low-level client.
public struct OpenRouterClient: Sendable {
    /// The generated client. Every operation in the (filtered) OpenAPI spec is
    /// available here, with the same retry, header and error handling as the
    /// convenience APIs.
    public let api: Client

    /// Chat completions (`POST /chat/completions`).
    public var chat: Chat { Chat(api: api) }
    /// Model catalogue (`/models`).
    public var models: Models { Models(api: api) }
    /// Account credits (`GET /credits`).
    public var credits: Credits { Credits(api: api) }
    /// Generation metadata and cost (`GET /generation`).
    public var generations: Generations { Generations(api: api) }
    /// The API key used by this client (`GET /key`).
    public var apiKey: APIKeys { APIKeys(api: api) }

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - apiKey: An OpenRouter API key (`sk-or-...`).
    ///   - configuration: Server, attribution, retry and timeout settings.
    ///   - transport: The HTTP transport. Defaults to `URLSession`.
    ///   - middlewares: Extra middlewares, run innermost (closest to the
    ///     transport), e.g. for logging.
    public init(
        apiKey: String,
        configuration: Configuration = .init(),
        transport: (any ClientTransport)? = nil,
        middlewares: [any ClientMiddleware] = [],
    ) {
        let transport = transport ?? Self.defaultTransport(timeout: configuration.timeout)
        self.api = Client(
            serverURL: configuration.serverURL,
            configuration: .init(dateTranscoder: LenientISO8601DateTranscoder()),
            transport: transport,
            middlewares: [
                ErrorMiddleware(),
                RetryMiddleware(policy: configuration.retryPolicy),
                HeadersMiddleware(
                    apiKey: apiKey,
                    appURL: configuration.appURL,
                    appTitle: configuration.appTitle,
                ),
            ] + middlewares,
        )
    }

    /// Creates a client using the `OPENROUTER_API_KEY` environment variable.
    ///
    /// - Throws: ``MissingAPIKeyError`` if the variable is unset or empty.
    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        configuration: Configuration = .init(),
        transport: (any ClientTransport)? = nil,
        middlewares: [any ClientMiddleware] = [],
    ) throws(MissingAPIKeyError) -> Self {
        guard let apiKey = environment[MissingAPIKeyError.variable], !apiKey.isEmpty else {
            throw MissingAPIKeyError()
        }
        return Self(
            apiKey: apiKey,
            configuration: configuration,
            transport: transport,
            middlewares: middlewares,
        )
    }

    #if canImport(OpenAPIURLSession)
    private static func defaultTransport(timeout: Duration?) -> any ClientTransport {
        guard let timeout else { return URLSessionTransport() }
        let session = URLSessionConfiguration.default
        // An idle timeout: it resets on every received byte, so it doesn't cut
        // off long-running streams that are still producing output.
        session.timeoutIntervalForRequest = timeout.seconds
        return URLSessionTransport(configuration: .init(session: URLSession(configuration: session)))
    }
    #else
    private static func defaultTransport(timeout: Duration?) -> any ClientTransport {
        // AsyncHTTPClient's timeout bounds the *whole* request, streaming
        // included, so the default must allow for long generations.
        let timeout = timeout ?? .seconds(60 * 60)
        return AsyncHTTPClientTransport(
            configuration: .init(
                client: .shared,
                timeout: .nanoseconds(Int64(timeout.seconds * 1e9)),
            ))
    }
    #endif
}

extension OpenRouterClient {
    /// Client-wide settings.
    public struct Configuration: Sendable {
        /// Base URL of the API.
        public var serverURL: URL
        /// Your app's URL, sent as `HTTP-Referer` for attribution on openrouter.ai.
        public var appURL: String?
        /// Your app's name, sent as `X-OpenRouter-Title` for attribution on openrouter.ai.
        public var appTitle: String?
        /// How failed requests are retried. Use ``RetryPolicy/disabled`` to disable.
        public var retryPolicy: RetryPolicy
        /// Timeout for the default transport. Ignored when a custom transport
        /// is passed.
        ///
        /// On Apple platforms (`URLSession`) this is an idle timeout. On Linux
        /// (AsyncHTTPClient) it bounds the whole request including streaming,
        /// and defaults to one hour.
        public var timeout: Duration?

        /// Creates a configuration.
        public init(
            serverURL: URL = .openRouterProduction,
            appURL: String? = nil,
            appTitle: String? = nil,
            retryPolicy: RetryPolicy = .default,
            timeout: Duration? = nil,
        ) {
            self.serverURL = serverURL
            self.appURL = appURL
            self.appTitle = appTitle
            self.retryPolicy = retryPolicy
            self.timeout = timeout
        }
    }
}

extension URL {
    /// `https://openrouter.ai/api/v1`
    public static let openRouterProduction: URL = {
        guard let url = URL(string: "https://openrouter.ai/api/v1") else {
            preconditionFailure("Invalid OpenRouter server URL literal")
        }
        return url
    }()
}

/// Thrown by ``OpenRouterClient/fromEnvironment(_:configuration:transport:middlewares:)``
/// when no API key is configured.
public struct MissingAPIKeyError: Error, CustomStringConvertible {
    static let variable = "OPENROUTER_API_KEY"

    /// A human-readable description of the error.
    public var description: String {
        "\(Self.variable) is not set. Create a key at https://openrouter.ai/keys"
    }
}
