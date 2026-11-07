import Cocoa

// Ev sahibi uygulama: Finder eklentisini kaydeder, etkinleştirir, Finder'ı yeniler ve çıkar.
let id = "dev.cavusoglu.tabula.finder"
let appex = Bundle.main.bundlePath + "/Contents/PlugIns/NewFileFinder.appex"
func run(_ args: [String]) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: args[0]); p.arguments = Array(args.dropFirst())
    try? p.run(); p.waitUntilExit()
}
run(["/usr/bin/pluginkit", "-a", appex])
run(["/usr/bin/pluginkit", "-e", "use", "-i", id])
run(["/usr/bin/killall", "Finder"])

NSApplication.shared.setActivationPolicy(.accessory)
NSApp.activate(ignoringOtherApps: true)
let a = NSAlert()
a.messageText = "Yeni Dosya etkin"
a.informativeText = "Finder'da bir klasörün boş yerine sağ tıkla → Yeni Dosya.\nGörünmezse: Sistem Ayarları → Genel → Oturum Açma Öğeleri ve Eklentiler → Finder → Yeni Dosya'yı aç."
a.runModal()
