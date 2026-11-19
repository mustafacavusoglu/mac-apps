// Resources/AppIcon.icns ve docs/icon.png üretir. speed-test klasöründen: swift tools/make_icon.swift
// Motif: uygulamanın kendi ibresi — mavi→mor yay, ibre, orta nokta.
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

// İbre yayı: 270°, sol alttan (225°) saat yönünde sağ alta (-45°)
let c = NSPoint(x: 512, y: 470), r: CGFloat = 250, w: CGFloat = 74
func arc(_ from: CGFloat, _ to: CGFloat) -> NSBezierPath {
    let p = NSBezierPath(); p.appendArc(withCenter: c, radius: r, startAngle: from, endAngle: to, clockwise: true); return p
}
func strokeShape(_ p: NSBezierPath) -> NSBezierPath {  // kalın çizginin dış hattı (degrade ile doldurmak için)
    let s = p.cgPath.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 10)
    return NSBezierPath(cgPath: s)
}
let track = arc(225, -45); track.lineWidth = w; track.lineCapStyle = .round
hex(0x000000, 0.07).setStroke(); track.stroke()

let end: CGFloat = 225 - 270 * 0.72  // %72 dolu
let fill = strokeShape(arc(225, end))
NSGraphicsContext.saveGraphicsState(); shadow(0.45, blur: 30, y: 0, color: hex(0x5E5CE6)); hex(0x5E5CE6).setFill(); fill.fill(); NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState(); fill.addClip()
NSGradient(colors: [hex(0x64D2FF), hex(0x5E8BF0), hex(0x5E5CE6), hex(0xBF5AF2)])!.draw(in: NSRect(x: c.x - r - w, y: c.y - r - w, width: 2 * (r + w), height: 2 * (r + w)), angle: -20)
NSGraphicsContext.restoreGraphicsState()

// İbre ve merkez
let a = end * .pi / 180
let tip = NSPoint(x: c.x + cos(a) * (r - 70), y: c.y + sin(a) * (r - 70))
let needle = NSBezierPath(); needle.move(to: c); needle.line(to: tip)
needle.lineWidth = 26; needle.lineCapStyle = .round
NSGraphicsContext.saveGraphicsState(); shadow(0.25, blur: 12, y: -4); hex(0x1D1D1F).setStroke(); needle.stroke(); NSGraphicsContext.restoreGraphicsState()
hex(0x1D1D1F).setFill(); NSBezierPath(ovalIn: NSRect(x: c.x - 44, y: c.y - 44, width: 88, height: 88)).fill()
hex(0xFFFFFF).setFill(); NSBezierPath(ovalIn: NSRect(x: c.x - 16, y: c.y - 16, width: 32, height: 32)).fill()

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
