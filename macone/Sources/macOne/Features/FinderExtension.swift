import Foundation

/// Finder sağ tık menüsü eklentisi (Yeni Dosya, Kes/Taşı, Burada Terminal Aç). macOne paketinin içinde durur.
/// Finder-Plus'ın kurulum mantığıyla aynı: yalnız eklenti sürümü değişince Finder yeniden başlatılır.
enum FinderExtension {
    private static let id = "dev.cavusoglu.tabula.finder"  // eski adıyla kalır, bkz. finder-plus/Extension/Info.plist
    private static let versionKey = "finderRegisteredVersion"
    private static var appex: String { Bundle.main.bundlePath + "/Contents/PlugIns/NewFileFinder.appex" }
    private static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }

    static func enable() {
        run("/usr/bin/pluginkit", "-a", appex)
        run("/usr/bin/pluginkit", "-e", "use", "-i", id)
        if UserDefaults.standard.string(forKey: versionKey) != version {
            UserDefaults.standard.set(version, forKey: versionKey)
            run("/usr/bin/killall", "Finder")
        }
    }

    static func disable() {
        run("/usr/bin/pluginkit", "-e", "ignore", "-i", id)
        run("/usr/bin/killall", "Finder")
    }

    private static func run(_ args: String...) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: args[0])
        p.arguments = Array(args.dropFirst())
        try? p.run()
        p.waitUntilExit()
    }
}
