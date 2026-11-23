import AppKit

/// exelban/stats uygulamasını başlatır / durdurur. Kurulu Stats (/Applications) varsa onu açar
/// (Apple onaylı, kendini güncelliyor); yoksa macOne'ın içindeki kopyayı (Contents/Resources/Stats.app).
enum StatsFeature {
    static let bundleID = "eu.exelban.Stats"

    private static var running: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    }

    static var isRunning: Bool { !running.isEmpty }

    /// Çalışmıyorsa gömülü kopyayı arka planda açar; kopya yoksa hiçbir şey yapmaz.
    static func start() {
        guard !isRunning else { return }
        let installed = URL(fileURLWithPath: "/Applications/Stats.app")
        let embedded = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Stats.app")
        guard let url = [installed, embedded].first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        // hides = true KULLANMA: gizli açılan Stats menü çubuğuna tıklanınca panelini (tüketim, en yoğun işlemler) hiç göstermiyor.
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
    }

    /// Çalışan tüm Stats örneklerini kapatır.
    static func stop() {
        running.forEach { $0.terminate() }
    }
}
