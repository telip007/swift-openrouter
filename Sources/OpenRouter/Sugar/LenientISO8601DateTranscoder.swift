import Foundation
import OpenAPIRuntime

/// Decodes ISO 8601 timestamps with or without fractional seconds.
///
/// OpenRouter mixes both forms, even within one response
/// (`"2026-10-12T00:00:00.000Z"` and `"2027-12-31T23:59:59Z"` in `GET /key`),
/// while the runtime's default `.iso8601` transcoder rejects fractional
/// seconds.
struct LenientISO8601DateTranscoder: DateTranscoder {
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let whole = Date.ISO8601FormatStyle()

    func encode(_ date: Date) throws -> String {
        Self.fractional.format(date)
    }

    func decode(_ string: String) throws -> Date {
        if let date = try? Self.fractional.parse(string) {
            return date
        }
        do {
            return try Self.whole.parse(string)
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Expected an ISO 8601 date, got '\(string)'")
            )
        }
    }
}
