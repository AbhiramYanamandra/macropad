import Foundation
import CryptoKit
import Darwin

public enum SyncPhase: String, CaseIterable, Sendable {
    case preflight, backup, staging, stagedReadback, conflictCheck, replacement, finalReadback
}
public enum SyncFailure: LocalizedError {
    case unchanged(String), unknown(String)
    public var errorDescription: String? {
        switch self {
        case .unchanged(let reason): return "Not saved. \(reason) The previous keymap was not replaced."
        case .unknown(let reason): return "Sync outcome unknown. \(reason) Reopen the same pad to inspect its keymap before retrying. Your draft and backup are retained."
        }
    }
}
public protocol PadFiles {
    func read(_ url: URL) throws -> Data
    func writeNew(_ data: Data, to url: URL) throws
    func replace(_ staged: URL, target: URL) throws
    func identity(_ root: URL) throws -> String
    func preflight(_ root: URL, bytes: Int) throws
}
public struct LocalPadFiles: PadFiles {
    public init() {}
    public func read(_ url: URL) throws -> Data { try Data(contentsOf: url) }
    public func writeNew(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }
    public func replace(_ staged: URL, target: URL) throws {
        let result = staged.withUnsafeFileSystemRepresentation { source in
            target.withUnsafeFileSystemRepresentation { dest in Darwin.rename(source!, dest!) }
        }
        if result != 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
    public func identity(_ root: URL) throws -> String {
        let attrs = try FileManager.default.attributesOfItem(atPath: root.path)
        guard attrs[.type] as? FileAttributeType == .typeDirectory else { throw StudioError("The selected folder is unavailable.") }
        if let volume = try root.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString {
            return "\(volume):\(attrs[.systemFileNumber] ?? "?")"
        }
        return "local:\(attrs[.systemNumber] ?? "?"):\(attrs[.systemFileNumber] ?? "?")"
    }
    public func preflight(_ root: URL, bytes: Int) throws {
        guard FileManager.default.isWritableFile(atPath: root.path) else { throw StudioError("The selected pad is read-only.") }
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: root.path)
        guard let free = attrs[.systemFreeSize] as? NSNumber, free.int64Value >= Int64(bytes + 4096) else { throw StudioError("There is not enough free space on the pad.") }
    }
}
public struct PadSnapshot: Sendable {
    public let root: URL
    public let identity: String
    public let bytes: Data
    public let keymap: Keymap
    public var fingerprint: String { digest(bytes) }
}
public func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

