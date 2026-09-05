import Foundation

enum MCPJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([MCPJSONValue])
    case object([String: MCPJSONValue])

    var arrayValue: [MCPJSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    var objectValue: [String: MCPJSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    init(from decoder: Decoder) throws {
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
        } else if let value = try? container.decode([MCPJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: MCPJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

enum MCPToolError: String, Error, Equatable, Sendable {
    case disabled = "MCP_DISABLED"
    case storeUnavailable = "STORE_UNAVAILABLE"
    case invalidArgument = "INVALID_ARGUMENT"
    case invalidCursor = "INVALID_CURSOR"
    case decodeFailed = "DECODE_FAILED"

    var retryable: Bool {
        switch self {
        case .storeUnavailable:
            true
        default:
            false
        }
    }

    var safeMessage: String {
        switch self {
        case .disabled:
            "AI access is disabled in MonMon settings."
        case .storeUnavailable:
            "The MonMon data snapshot is unavailable. Open MonMon to refresh it."
        case .invalidArgument:
            "One or more tool arguments are invalid."
        case .invalidCursor:
            "The pagination cursor is invalid or belongs to another tool."
        case .decodeFailed:
            "A stored record could not be decoded safely."
        }
    }

    var payload: [String: MCPJSONValue] {
        [
            "error": .object([
                "code": .string(rawValue),
                "message": .string(safeMessage),
                "retryable": .bool(retryable),
            ])
        ]
    }
}

struct MCPRecord: Equatable, Sendable {
    let recordType: String
    let id: UUID
    let sortDate: Date
    let fields: [String: MCPJSONValue]
}
