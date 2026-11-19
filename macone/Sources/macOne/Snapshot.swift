import SwiftUI
import AppKit

/// Tasarım kontrolü: `macOne --snapshot <klasör>` menü, ayarlar ve hız testi ekranlarını PNG'ye yazar, çıkar.
/// Hiçbir özelliği başlatmaz ve izin istemez. Menü görüntüsünde gerçek pano geçmişi görünür.
@MainActor
enum Snapshot {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1])
        let store = FeatureStore(features: Catalog.make())
        NSApplication.shared.setActivationPolicy(.accessory)
        render(MenuView(features: store), "menu", dir)
        render(SettingsView(features: store).frame(width: 520), "settings", dir)
        render(FeaturePanel(title: "Hız Testi", symbol: "speedometer", turnOff: {}) { SpeedTestView().frame(width: 400) }, "speedtest", dir)
        let running = SpeedTestModel(); running.preview(.download, live: 312.4, ping: 14, download: nil, upload: nil)
        render(SpeedTestView(model: running).frame(width: 420), "speedtest-running", dir)
        let done = SpeedTestModel(); done.preview(.done, live: 486.2, ping: 14, download: 486.2, upload: 92.7)
        render(SpeedTestView(model: done).frame(width: 420), "speedtest-done", dir)
        exit(0)
    }

    private static func render(_ view: some View, _ name: String, _ dir: URL) {
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        host.frame.size = host.fittingSize
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(2))  // düzenin oturması için
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
        window.orderOut(nil)
    }
}
