// Resources/AppIcon.icns ve docs/icon.png üretir. finder-plus klasöründen: swift tools/make_icon.swift
// Motif: mavi klasör, üstünde beyaz artı (Finder'a eklenenler).
import AppKit

func hex(_ v: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}
func rr(_ r: NSRect, _ c: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: c, yRadius: c) }
func shadow(_ a: CGFloat, blur: CGFloat, y: CGFloat, color: NSColor = .black) {
    let s = NSShadow(); s.shadowColor = color.withAlphaComponent(a); s.shadowBlurRadius = blur; s.shadowOffset = NSSize(width: 0, height: y); s.set()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Gövde: macOne ile aynı açık zemin (macOS ikon ızgarası: 1024 içinde 824'lük kare)
let body = rr(NSRect(x: 100, y: 100, width: 824, height: 824), 185)
NSGraphicsContext.saveGraphicsState(); shadow(0.22, blur: 28, y: -12); hex(0xF2F3F6).setFill(); body.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [hex(0xFFFFFF), hex(0xE4E6EC)])!.draw(in: body, angle: -90)
hex(0x000000, 0.06).setStroke(); body.lineWidth = 2; body.stroke()

// Klasörün arka yüzü ve sekmesi
let back = NSBezierPath()
back.append(rr(NSRect(x: 230, y: 250, width: 564, height: 470), 48))
back.append(rr(NSRect(x: 230, y: 640, width: 250, height: 120), 40))
NSGraphicsContext.saveGraphicsState(); shadow(0.25, blur: 28, y: -12, color: hex(0x2F6BEF)); hex(0x3A78E8).setFill(); back.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [hex(0x4F8EF5), hex(0x3466D9)])!.draw(in: back, angle: -90)

// Ön yüz
let front = rr(NSRect(x: 230, y: 250, width: 564, height: 400), 48)
NSGraphicsContext.saveGraphicsState(); shadow(0.2, blur: 16, y: -6); hex(0x2F7BF6).setFill(); front.fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [hex(0x7FD4FF), hex(0x3F8CF7), hex(0x5E5CE6)])!.draw(in: front, angle: -60)
NSGraphicsContext.saveGraphicsState(); front.addClip()
NSGradient(colors: [.white.withAlphaComponent(0.25), .white.withAlphaComponent(0)])!.draw(in: NSRect(x: 230, y: 520, width: 564, height: 130), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Artı
let plus = NSBezierPath()
plus.append(rr(NSRect(x: 512 - 120, y: 450 - 30, width: 240, height: 60), 30))
plus.append(rr(NSRect(x: 512 - 30, y: 450 - 120, width: 60, height: 240), 30))
NSGraphicsContext.saveGraphicsState(); shadow(0.2, blur: 10, y: -4); hex(0xFFFFFF, 0.96).setFill(); plus.fill(); NSGraphicsContext.restoreGraphicsState()

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
