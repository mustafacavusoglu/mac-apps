import SwiftUI
import CopyHistKit

@main
struct CopyHistApp: App {
    init() { clipboardHistoryStart() }

    var body: some Scene {
        MenuBarExtra("Copy-Hist", systemImage: "doc.on.clipboard") {
            ClipboardHistoryMenu()
        }
        .menuBarExtraStyle(.window)
    }
}
