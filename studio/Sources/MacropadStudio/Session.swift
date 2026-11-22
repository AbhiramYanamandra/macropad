import AppKit
import SwiftUI
import StudioCore

@MainActor final class Session: ObservableObject {
    enum State: String { case empty, ready, dirty, invalid, conflict, syncing, saved, disconnected, unknown }
    @Published var draft: Keymap?
    @Published var snapshot: PadSnapshot?
    @Published var state: State = .empty
    @Published var message = "Open your CIRCUITPY folder to edit its layout."
    @Published var selectedLayer = 0
    @Published var selectedKey = 0
    @Published var destination = "Keys"
    @Published var editing = false
    @Published var history: [Keymap] = []
    @Published var futureNotice = false
    let store: PadStore
    let recovery: URL
    var dirty: Bool { draft != snapshot?.keymap }
    var canSync: Bool { draft != nil && snapshot != nil && dirty && !editing && [.ready, .dirty, .saved].contains(state) }
    var selected: JSON { draft?.action(layer: selectedLayer, key: selectedKey) ?? .object(["type": .string("none")]) }
    var layerName: String { draft?.layers[selectedLayer]["name"].string ?? "No layout" }
    init(recovery: URL? = nil) {
        self.recovery = recovery ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Macropad Studio", isDirectory: true)
        store = PadStore(recovery: self.recovery.appendingPathComponent("Recovery"))
    }
    func confirmDiscard() -> Bool {
        guard dirty || editing else { return true }
        let alert = NSAlert(); alert.messageText = "Keep your current draft?"; alert.informativeText = "Opening another layout replaces the working draft. Applied edits are saved locally in Application Support."
        alert.addButton(withTitle: "Keep editing"); alert.addButton(withTitle: "Open another layout")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func chooseFolder() {
        guard state != .syncing, confirmDiscard() else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.message = "Choose the CIRCUITPY folder containing your macropad firmware and keymap.json."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await open(url) }
    }
    func open(_ url: URL) async {
        do {
            let opened = try await store.open(url)
            snapshot = opened; draft = opened.keymap; history = []; selectedLayer = 0; selectedKey = 0; editing = false
            state = .ready; message = "Layout opened. Selected layer is an editor preview; live pad state is unavailable."
        } catch { state = .invalid; message = error.localizedDescription }
    }
    func persistDraft() throws {
        guard let draft else { return }
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        try draft.encoded().write(to: recovery.appendingPathComponent("working-draft.json"), options: .atomic)
    }
    func apply(_ action: JSON) throws {
        guard var next = draft else { return }
        try next.setPressed(action, layer: selectedLayer, key: selectedKey)
        guard next != draft else { editing = false; return }
        let previous = draft!; draft = next
        do { try persistDraft() } catch { draft = previous; throw error }
        history.append(previous); editing = false
        if [.ready, .dirty, .saved].contains(state) { state = .dirty }
        message = "Draft updated. Sync to pad when you're ready."
    }
    func undo() {
        guard !editing, state != .syncing, let previous = history.last else { return }
        let current = draft; draft = previous
        do { try persistDraft(); history.removeLast(); if [.ready, .dirty, .saved].contains(state) { state = dirty ? .dirty : .ready }; message = "Undid the last key edit." }
        catch { draft = current; message = error.localizedDescription }
    }
    func sync() {
        guard canSync, let map = draft, let old = snapshot else { return }
        state = .syncing; message = "Validating, backing up and writing the keymap…"
        Task {
            do {
                snapshot = try await store.sync(map, from: old); state = .saved
                message = "Saved to pad; firmware reload not verified."
            } catch let error as SyncFailure {
                switch error { case .unknown: state = .unknown; case .unchanged: state = .conflict }
                message = error.localizedDescription
            } catch { state = .invalid; message = error.localizedDescription }
        }
    }
    func checkConnection() async {
        guard let snapshot, state != .syncing, state != .invalid else { return }
        if !(await store.isPresent(snapshot)) { state = .disconnected; message = "Pad disconnected. Your draft is retained. Reconnect and inspect before syncing." }
    }
    func inspectReconnect() {
        guard let old = snapshot, let map = draft else { return }
        Task {
            do {
                let current = try await store.open(old.root)
                guard current.identity == old.identity else { throw StudioError("This is a different destination. Choose the correct pad folder.") }
                if current.keymap == map { snapshot = current; state = .saved; message = "The pad contains your draft. Firmware reload is not verified." }
                else if current.bytes == old.bytes { snapshot = current; state = .dirty; message = "The pad still contains the previous layout. Your draft is ready for an explicit retry." }
                else { state = .conflict; message = "The pad contains another valid layout. Reopen it to discard this draft, or keep editing locally." }
            } catch { state = .unknown; message = "Cannot inspect the pad: \(error.localizedDescription). Draft retained." }
        }
    }
    func requestQuit() {
        if state == .syncing { message = "Wait for sync to finish before quitting."; return }
        if editing || dirty || state == .unknown {
            let alert = NSAlert(); alert.messageText = "Quit Macropad Studio?"
            alert.informativeText = "Applied edits are retained in Application Support/ Macropad Studio/working-draft.json. Unapplied inspector edits will be lost. An uncertain sync must be inspected on the same pad before retrying."
            alert.addButton(withTitle: "Keep editing"); alert.addButton(withTitle: "Quit")
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        NSApplication.shared.terminate(nil)
    }
    func recoverDraft() {
        guard state != .syncing, let current = draft else { return }
        do {
            let recovered = try Keymap(data: Data(contentsOf: recovery.appendingPathComponent("working-draft.json")))
            guard recovered.layers.count == current.layers.count else { throw StudioError("The recovered draft has a different layer count. Open it in a mock folder for inspection first.") }
            history.append(current); draft = recovered; selectedLayer = 0; selectedKey = 0; editing = false
            if [.ready, .dirty, .saved].contains(state) { state = .dirty }; message = "Recovered the local draft. Review it before syncing."
        } catch { message = error.localizedDescription }
    }
}
