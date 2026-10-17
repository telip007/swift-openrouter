public import OpenAPIRuntime

/// A JSON value that can be written as a Swift literal.
///
/// Used for JSON Schemas in tool definitions:
///
/// ```swift
/// let schema: [String: JSONValue] = [
///     "type": "object",
///     "properties": ["path": ["type": "string"]],
///     "required": ["path"],
/// ]
/// ```
public enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([Self])
    case object([String: Self])

    /// The generated client's representation of the same value.
    public var container: OpenAPIValueContainer {
        do {
            return try OpenAPIValueContainer(unvalidatedValue: unvalidatedValue)
        } catch {
            preconditionFailure("Every JSONValue is representable as OpenAPIValueContainer: \(error)")
        }
    }

    private var unvalidatedValue: (any Sendable)? {
        switch self {
        case .null: nil
        case .bool(let value): value
        case .int(let value): value
        case .double(let value): value
        case .string(let value): value
        case .array(let values): values.map(\.unvalidatedValue)
        case .object(let values): values.mapValues(\.unvalidatedValue)
        }
    }
}

extension JSONValue: Codable {
    /// Decodes any JSON value.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([Self].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: Self].self))
        }
    }

    /// Encodes the value as JSON.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    /// Creates `null`.
    public init(nilLiteral _: ()) { self = .null }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    /// Creates a boolean.
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    /// Creates an integer.
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension JSONValue: ExpressibleByFloatLiteral {
    /// Creates a floating-point number.
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension JSONValue: ExpressibleByStringLiteral {
    /// Creates a string.
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    /// Creates an array.
    public init(arrayLiteral elements: Self...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    /// Creates an object.
    public init(dictionaryLiteral elements: (String, Self)...) {
        self = .object(Dictionary(elements) { _, last in last })
    }
}
