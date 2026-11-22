import XCTest
import SwiftUI
import AppKit
import StudioCore
@testable import MacropadStudio

private let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

@MainActor final class StudioUITests:XCTestCase {
    func testApplyUndoRetainsDraftAcrossDisconnectState() async throws {
        let local=FileManager.default.temporaryDirectory.appendingPathComponent("StudioSession-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:local) }
        let session=Session(recovery:local)
        await session.open(repo)
        let original=try XCTUnwrap(session.draft)
        try session.apply(.object(["type":.string("text"),"text":.string("Test edit"),"label":.string("TEST")]))
        XCTAssertTrue(session.dirty); XCTAssertTrue(session.canSync)
        XCTAssertEqual(session.state,.dirty)
        session.editing=true; XCTAssertFalse(session.canSync)
        session.editing=false
        session.state = .disconnected
        XCTAssertFalse(session.canSync)
        XCTAssertNotEqual(session.draft,original)
        XCTAssertEqual(try Keymap(data:Data(contentsOf:local.appendingPathComponent("working-draft.json"))),session.draft)
        session.undo()
        XCTAssertEqual(session.draft,original)
        XCTAssertEqual(session.state,.disconnected)
    }
    func testInvalidOpenDoesNotDiscardDraftOrAllowSync() async throws {
        let local=FileManager.default.temporaryDirectory.appendingPathComponent("StudioInvalid-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:local) }
        let session=Session(recovery:local)
        await session.open(repo)
        let draft=session.draft
        await session.open(local.appendingPathComponent("missing"))
        XCTAssertEqual(session.state,.invalid)
        XCTAssertEqual(session.draft,draft)
        XCTAssertFalse(session.canSync)
    }
    func testRecoveryIsBoundToTheSelectedPadAndOriginalLayout() async throws {
        let local=FileManager.default.temporaryDirectory.appendingPathComponent("StudioRecovery-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:local) }
        let session=Session(recovery:local)
        await session.open(repo)
        let original=try XCTUnwrap(session.draft)
        try session.apply(.object(["type":.string("text"),"text":.string("Recovered")]))
        let expected=session.draft
        await session.open(repo)
        session.recoverDraft()
        XCTAssertEqual(session.draft,expected)
        let other=local.appendingPathComponent("OtherPad")
        try FileManager.default.createDirectory(at:other.appendingPathComponent("lib"),withIntermediateDirectories:true)
        for name in ["code.py","config_loader.py","keymap.json","lib/goku.bmp","lib/manandmountain.bmp","lib/turbulence.bmp"] {
            try FileManager.default.copyItem(at:repo.appendingPathComponent(name),to:other.appendingPathComponent(name))
        }
        await session.open(other)
        session.recoverDraft()
        XCTAssertEqual(session.draft,original)
        XCTAssertTrue(session.message.contains("another pad"))
    }
    func testLargeDelayTextDoesNotNarrowToMachineInteger() {
        let step:JSON = .object(["do":.string("delay"),"ms":.number(1e30)])
        let editor=MacroStepEditor(step:.constant(step),index:0,remove:{})
        XCTAssertEqual(Double(editor.delayText),1e30)
    }
    func testRenderNativeWindowAndDevicePreview() async throws {
        guard let directory=ProcessInfo.processInfo.environment["STUDIO_SCREENSHOT_DIR"] else { return }
        let local=FileManager.default.temporaryDirectory.appendingPathComponent("StudioRender-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:local) }
        _=NSApplication.shared
        let session=Session(recovery:local)
        await session.open(repo)
        session.selectedLayer=1; session.selectedKey=4
        let root=URL(fileURLWithPath:directory)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        try render(StudioWindow(session:session).frame(width:1200,height:760),to:root.appendingPathComponent("studio-keys.png"),size:CGSize(width:1200,height:760))
        try render(PadDrawing(session:session).frame(width:318).padding(70).background(Porcelain.background),to:root.appendingPathComponent("macropad-preview.png"),size:CGSize(width:458,height:530))
    }
    private func render<V:View>(_ view:V,to url:URL,size:CGSize) throws {
        let host=NSHostingView(rootView:view.environment(\.colorScheme,.light))
        host.frame=CGRect(origin:.zero,size:size)
        host.layoutSubtreeIfNeeded()
        let bitmap=try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in:host.bounds))
        host.cacheDisplay(in:host.bounds,to:bitmap)
        let png=try XCTUnwrap(bitmap.representation(using:.png,properties:[:]))
        try png.write(to:url)
    }
}
