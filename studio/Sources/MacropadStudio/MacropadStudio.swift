import AppKit
import SwiftUI
import StudioCore

@main struct MacropadStudio: App {
    @StateObject private var session = Session()
    var body: some Scene {
        WindowGroup("Macropad Studio", id: "studio") {
            StudioWindow(session: session).frame(minWidth: 1080, minHeight: 720)
                .preferredColorScheme(.light)
                .task { while !Task.isCancelled { await session.checkConnection(); try? await Task.sleep(nanoseconds: 2_000_000_000) } }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { Button("Open pad folder…") { session.chooseFolder() }.keyboardShortcut("o") }
            CommandGroup(replacing: .undoRedo) { Button("Undo key edit") { session.undo() }.keyboardShortcut("z").disabled(session.history.isEmpty || session.editing) }
            CommandGroup(replacing: .appTermination) { Button("Quit Macropad Studio") { session.requestQuit() }.keyboardShortcut("q") }
        }
        MenuBarExtra("Macropad Studio", systemImage: "square.grid.3x3") { StudioMenu(session: session) }
            .menuBarExtraStyle(.window)
    }
}

struct StudioMenu: View {
    @ObservedObject var session: Session
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Macropad mk2", systemImage: "square.grid.3x3").font(.headline)
            Text(session.snapshot == nil ? "No pad selected" : session.state.rawValue.capitalized).foregroundStyle(.secondary)
            Text("Editor selection: \(session.layerName)").font(.caption)
            Text("Live layer control arrives in a later slice.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Button("Open Studio") { openWindow(id: "studio"); NSApp.activate(ignoringOtherApps: true) }.keyboardShortcut("o")
            Button("Open pad folder…") { session.chooseFolder() }
            Button("Quit") { session.requestQuit() }.keyboardShortcut("q")
        }.padding(18).frame(width: 280).background(Porcelain.surface)
    }
}
