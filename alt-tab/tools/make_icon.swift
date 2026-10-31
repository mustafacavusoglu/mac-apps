// Resources/AppIcon.icns ve docs/icon.png üretir. alt-tab klasöründen: swift tools/make_icon.swift
// Motif: Geçiş panelinin kendisi — üç pencere kutucuğu, ortadaki seçili.
import AppKit

func hex(_ v: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}
func rr(_ r: NSRect, _ c: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: c, yRadius: c) }
func shadow(_ a: CGFloat, blur: CGFloat, y: CGFloat) { let s = NSShadow(); s.shadowColor = .black.withAlphaComponent(a); s.shadowBlurRadius = blur; s.shadowOffset = NSSize(width: 0, height: y); s.set() }
func dots(_ r: NSRect, colors: [NSColor], d: CGFloat) {
    for (i, c) in colors.enumerated() { c.setFill(); NSBezierPath(ovalIn: NSRect(x: r.minX + d * 1.2 + CGFloat(i) * d * 1.7, y: r.maxY - d * 2.1, width: d, height: d)).fill() }
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Gövde (macOS ikon ızgarası: 1024 içinde 824'lük kare)
let body = rr(NSRect(x: 100, y: 100, width: 824, height: 824), 185)
NSGraphicsContext.saveGraphicsState(); shadow(0.35, blur: 30, y: -14); hex(0x2A1F7A).setFill(); body.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [hex(0x8A9BFF), hex(0x5B4BE8), hex(0x2A1F7A)])!.draw(in: body, angle: -65)
NSGraphicsContext.saveGraphicsState(); body.addClip()
NSGradient(colors: [.white.withAlphaComponent(0.25), .white.withAlphaComponent(0)])!.draw(in: NSRect(x: 100, y: 600, width: 824, height: 324), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Yan kutucuklar (yarı saydam cam)
for x in [158.0, 656.0] {
    let r = NSRect(x: x, y: 432, width: 210, height: 160), p = rr(r, 26)
    hex(0xFFFFFF, 0.26).setFill(); p.fill()
    hex(0xFFFFFF, 0.45).setStroke(); p.lineWidth = 3; p.stroke()
    dots(r, colors: Array(repeating: hex(0xFFFFFF, 0.7), count: 3), d: 14)
    hex(0xFFFFFF, 0.35).setFill()
    rr(NSRect(x: r.minX + 22, y: r.minY + 52, width: 166, height: 16), 8).fill()
    rr(NSRect(x: r.minX + 22, y: r.minY + 24, width: 110, height: 16), 8).fill()
}

// Seçili orta kutucuk
let c = NSRect(x: 337, y: 372, width: 350, height: 268)
let ring = rr(c.insetBy(dx: -20, dy: -20), 52)
hex(0x8BE9FF).setStroke(); ring.lineWidth = 12; ring.stroke()
NSGraphicsContext.saveGraphicsState(); shadow(0.4, blur: 36, y: -16); hex(0xFFFFFF).setFill(); rr(c, 34).fill(); NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState(); rr(c, 34).addClip()
hex(0xEEF0F8).setFill(); NSRect(x: c.minX, y: c.maxY - 58, width: c.width, height: 58).fill()
dots(c, colors: [hex(0xFF5F57), hex(0xFEBC2E), hex(0x28C840)], d: 22)
hex(0x6C63FF).setFill(); rr(NSRect(x: c.minX + 30, y: c.minY + 30, width: 112, height: 150), 16).fill()
hex(0xDDE1EE).setFill()
for (y, w) in [(152.0, 170.0), (112.0, 140.0), (72.0, 170.0), (32.0, 110.0)] { rr(NSRect(x: c.minX + 160, y: c.minY + y, width: w, height: 18), 9).fill() }
NSGraphicsContext.restoreGraphicsState()

// ⌥⇥ tuş ipucu
let keys = "⌥ ⇥" as NSString
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 92, weight: .semibold), .foregroundColor: NSColor.white.withAlphaComponent(0.92)]
let ks = keys.size(withAttributes: attrs)
keys.draw(at: NSPoint(x: 512 - ks.width / 2, y: 196), withAttributes: attrs)

// iconset → icns
let dir = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.removeItem(at: dir)
try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let master = dir.appendingPathComponent("master.png")
try! rep.representation(using: .png, properties: [:])!.write(to: master)
func run(_ args: [String]) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: args[0]); p.arguments = Array(args.dropFirst())
    p.standardOutput = FileHandle.nullDevice; try! p.run(); p.waitUntilExit()
}
for s in [16, 32, 128, 256, 512] {
    run(["/usr/bin/sips", "-z", "\(s)", "\(s)", master.path, "--out", dir.appendingPathComponent("icon_\(s)x\(s).png").path])
    run(["/usr/bin/sips", "-z", "\(s * 2)", "\(s * 2)", master.path, "--out", dir.appendingPathComponent("icon_\(s)x\(s)@2x.png").path])
}
let preview = URL(fileURLWithPath: "docs/icon.png")
try? FileManager.default.removeItem(at: preview)
try! FileManager.default.copyItem(at: master, to: preview)  // README önizlemesi
try! FileManager.default.removeItem(at: master)
run(["/usr/bin/iconutil", "-c", "icns", dir.path, "-o", "Resources/AppIcon.icns"])
try! FileManager.default.removeItem(at: dir)
print("Resources/AppIcon.icns hazır")
