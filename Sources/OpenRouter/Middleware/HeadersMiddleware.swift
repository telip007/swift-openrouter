import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Adds authentication, attribution and user-agent headers to every request.
struct HeadersMiddleware: ClientMiddleware {
    static let userAgent = "swift-openrouter/0.1.0"

    let apiKey: String
    let appURL: String?
    let appTitle: String?

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?),
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(apiKey)"
        request.headerFields[.userAgent] = Self.userAgent
        // Per-request values set through the generated `Input.Headers` win.
        if let appURL, request.headerFields[.httpReferer] == nil {
            request.headerFields[.httpReferer] = appURL
        }
        if let appTitle, request.headerFields[.openRouterTitle] == nil {
            request.headerFields[.openRouterTitle] = appTitle
        }
        return try await next(request, body, baseURL)
    }
}

extension HTTPField.Name {
    static let httpReferer = Self.known("HTTP-Referer")
    static let openRouterTitle = Self.known("X-OpenRouter-Title")
    static let retryAfterMilliseconds = Self.known("Retry-After-Ms")

    private static func known(_ name: String) -> Self {
        guard let field = Self(name) else {
            preconditionFailure("Invalid HTTP header name literal: \(name)")
        }
        return field
    }
}
