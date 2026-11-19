import AppKit
import SwiftUI

// MARK: - macOne / yürütülebilir dosya için genel API

/// Ana görünüm; boyutu (frame) ana uygulama belirler.
public struct MacClearView: View {
    public init() {}
    public var body: some View { RootView() }
}

/// Dizini yükler / arka planda tarar. Görünümden önce bir kez çağrılır (tekrar çağrılması zararsızdır).
@MainActor public func macClearPrepare() {
    DiskIndex.shared.start()
}

/// `--selftest` ve `--du <klasör>` bayraklarını işler; işlediyse süreçten çıkar (true döner, aslında dönmez).
@MainActor public func macClearHandleCommandLine(_ args: [String]) -> Bool {
    if args.contains("--selftest") {
        selfTest(); leftoversSelfTest(); cleanTreeSelfTest(); duplicatesSelfTest(); indexSelfTest()
        Task { await performSelfTest(); exit(0) }
        RunLoop.main.run() // ana aktör görevleri için
        return true
    }
    if let i = args.firstIndex(of: "--du"), i + 1 < args.count { duCommand(args[i + 1]); exit(0) }
    return false
}
