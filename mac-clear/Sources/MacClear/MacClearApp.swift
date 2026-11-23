import AppKit
import SwiftUI
import MacClearKit

/// Komut satırı: `mac-clear --selftest` (testler), `mac-clear --du <klasör>` (hızlı tarama ölçümü).
@main struct MacClearApp: App {
    init() {
        _ = macClearHandleCommandLine(CommandLine.arguments)
        setvbuf(stdout, nil, _IOLBF, 0) // terminalden çalıştırınca süre çıktıları anında görünsün
        NSApplication.shared.setActivationPolicy(.regular)
    }
    var body: some Scene {
        WindowGroup("Mac-Clear") { MacClearView().frame(minWidth: 860, minHeight: 560) }
            .windowToolbarStyle(.unified)
    }
}
