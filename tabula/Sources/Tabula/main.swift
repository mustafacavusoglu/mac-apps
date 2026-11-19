import Cocoa
import ServiceManagement
import TabulaKit

// Ana uygulama: Finder eklentisini kaydeder (sürüm başına bir kez), sonra arka planda ⌘X/⌘V kısayollarını dinler.
let id = "dev.cavusoglu.tabula.finder"
let appex = Bundle.main.bundlePath + "/Contents/PlugIns/NewFileFinder.appex"
let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

func run(_ args: [String]) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: args[0]); p.arguments = Array(args.dropFirst())
    try? p.run(); p.waitUntilExit()
}

NSApplication.shared.setActivationPolicy(.accessory)

if UserDefaults.standard.string(forKey: "setupVersion") != version {
    run(["/usr/bin/pluginkit", "-a", appex])
    run(["/usr/bin/pluginkit", "-e", "use", "-i", id])
    run(["/usr/bin/killall", "Finder"])
    UserDefaults.standard.set(version, forKey: "setupVersion")
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert()
    a.messageText = "Tabula etkin"
    a.informativeText = "Finder'da sağ tık → Yeni Dosya, Kes, Burada Terminal Aç.\nKısayollar ⌘X (kes) ve ⌘V (buraya taşı) için Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik'te Tabula'yı aç. Finder'ı denetleme (Otomasyon) sorusuna da izin ver.\nSağ tık menüsü görünmezse: Genel → Oturum Açma Öğeleri ve Eklentiler → Finder → Yeni Dosya."
    a.runModal()
}

try? SMAppService.mainApp.register()  // oturum açılınca kendiliğinden başlar
finderShortcutsStart()
NSApp.run()
