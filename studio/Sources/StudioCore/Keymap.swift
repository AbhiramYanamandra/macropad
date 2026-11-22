import Foundation

public enum JSON: Codable, Equatable, Sendable {
    case object([String: JSON]), array([JSON]), string(String), integer(Int64), number(Double), bool(Bool), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int64.self) { self = .integer(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSON].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSON].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let x): try c.encode(x)
        case .array(let x): try c.encode(x)
        case .string(let x): try c.encode(x)
        case .integer(let x): try c.encode(x)
        case .number(let x): try c.encode(x)
        case .bool(let x): try c.encode(x)
        case .null: try c.encodeNil()
        }
    }
    public static func == (lhs: JSON, rhs: JSON) -> Bool {
        switch (lhs,rhs) {
        case (.object(let a),.object(let b)): return a == b
        case (.array(let a),.array(let b)): return a == b
        case (.string(let a),.string(let b)): return a == b
        case (.integer(let a),.integer(let b)): return a == b
        case (.number(let a),.number(let b)): return a == b
        case (.integer(let a),.number(let b)), (.number(let b),.integer(let a)): return Int64(exactly:b) == a
        case (.bool(let a),.bool(let b)): return a == b
        case (.null,.null): return true
        default: return false
        }
    }
    public subscript(_ key: String) -> JSON { object[key] ?? .null }
    public var object: [String: JSON] { if case .object(let x) = self { return x }; return [:] }
    public var array: [JSON] { if case .array(let x) = self { return x }; return [] }
    public var string: String { if case .string(let x) = self { return x }; return "" }
    public var number: Double? { if case .number(let x) = self { return x }; if case .integer(let x) = self { return Double(x) }; return nil }
    public var bool: Bool? { if case .bool(let x) = self { return x }; return nil }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

