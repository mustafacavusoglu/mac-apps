// Resources/AppIcon.icns ve docs/icon.png üretir. macone klasöründen: swift tools/make_icon.swift
// Motif: önden sade bir MacBook; ekranda 2×2 kutucuk (birçok uygulama tek yerde), biri öne çıkmış.
import AppKit

func hex(_ v: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}
func rr(_ r: NSRect, _ c: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: c, yRadius: c) }
func shadow(_ a: CGFloat, blur: CGFloat, y: CGFloat) {
    let s = NSShadow(); s.shadowColor = .black.withAlphaComponent(a); s.shadowBlurRadius = blur; s.shadowOffset = NSSize(width: 0, height: y); s.set()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Gövde: açık, yumuşak gri-beyaz (macOS ikon ızgarası: 1024 içinde 824'lük kare)
let body = rr(NSRect(x: 100, y: 100, width: 824, height: 824), 185)
NSGraphicsContext.saveGraphicsState(); shadow(0.22, blur: 28, y: -12); hex(0xF2F3F6).setFill(); body.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [hex(0xFFFFFF), hex(0xE4E6EC)])!.draw(in: body, angle: -90)
hex(0x000000, 0.06).setStroke(); body.lineWidth = 2; body.stroke()

// Dizüstünü gövdede dikeyde ortala
let shift = NSAffineTransform(); shift.translateX(by: 0, yBy: -45); shift.concat()

// Masa gölgesi
NSGraphicsContext.saveGraphicsState(); body.addClip()
NSGradient(colors: [hex(0x000000, 0.16), hex(0x000000, 0)])!.draw(in: NSBezierPath(ovalIn: NSRect(x: 170, y: 300, width: 684, height: 70)), relativeCenterPosition: .zero)
NSGraphicsContext.restoreGraphicsState()

// Ekran çerçevesi (uzay grisi) ve ekran
let lid = NSRect(x: 214, y: 372, width: 596, height: 400)
NSGraphicsContext.saveGraphicsState(); shadow(0.25, blur: 22, y: -8); hex(0x1D1D1F).setFill(); rr(lid, 34).fill(); NSGraphicsContext.restoreGraphicsState()
let screen = lid.insetBy(dx: 16, dy: 16)
NSGraphicsContext.saveGraphicsState(); rr(screen, 20).addClip()
NSGradient(colors: [hex(0x64D2FF), hex(0x5E5CE6), hex(0xBF5AF2)])!.draw(in: screen, angle: -55)
NSGradient(colors: [.white.withAlphaComponent(0.22), .white.withAlphaComponent(0)])!.draw(in: NSRect(x: screen.minX, y: screen.midY, width: screen.width, height: screen.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Çentik (kamera)
hex(0x1D1D1F).setFill()
rr(NSRect(x: 512 - 46, y: screen.maxY - 20, width: 92, height: 30), 10).fill()

// 2×2 kutucuk: üçü buzlu cam, biri beyaz
let t = NSSize(width: 118, height: 84), gap: CGFloat = 22
let origin = NSPoint(x: 512 - t.width - gap / 2, y: screen.midY - t.height - gap / 2)
for row in 0..<2 { for col in 0..<2 {
    let r = NSRect(x: origin.x + CGFloat(col) * (t.width + gap), y: origin.y + CGFloat(1 - row) * (t.height + gap), width: t.width, height: t.height)
    let p = rr(r, 16)
    if row == 0 && col == 0 {
        NSGraphicsContext.saveGraphicsState(); shadow(0.25, blur: 14, y: -5); hex(0xFFFFFF, 0.95).setFill(); p.fill(); NSGraphicsContext.restoreGraphicsState()
    } else {
        hex(0xFFFFFF, 0.24).setFill(); p.fill()
        hex(0xFFFFFF, 0.5).setStroke(); p.lineWidth = 2.5; p.stroke()
    }
}}

// Alt kasa (alüminyum) ve açma girintisi
let base = NSRect(x: 150, y: 338, width: 724, height: 34)
let basePath = NSBezierPath()
basePath.move(to: NSPoint(x: base.minX, y: base.maxY))
basePath.line(to: NSPoint(x: base.maxX, y: base.maxY))
basePath.curve(to: NSPoint(x: base.maxX - 40, y: base.minY), controlPoint1: NSPoint(x: base.maxX, y: base.minY + 10), controlPoint2: NSPoint(x: base.maxX - 14, y: base.minY))
basePath.line(to: NSPoint(x: base.minX + 40, y: base.minY))
basePath.curve(to: NSPoint(x: base.minX, y: base.maxY), controlPoint1: NSPoint(x: base.minX + 14, y: base.minY), controlPoint2: NSPoint(x: base.minX, y: base.minY + 10))
basePath.close()
NSGraphicsContext.saveGraphicsState(); shadow(0.2, blur: 12, y: -6); hex(0xC9CCD3).setFill(); basePath.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [hex(0xEDEEF2), hex(0xB4B8C1)])!.draw(in: basePath, angle: -90)
hex(0x9EA3AD).setFill()
rr(NSRect(x: 512 - 58, y: base.maxY - 12, width: 116, height: 12), 6).fill()

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
try? FileManager.default.createDirectory(at: URL(fileURLWithPath: "docs"), withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: URL(fileURLWithPath: "Resources"), withIntermediateDirectories: true)
let preview = URL(fileURLWithPath: "docs/icon.png")
try? FileManager.default.removeItem(at: preview)
try! FileManager.default.copyItem(at: master, to: preview)  // README önizlemesi
try! FileManager.default.removeItem(at: master)
run(["/usr/bin/iconutil", "-c", "icns", dir.path, "-o", "Resources/AppIcon.icns"])
try! FileManager.default.removeItem(at: dir)
print("Resources/AppIcon.icns hazır")
