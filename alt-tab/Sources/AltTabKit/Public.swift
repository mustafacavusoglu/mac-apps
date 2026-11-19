// macOne ve tek başına uygulama için genel API.
import AppKit

private var switcher: Switcher?
private var pollTimer: Timer?
private var status: NSStatusItem?

/// ⌥Tab'ı başlatır (izinleri ister, gerekirse izin verilene kadar bekler). Birden çok çağrı güvenlidir.
public func altTabStart(showStatusItem: Bool = true) {
    if switcher == nil {
        let s = Switcher()
        switcher = s
        // İki izin de yalnız bir kez sorulur (imza sabit olduğu için derlemeler arasında korunur).
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }  // küçük resimler için
        if !(AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) && startHotkey(s)) {
            // İzin verilene kadar bekle; yeniden başlatmak gerekmez.
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                if AXIsProcessTrusted() && startHotkey(s) { t.invalidate(); pollTimer = nil }
            }
        }
    }
    if showStatusItem { if status == nil { status = makeStatusItem() } }
    else if let s = status { NSStatusBar.system.removeStatusItem(s); status = nil }
}

/// Özelliği tamamen kapatır: musluk, zamanlayıcı, panel ve menü çubuğu simgesi.
public func altTabStop() {
    pollTimer?.invalidate(); pollTimer = nil
    stopHotkey()
    switcher?.cancel(); switcher = nil
    if let s = status { NSStatusBar.system.removeStatusItem(s); status = nil }
}

/// `--list`: pencere listesini yazar (izin gerekmez).
public func altTabPrintWindows() {
    for w in listWindows() { print(w.id, w.pid, w.app, "—", w.title) }
}

/// `--preview`: paneli açıp görüntüsünü PNG'ye yazar, sonra çıkar (Erişilebilirlik izni gerekmez).
public func altTabPreview(to path: String) {
    let sw = Switcher()
    previewSwitcher = sw
    sw.open(backwards: false)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l\(sw.panel.windowNumber)", path]
        try? p.run(); p.waitUntilExit(); exit(p.terminationStatus)
    }
}
private var previewSwitcher: Switcher?