public struct StudioError: LocalizedError, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct Keymap: Equatable, Sendable {
    public private(set) var value: JSON
    public init(data: Data) throws { value = try JSONDecoder().decode(JSON.self, from: data); try validate() }
    public var layers: [JSON] { value["layers"].array }
    public var knob: Bool { value["settings"]["knob"].bool ?? false }
    public var combos: [JSON] { value["combos"].array }
    public func encoded() throws -> Data { try validate(); return try value.encoded() }
    public func action(layer: Int, key: Int) -> JSON { layers[layer]["keys"].array[key] }
    public mutating func setPressed(_ action: JSON, layer: Int, key: Int) throws {
        guard layers.indices.contains(layer), (0..<9).contains(key) else { throw StudioError("Choose an existing key.") }
        var root = value.object, list = layers, item = list[layer].object, keys = list[layer]["keys"].array
        var merged = keys[key].object
        for field in ["type", "key", "mods", "text", "steps", "mode", "layer", "label"] { merged.removeValue(forKey: field) }
        for (field, value) in action.object where field != "hold" { merged[field] = value }
        keys[key] = .object(merged); item["keys"] = .array(keys); list[layer] = .object(item); root["layers"] = .array(list)
        let candidate = try Keymap(data: JSON.object(root).encoded())
        self = candidate
    }
    public static let keyNames: [String] = {
        guard let url = Bundle.module.url(forResource: "key-names", withExtension: "json"),
              let data = try? Data(contentsOf: url), let names = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return names
    }()
    public static let modifiers = ["LCTL", "LSFT", "LALT", "LCMD", "RCTL", "RSFT", "RALT", "RCMD"]
    public func validate() throws {
        func require(_ condition: Bool, _ message: String) throws { if !condition { throw StudioError(message) } }
        func ascii(_ s: String) -> Bool { s.unicodeScalars.allSatisfy { (32...126).contains(Int($0.value)) } }
        try require(value["version"].number == 1, "Only version 1 keymaps can be edited. The file was not changed.")
        try require((1...8).contains(layers.count), "The keymap needs 1–8 layers.")
        if value.object["settings"] != nil { try require(value["settings"].object.count > 0 || value["settings"] == .object([:]), "Settings must be an object.") }
        let settings = value["settings"].object
        if let knob = settings["knob"] { try require(knob.bool != nil, "Knob fitted must be true or false.") }
        for key in ["hold_ms", "combo_timeout", "toast_ms", "dim_s", "off_s", "led_brightness"] {
            if let field = settings[key] {
                guard let n = field.number else { throw StudioError("\(key) must be a number.") }
                try require(n.isFinite && n >= 0 && (key != "led_brightness" || n <= 1), "Invalid \(key).")
                if key != "led_brightness" { try require(n.rounded() == n, "\(key) must be a whole number.") }
            }
        }
        func chord(_ a: JSON) throws {
            try require(Self.keyNames.contains(a["key"].string), "Unknown firmware key: \(a["key"].string)")
            if a.object["mods"] != nil {
                guard case .array(let mods) = a["mods"] else { throw StudioError("Modifiers must be a list.") }
                try require(mods.allSatisfy { Self.modifiers.contains($0.string) }, "Unknown modifier.")
            }
        }
        func action(_ a: JSON, depth: Int = 0) throws {
            if a == .null { return }
            guard case .object = a, depth < 8 else { throw StudioError("Invalid or deeply nested action.") }
            if let label = a.object["label"] { try require(label.string.count <= 10 && ascii(label.string) && label == .string(label.string), "Labels must be ASCII and at most 10 characters.") }
            switch a.object["type"]?.string ?? "none" {
            case "none": break
            case "key": try chord(a)
            case "text": try require(a["text"] == .string(a["text"].string) && a["text"].string.unicodeScalars.allSatisfy { $0.value < 128 }, "Typed text must be ASCII.")
            case "layer":
                try require(["to", "mo", "tg", "df"].contains(a.object["mode"]?.string ?? "to"), "Unknown layer mode.")
                let target = a.object["layer"] ?? .string("next")
                try require(["next", "prev"].contains(target.string) || (target.number.map { $0.rounded() == $0 && $0 >= 0 && $0 < Double(layers.count) } ?? false), "Layer target does not exist.")
            case "macro":
                guard case .array(let steps) = a["steps"] else { throw StudioError("Macro steps must be a list.") }
                for step in steps {
                    switch step["do"].string {
                    case "tap", "press", "release": try chord(step)
                    case "delay": try require(step["ms"].number.map { $0 >= 0 && $0.rounded() == $0 } ?? false, "Macro delay must be a non-negative whole number.")
                    case "text": try require(step["text"] == .string(step["text"].string) && step["text"].string.unicodeScalars.allSatisfy { $0.value < 128 }, "Macro text must be ASCII.")
                    default: throw StudioError("Unknown macro step.")
                    }
                }
            default: throw StudioError("Unsupported action type: \(a["type"].string). Preserved on disk.")
            }
            if let hold = a.object["hold"] { try action(hold, depth: depth + 1) }
        }
        for layer in layers {
            try require(layer["keys"].array.count == 9, "Every layer needs nine keys.")
            try require(layer["name"].string.count <= 10 && !layer["name"].string.isEmpty && ascii(layer["name"].string), "Layer names need 1–10 ASCII characters.")
            let color = layer["color"].string
            try require(color.isEmpty || (color.count == 7 && color.first == "#" && Int(color.dropFirst(), radix: 16) != nil), "Invalid layer colour.")
            if layer["image"] != .null { try Self.validateRelativePath(layer["image"].string) }
            for key in layer["keys"].array { try action(key) }
            if layer.object["encoder"] != nil { guard case .object = layer["encoder"] else { throw StudioError("Encoder must be an object.") }; }
            for part in ["ccw", "cw", "press"] { try action(layer["encoder"][part]) }
        }
        if value.object["combos"] != nil { guard case .array = value["combos"] else { throw StudioError("Combos must be a list.") }; }
        for combo in combos {
            let coords = combo["keys"].array
            try require(coords.count >= 2 && Set(coords.compactMap(\.number)).count == coords.count && coords.allSatisfy { $0.number.map { $0 >= 0 && $0 < 9 && $0.rounded() == $0 } ?? false }, "Combo positions must be distinct keys 0–8.")
            try action(combo["action"])
        }
    }
    public static func validateRelativePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { throw StudioError("Asset path must stay inside the selected pad.") }
    }
}