public actor PadStore {
    private let files: PadFiles
    private let recovery: URL
    private let checkpoint: (SyncPhase) throws -> Void
    public init(recovery: URL, files: PadFiles = LocalPadFiles(), checkpoint: @escaping (SyncPhase) throws -> Void = { _ in }) {
        self.files = files; self.recovery = recovery; self.checkpoint = checkpoint
    }
    public static func safeChild(_ root: URL, path: String) throws -> URL {
        try Keymap.validateRelativePath(path)
        let child = root.appendingPathComponent(path)
        guard child.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { throw StudioError("A pad file points outside the selected folder.") }
        // Reject symlink components, including a symlink that stays inside the pad.
        var cursor = root
        for part in path.split(separator: "/") {
            cursor.appendPathComponent(String(part))
            if (try? FileManager.default.attributesOfItem(atPath: cursor.path)[.type]) as? FileAttributeType == .typeSymbolicLink {
                throw StudioError("Symlinks are not supported on the pad.")
            }
        }
        return child
    }
    public func open(_ selected: URL) throws -> PadSnapshot {
        let root = selected.standardizedFileURL.resolvingSymlinksInPath()
        let identity = try files.identity(root)
        for sentinel in ["code.py", "config_loader.py"] {
            let bytes = try files.read(Self.safeChild(root, path: sentinel))
            guard !bytes.isEmpty else { throw StudioError("The selected folder does not contain the current macropad firmware.") }
        }
        let bytes = try files.read(Self.safeChild(root, path: "keymap.json"))
        guard bytes.count <= 1_048_576 else { throw StudioError("Keymap is too large.") }
        let map = try Keymap(data: bytes)
        try validateAssets(map, at: root)
        return PadSnapshot(root: root, identity: identity, bytes: bytes, keymap: map)
    }
    private func validateAssets(_ map: Keymap, at root: URL) throws {
        for layer in map.layers where layer["image"] != .null {
            let image = try files.read(Self.safeChild(root, path: layer["image"].string))
            try Self.validateBMP(image)
        }
    }
    public static func validateBMP(_ data: Data) throws {
        let b = [UInt8](data)
        func word(_ i: Int) -> UInt32 { UInt32(b[i]) | UInt32(b[i+1]) << 8 | UInt32(b[i+2]) << 16 | UInt32(b[i+3]) << 24 }
        guard b.count >= 62, b[0] == 66, b[1] == 77,
              word(14) >= 40, word(18) == 128, (word(22) == 32 || word(22) == UInt32(bitPattern: -32)),
              b[26] == 1, b[27] == 0, b[28] == 1, b[29] == 0, word(30) == 0,
              Int(word(10)) >= 62, Int(word(14)) + 22 <= Int(word(10)), Int(word(10)) <= b.count - 512 else { throw StudioError("Layer images must be uncompressed 128×32 one-bit BMPs.") }
    }
    public func isPresent(_ snapshot: PadSnapshot) -> Bool { (try? files.identity(snapshot.root)) == snapshot.identity }
    public func sync(_ map: Keymap, from snapshot: PadSnapshot) throws -> PadSnapshot {
        let data = try map.encoded()
        guard data.count <= 1_048_576 else { throw StudioError("The draft is too large to sync.") }
        var replacementStarted = false
        do {
            try checkpoint(.preflight)
            let current = try open(snapshot.root)
            guard current.identity == snapshot.identity else { throw StudioError("The selected volume changed.") }
            try validateAssets(map, at: snapshot.root)
            // A reconnect after a completed write needs no duplicate replacement.
            if current.bytes == data { return current }
            guard current.bytes == snapshot.bytes else { throw StudioError("The keymap changed outside Studio. Reopen it before syncing.") }
            try files.preflight(snapshot.root, bytes: data.count)
            let id = UUID().uuidString
            try checkpoint(.backup)
            try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
            let transaction = recovery.appendingPathComponent(id, isDirectory: true)
            try FileManager.default.createDirectory(at: transaction, withIntermediateDirectories: true)
            try snapshot.bytes.write(to: transaction.appendingPathComponent("previous-keymap.json"), options: .atomic)
            try data.write(to: transaction.appendingPathComponent("draft-keymap.json"), options: .atomic)
            let receipt: JSON = .object(["version": .number(1), "volume": .string(snapshot.identity), "baseline": .string(snapshot.fingerprint), "candidate": .string(digest(data)), "state": .string("prepared")])
            try receipt.encoded().write(to: transaction.appendingPathComponent("receipt.json"), options: .atomic)
            let staged = try Self.safeChild(snapshot.root, path: ".studio-\(id).json")
            let target = try Self.safeChild(snapshot.root, path: "keymap.json")
            try checkpoint(.staging)
            try files.writeNew(data, to: staged)
            try checkpoint(.stagedReadback)
            let readback = try files.read(staged)
            guard readback == data else { throw StudioError("The staged file did not match the draft.") }
            _ = try Keymap(data: readback)
            try checkpoint(.conflictCheck)
            let latest = try open(snapshot.root)
            guard latest.identity == snapshot.identity, latest.bytes == snapshot.bytes else { throw StudioError("The pad or keymap changed during sync.") }
            try checkpoint(.replacement)
            replacementStarted = true
            try files.replace(staged, target: target)
            try checkpoint(.finalReadback)
            let final = try open(snapshot.root)
            guard final.identity == snapshot.identity, final.bytes == data else { throw StudioError("Final readback did not match the draft.") }
            return final
        } catch {
            if replacementStarted { throw SyncFailure.unknown(error.localizedDescription) }
            throw SyncFailure.unchanged(error.localizedDescription)
        }
    }
}

public struct MonochromeBitmap {
    public let pixels: [Bool]
    public init(data: Data) throws {
        try PadStore.validateBMP(data)
        let b=[UInt8](data)
        func word(_ i:Int)->UInt32 { UInt32(b[i]) | UInt32(b[i+1])<<8 | UInt32(b[i+2])<<16 | UInt32(b[i+3])<<24 }
        let palette=14+Int(word(14)), offset=Int(word(10))
        guard palette+8 <= offset else { throw StudioError("BMP palette is missing.") }
        let light=(0..<2).map { index in let p=palette+index*4; return Int(b[p])+Int(b[p+1])+Int(b[p+2]) > 382 }
        let topDown=Int32(bitPattern:word(22)) < 0
        pixels=(0..<4096).map { index in
            let x=index%128, y=index/128, row=topDown ? y : 31-y
            let value=(b[offset+row*16+x/8] >> (7-x%8)) & 1
            return light[Int(value)]
        }
    }
}
