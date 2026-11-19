// Menü çubuğu simgesi ve menüsü.
import AppKit

func makeStatusItem() -> NSStatusItem {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    // Uygulama ikonuyla aynı motif: iki yan pencere + seçili orta pencere. Template → açık/koyu menü çubuğuna uyar.
    let img = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
        NSColor.black.set()
        for x in [0.6, 17.4] {
            let p = NSBezierPath(roundedRect: NSRect(x: x, y: 5, width: 4, height: 6), xRadius: 1.2, yRadius: 1.2)
            p.lineWidth = 1.2; p.stroke()
        }
        NSBezierPath(roundedRect: NSRect(x: 7, y: 1.5, width: 8, height: 13), xRadius: 2.2, yRadius: 2.2).fill()
        NSColor.clear.set()  // orta pencerede başlık çubuğu çizgisi (oyuk)
        NSRect(x: 7, y: 10.5, width: 8, height: 1).fill(using: .copy)
        return true
    }
    img.isTemplate = true
    img.accessibilityDescription = "Alt-Tab"
    status.button?.image = img
    status.menu = NSMenu()
    status.menu?.addItem(NSMenuItem(title: "Alt-Tab — ⌥Tab", action: nil, keyEquivalent: ""))
    status.menu?.addItem(.separator())
    status.menu?.addItem(NSMenuItem(title: "Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    return status
}
