// Alt-Tab — ⌥Tab ile canlı önizlemeli pencere değiştirici.
import AppKit

let args = CommandLine.arguments
if args.contains("--list") {  // izinsiz kontrol: pencere listesini yaz
    for w in listWindows() { print(w.id, w.pid, w.app, "—", w.title) }
    exit(0)
}

setvbuf(stdout, nil, _IOLBF, 0)
print("Erişilebilirlik:", AXIsProcessTrusted(), "Ekran Kaydı:", CGPreflightScreenCaptureAccess())
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let switcher = Switcher()

if let i = args.firstIndex(of: "--preview"), i + 1 < args.count {
    // Tasarım kontrolü: paneli açıp görüntüsünü PNG'ye yazar (Erişilebilirlik izni gerekmez).
    switcher.open(backwards: false)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l\(switcher.panel.windowNumber)", args[i + 1]]
        try? p.run(); p.waitUntilExit(); exit(p.terminationStatus)
    }
    app.run()
}

// İki izin de yalnız bir kez sorulur (imza sabit olduğu için derlemeler arasında korunur).
if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }  // küçük resimler için
if !(AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) && startHotkey(switcher)) {
    // İzin verilene kadar bekle; yeniden başlatmak gerekmez.
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in if AXIsProcessTrusted() && startHotkey(switcher) { t.invalidate() } }
}

let status = makeStatusItem()
app.run()
