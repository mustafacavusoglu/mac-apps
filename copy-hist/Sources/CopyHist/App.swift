import SwiftUI

@main
struct CopyHistApp: App {
    @StateObject private var store: Store
    private let watcher: Watcher

    init() {
        let s = Store()
        let w = Watcher(store: s)
        w.start()
        _store = StateObject(wrappedValue: s)
        watcher = w
    }

    var body: some Scene {
        MenuBarExtra("Copy-Hist", systemImage: "doc.on.clipboard") {
            MenuView(store: store, watcher: watcher)
        }
        .menuBarExtraStyle(.window)
    }
}
