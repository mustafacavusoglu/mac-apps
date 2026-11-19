import SwiftUI
import SpeedTestKit
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
        NSApp.appearance = NSAppearance(named: .aqua)  // açık tema: depodaki diğer ekran görüntüleriyle aynı
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
        let window = KeyWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)  // etkin pencere: anahtarlar gri değil, gerçek renkte çizilir
        RunLoop.main.run(until: Date().addingTimeInterval(2))  // düzenin oturması için
        // Ekrandaki hâliyle yakala (cacheDisplay denetimleri hep etkin değilmiş gibi soluk çiziyor).
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l\(window.windowNumber)", dir.appendingPathComponent("\(name).png").path]
        try? p.run(); p.waitUntilExit()
        window.orderOut(nil)
    }
}

/// Kenarlıksız pencere normalde etkin (key) olamaz; görüntüde denetimler soluk çıkmasın diye.
private final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
