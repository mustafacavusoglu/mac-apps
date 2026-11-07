// Resources/AppIcon.icns ve docs/icon.png üretir. tabula klasöründen: swift tools/make_icon.swift
// Motif: boş beyaz sayfa (tabula rasa), köşesi kıvrık, ortada artı.
import AppKit

func hex(_ v: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let body = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let sh = NSShadow(); sh.shadowColor = .black.withAlphaComponent(0.3); sh.shadowBlurRadius = 30; sh.shadowOffset = NSSize(width: 0, height: -14); sh.set()
hex(0x0F766E).setFill(); body.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [hex(0x5EEAD4), hex(0x14B8A6), hex(0x0F766E)])!.draw(in: body, angle: -65)

// Sayfa: sağ üst köşe kesik
let (l, r, b, t, f) = (332.0, 692.0, 232.0, 792.0, 130.0)
let page = NSBezierPath()
page.move(to: NSPoint(x: l, y: b)); page.line(to: NSPoint(x: r, y: b)); page.line(to: NSPoint(x: r, y: t - f))
page.line(to: NSPoint(x: r - f, y: t)); page.line(to: NSPoint(x: l, y: t)); page.close()
page.lineJoinStyle = .round
NSGraphicsContext.saveGraphicsState()
sh.shadowBlurRadius = 24; sh.shadowOffset = NSSize(width: 0, height: -10); sh.set()
hex(0xFFFFFF).setFill(); page.fill(); NSGraphicsContext.restoreGraphicsState()
let fold = NSBezierPath()
fold.move(to: NSPoint(x: r - f, y: t)); fold.line(to: NSPoint(x: r - f, y: t - f)); fold.line(to: NSPoint(x: r, y: t - f)); fold.close()
hex(0xCCFBF1).setFill(); fold.fill()

// Artı
hex(0x0F766E).setFill()
let (cx, cy) = ((l + r) / 2 - 10, (b + t) / 2 - 30)
NSBezierPath(roundedRect: NSRect(x: cx - 70, y: cy - 14, width: 140, height: 28), xRadius: 14, yRadius: 14).fill()
NSBezierPath(roundedRect: NSRect(x: cx - 14, y: cy - 70, width: 28, height: 140), xRadius: 14, yRadius: 14).fill()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "docs/icon.png"))
let set = "/tmp/tabula.iconset"
try? FileManager.default.removeItem(atPath: set)
try! FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
let src = NSImage(data: png)!
for s in [16, 32, 128, 256, 512] { for x in [1, 2] {
    let px = s * x, img = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: img)
    src.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    try! img.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(set)/icon_\(s)x\(s)\(x == 2 ? "@2x" : "").png"))
} }
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); p.arguments = ["-c", "icns", set, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
