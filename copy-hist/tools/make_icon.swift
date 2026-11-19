// Resources/AppIcon.icns ve docs/icon.png üretir. copy-hist klasöründen: swift tools/make_icon.swift
// Motif: pano panosu; arkasında soluk bir sayfa daha (geçmiş).
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

// Arkadaki sayfa (geçmiş)
let back = NSRect(x: 330, y: 250, width: 420, height: 520)
NSGraphicsContext.saveGraphicsState(); shadow(0.12, blur: 18, y: -6); hex(0xFFFFFF).setFill(); rr(back, 44).fill(); NSGraphicsContext.restoreGraphicsState()
hex(0x000000, 0.08).setStroke(); let bp = rr(back, 44); bp.lineWidth = 3; bp.stroke()
hex(0x000000, 0.08).setFill()
for (i, wd) in [300.0, 240.0, 280.0].enumerated() { rr(NSRect(x: back.minX + 50, y: back.minY + 70 + CGFloat(i) * 56, width: wd, height: 22), 11).fill() }

// Öndeki pano
let board = NSRect(x: 260, y: 190, width: 440, height: 540)
NSGraphicsContext.saveGraphicsState(); shadow(0.3, blur: 30, y: -12, color: hex(0x2F6BEF)); hex(0x2F7BF6).setFill(); rr(board, 48).fill(); NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [hex(0x5AC8FA), hex(0x2F7BF6), hex(0x5E5CE6)])!.draw(in: rr(board, 48), angle: -60)
NSGraphicsContext.saveGraphicsState(); rr(board, 48).addClip()
NSGradient(colors: [.white.withAlphaComponent(0.22), .white.withAlphaComponent(0)])!.draw(in: NSRect(x: board.minX, y: board.midY, width: board.width, height: board.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// Satırlar (kopyalanmış metinler)
hex(0xFFFFFF, 0.92).setFill()
for (i, wd) in [330.0, 260.0, 300.0, 200.0].enumerated() {
    rr(NSRect(x: board.minX + 55, y: board.maxY - 170 - CGFloat(i) * 84, width: wd, height: 34), 17).fill()
}

// Mandal
let clip = NSRect(x: 512 - 120, y: board.maxY - 52, width: 240, height: 100)
NSGraphicsContext.saveGraphicsState(); shadow(0.25, blur: 12, y: -5); hex(0x1D1D1F).setFill(); rr(clip, 30).fill(); NSGraphicsContext.restoreGraphicsState()
hex(0x3A3A3C).setFill(); rr(clip.insetBy(dx: 16, dy: 16), 18).fill()
hex(0xF2F3F6).setFill(); rr(NSRect(x: 512 - 40, y: clip.maxY - 34, width: 80, height: 22), 11).fill()

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
