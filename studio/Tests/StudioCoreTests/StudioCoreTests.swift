import XCTest
@testable import StudioCore

private let repo = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
private func fixture() throws -> Data { try Data(contentsOf:repo.appendingPathComponent("keymap.json")) }
private func altered(_ data:Data, _ edit:(inout [String:JSON])->Void) throws -> Data {
    var root = try JSONDecoder().decode(JSON.self,from:data).object
    edit(&root); return try JSON.object(root).encoded()
}
private final class FaultFiles: PadFiles {
    let local = LocalPadFiles()
    var replacementCount = 0, failPreflight = false, readOnly = false, partialWrite = false, badStaging = false, disconnectAfterReplace = false, changedIdentity = false
    func read(_ url:URL) throws -> Data {
        if disconnectAfterReplace && replacementCount > 0 { throw POSIXError(.ENODEV) }
        if badStaging && url.lastPathComponent.hasPrefix(".studio-") { return Data("{".utf8) }
        return try local.read(url)
    }
    func writeNew(_ data:Data,to url:URL) throws { if partialWrite { try Data(data.prefix(20)).write(to:url); throw POSIXError(.ENODEV) }; try local.writeNew(data,to:url) }
    func replace(_ staged:URL,target:URL) throws { replacementCount += 1; try local.replace(staged,target:target) }
    func identity(_ root:URL) throws -> String { changedIdentity ? "another-volume" : try local.identity(root) }
    func preflight(_ root:URL,bytes:Int) throws { if readOnly { throw POSIXError(.EROFS) }; if failPreflight { throw POSIXError(.ENOSPC) }; try local.preflight(root,bytes:bytes) }
}
final class StudioCoreTests: XCTestCase {
    var temporary:URL!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent("StudioTests-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:temporary,withIntermediateDirectories:true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at:temporary) }
    func mockPad() throws -> URL {
        let pad=temporary.appendingPathComponent("CIRCUITPY")
        try FileManager.default.createDirectory(at:pad.appendingPathComponent("lib"),withIntermediateDirectories:true)
        for name in ["code.py","config_loader.py","keymap.json","lib/goku.bmp","lib/manandmountain.bmp","lib/turbulence.bmp"] {
            try FileManager.default.copyItem(at:repo.appendingPathComponent(name),to:pad.appendingPathComponent(name))
        }
        return pad
    }
    func store(_ files:PadFiles = LocalPadFiles(),checkpoint:@escaping(SyncPhase)throws->Void = {_ in}) -> PadStore {
        PadStore(recovery:temporary.appendingPathComponent("Recovery"),files:files,checkpoint:checkpoint)
    }
    func edited(_ map:Keymap) throws -> Keymap {
        var next=map
        try next.setPressed(.object(["type":.string("key"),"key":.string("A"),"label":.string("TEST"),"mods":.array([.string("LCMD")])]),layer:0,key:0)
        return next
    }
    func testLegacyAndUnknownJSONPreserved() throws {
        let data=try altered(fixture()) { root in
            var settings=root["settings"]!.object; settings.removeValue(forKey:"knob"); root["settings"] = .object(settings)
            root["future"] = .object(["nested":.array([.bool(true),.number(9),.null])])
        }
        let original=try Keymap(data:data)
        XCTAssertFalse(original.knob)
        let next=try edited(original)
        XCTAssertEqual(next.value["future"],original.value["future"])
        XCTAssertEqual(next.value["settings"],original.value["settings"])
        XCTAssertEqual(next.combos,original.combos)
        XCTAssertEqual(Array(next.layers.dropFirst()),Array(original.layers.dropFirst()))
        for index in 1..<9 { XCTAssertEqual(next.action(layer:0,key:index),original.action(layer:0,key:index)) }
        XCTAssertEqual(next.layers[0]["encoder"],original.layers[0]["encoder"])
        XCTAssertEqual(try Keymap(data:next.encoded()),next)
    }
    func testEveryActionAndHoldSurvivesEdit() throws {
        var map=try Keymap(data:fixture())
        let originalHold=map.action(layer:0,key:1)["hold"]
        let actions:[JSON] = [
            .object(["type":.string("none")]),
            .object(["type":.string("key"),"key":.string("MPLY")]),
            .object(["type":.string("text"),"text":.string("Hello")]),
            .object(["type":.string("layer"),"mode":.string("to"),"layer":.string("next")]),
            .object(["type":.string("macro"),"steps":.array([
                .object(["do":.string("tap"),"key":.string("A")]),
                .object(["do":.string("press"),"key":.string("LCMD")]),
                .object(["do":.string("release"),"key":.string("LCMD")]),
                .object(["do":.string("delay"),"ms":.number(120)]),
                .object(["do":.string("text"),"text":.string("ok")])])])
        ]
        for action in actions {
            try map.setPressed(action,layer:0,key:1)
            XCTAssertEqual(map.action(layer:0,key:1)["hold"],originalHold)
            XCTAssertEqual(try Keymap(data:map.encoded()),map)
        }
        if let out=ProcessInfo.processInfo.environment["STUDIO_EXPORT_DIR"] {
            try FileManager.default.createDirectory(atPath:out,withIntermediateDirectories:true)
            try map.encoded().write(to:URL(fileURLWithPath:out).appendingPathComponent("keymap.json"))
        }
    }
    func testLargeUnknownIntegerAndASCIIWhitespaceArePreserved() throws {
        let data=try altered(fixture()) { $0["large"] = .integer(9_007_199_254_740_993) }
        var map=try Keymap(data:data)
        try map.setPressed(.object(["type":.string("text"),"text":.string("Line 1\nLine 2\t")]),layer:0,key:0)
        let roundtrip=try Keymap(data:map.encoded())
        XCTAssertEqual(roundtrip.value["large"],.integer(9_007_199_254_740_993))
        XCTAssertTrue(String(data:try map.encoded(),encoding:.utf8)!.contains("9007199254740993"))
    }
    func testBitmapPreviewUsesPaletteAndPixelRows() throws {
        let bitmap=try MonochromeBitmap(data:Data(contentsOf:repo.appendingPathComponent("lib/goku.bmp")))
        XCTAssertEqual(bitmap.pixels.count,4096)
        XCTAssertEqual(bitmap.pixels.filter { $0 }.count,722)
    }
    func testInvalidContractNeverAccepted() throws {
        for edit: (inout [String:JSON])->Void in [
            { $0["version"] = .number(2) },
            { $0["layers"] = .array([]) },
            { $0["settings"] = .object(["knob":.string("false")]) },
            { $0["combos"] = .array([.object(["keys":.array([.number(6),.number(6)])])]) }
        ] { XCTAssertThrowsError(try Keymap(data:altered(fixture(),edit))) }
        var map=try Keymap(data:fixture())
        for action:JSON in [
            .object(["type":.string("key"),"key":.string("DOES_NOT_EXIST")]),
            .object(["type":.string("layer"),"layer":.number(99)]),
            .object(["type":.string("shell"),"text":.string("anything")])
        ] { XCTAssertThrowsError(try map.setPressed(action,layer:0,key:0)) }
    }
    func testSuccessfulSyncBackupAndDuplicateIsNoOp() async throws {
        let pad=try mockPad(), files=FaultFiles(), store=store(files)
        let old=try await store.open(pad), next=try edited(old.keymap)
        let saved=try await store.sync(next,from:old)
        XCTAssertEqual(saved.keymap,next)
        _=try await store.sync(next,from:old)
        XCTAssertEqual(files.replacementCount,1)
        let recovery=temporary.appendingPathComponent("Recovery")
        let transaction=try XCTUnwrap(FileManager.default.contentsOfDirectory(at:recovery,includingPropertiesForKeys:nil).first)
        XCTAssertEqual(try Data(contentsOf:transaction.appendingPathComponent("previous-keymap.json")),old.bytes)
        XCTAssertEqual(try Keymap(data:Data(contentsOf:transaction.appendingPathComponent("draft-keymap.json"))),next)
    }
    func testEveryFileBoundaryFailureRetainsOldOrNewValidConfig() async throws {
        for phase in SyncPhase.allCases {
            let pad=try mockPad(), store=store(checkpoint:{ if $0 == phase { throw POSIXError(.ENODEV) } })
            let old=try await store.open(pad), next=try edited(old.keymap)
            do { _=try await store.sync(next,from:old); XCTFail("Expected injected failure at \(phase)") }
            catch let error as SyncFailure {
                if phase == .finalReadback { if case .unknown = error {} else { XCTFail("Expected unknown outcome") } }
                else { if case .unchanged = error {} else { XCTFail("Old file should be unchanged") } }
            }
            let actual=try Keymap(data:Data(contentsOf:pad.appendingPathComponent("keymap.json")))
            XCTAssertEqual(actual,phase == .finalReadback ? next : old.keymap)
            try FileManager.default.removeItem(at:pad)
        }
    }
    func testFullDriveAndBadStageNeverReplace() async throws {
        for mode in 0..<4 {
            let pad=try mockPad(), files=FaultFiles(); files.failPreflight = mode == 0; files.badStaging = mode == 1; files.readOnly = mode == 2; files.partialWrite = mode == 3
            let store=store(files)
            let old=try await store.open(pad)
            do { _=try await store.sync(edited(old.keymap),from:old); XCTFail("Expected failure") } catch {}
            XCTAssertEqual(try Data(contentsOf:pad.appendingPathComponent("keymap.json")),old.bytes)
            XCTAssertEqual(files.replacementCount,0)
            try FileManager.default.removeItem(at:pad)
        }
    }
    func testExternalEditAndVolumeChangeBlockSync() async throws {
        let pad=try mockPad(), files=FaultFiles(), store=store(files)
        let old=try await store.open(pad)
        var external=try edited(old.keymap)
        try external.setPressed(.object(["type":.string("text"),"text":.string("external")]),layer:0,key:0)
        try external.encoded().write(to:pad.appendingPathComponent("keymap.json"))
        do { _=try await store.sync(edited(old.keymap),from:old); XCTFail("Expected conflict") } catch {}
        XCTAssertEqual(try Keymap(data:Data(contentsOf:pad.appendingPathComponent("keymap.json"))),external)
        files.changedIdentity=true
        do { _=try await store.sync(edited(old.keymap),from:old); XCTFail("Expected volume mismatch") } catch {}
        XCTAssertEqual(files.replacementCount,0)
    }
    func testDisconnectAfterReplacementIsUnknownAndCanReconcile() async throws {
        let pad=try mockPad(), files=FaultFiles(), store=store(files)
        let old=try await store.open(pad), next=try edited(old.keymap)
        files.disconnectAfterReplace=true
        do { _=try await store.sync(next,from:old); XCTFail("Expected disconnect") }
        catch let error as SyncFailure { if case .unknown = error {} else { XCTFail("Expected unknown") } }
        files.disconnectAfterReplace=false
        let reconnected=try await store.open(pad)
        XCTAssertEqual(reconnected.keymap,next)
        _=try await store.sync(next,from:old)
        XCTAssertEqual(files.replacementCount,1)
    }
    func testUnsafePathsAndSymlinksRejected() throws {
        for path in ["../secret","/tmp/file","lib/../../file","lib//file","lib/./x","lib\\x"] { XCTAssertThrowsError(try Keymap.validateRelativePath(path)) }
        let pad=try mockPad()
        try FileManager.default.createSymbolicLink(at:pad.appendingPathComponent("escape"),withDestinationURL:temporary)
        XCTAssertThrowsError(try PadStore.safeChild(pad,path:"escape/test"))
        XCTAssertThrowsError(try PadStore.validateBMP(Data("not a bitmap".utf8)))
    }
}
