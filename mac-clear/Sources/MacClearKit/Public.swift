import AppKit
import SwiftUI

// MARK: - macOne / yürütülebilir dosya için genel API

/// Ana görünüm; boyutu (frame) ana uygulama belirler.
public struct MacClearView: View {
    public init() {}
    public var body: some View {
        // Disk dizini yalnız pencere açıkken izlenir (pil).
        RootView()
            .onAppear { DiskIndex.shared.start() }
            .onDisappear { DiskIndex.shared.stop() }
    }
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
