// Panelde tek bir pencere kutucuğu: küçük resim, uygulama rozeti, başlık.
import AppKit

func label(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
    let l = NSTextField(labelWithString: s)
    l.font = .systemFont(ofSize: size, weight: weight); l.textColor = color
    l.alignment = .center; l.lineBreakMode = .byTruncatingTail
    return l
}

final class Tile: NSView {
    static let size = NSSize(width: 236, height: 190), box = NSSize(width: 216, height: 132)
    let shot: NSRect
    let thumb = NSImageView(), placeholder = NSImageView()
    var selected = false { didSet { restyle() } }
    var hovered = false { didSet { restyle() } }
    var onClick: () -> Void = {}
    override var isFlipped: Bool { true }

    init(_ w: Win) {
        // Küçük resim, pencerenin en-boy oranıyla kutuya sığdırılır.
        let s = min(Tile.box.width / w.size.width, Tile.box.height / w.size.height)
        let sz = NSSize(width: (w.size.width * s).rounded(), height: (w.size.height * s).rounded())
        shot = NSRect(x: 10 + (Tile.box.width - sz.width) / 2, y: 10 + (Tile.box.height - sz.height) / 2, width: sz.width, height: sz.height)
        super.init(frame: NSRect(origin: .zero, size: Tile.size))
        wantsLayer = true; layer?.cornerRadius = 14; layer?.cornerCurve = .continuous
        widthAnchor.constraint(equalToConstant: Tile.size.width).isActive = true
        heightAnchor.constraint(equalToConstant: Tile.size.height).isActive = true

        thumb.frame = shot; thumb.imageScaling = .scaleAxesIndependently; thumb.wantsLayer = true
        thumb.layer?.cornerRadius = 8; thumb.layer?.cornerCurve = .continuous; thumb.layer?.masksToBounds = true
        thumb.layer?.borderWidth = 0.5
        placeholder.image = w.icon; placeholder.frame = NSRect(x: shot.midX - 32, y: shot.midY - 32, width: 64, height: 64)

        let badge = NSImageView(image: w.icon ?? NSImage())  // küçük resmin köşesinde uygulama ikonu
        badge.frame = NSRect(x: max(2, shot.minX - 6), y: shot.maxY - 26, width: 34, height: 34)
        badge.shadow = { let s = NSShadow(); s.shadowBlurRadius = 4; s.shadowOffset = NSSize(width: 0, height: -1); s.shadowColor = .black.withAlphaComponent(0.35); return s }()

        let title = label(w.title.isEmpty ? w.app : w.title, size: 12.5, weight: .medium, color: .labelColor)
        title.frame = NSRect(x: 12, y: 150, width: Tile.size.width - 24, height: 17)
        let app = label(w.app, size: 11, weight: .regular, color: .secondaryLabelColor)
        app.frame = NSRect(x: 12, y: 168, width: Tile.size.width - 24, height: 15)
        app.isHidden = w.title.isEmpty || w.title == w.app

        for v in [thumb, placeholder, badge, title, app] { addSubview(v) }
        restyle()
    }
    required init?(coder: NSCoder) { nil }

    func show(_ img: NSImage) { thumb.image = img; placeholder.isHidden = true }

    func restyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let accent = NSColor.controlAccentColor
            layer?.backgroundColor = selected ? accent.withAlphaComponent(0.28).cgColor
                : hovered ? NSColor.labelColor.withAlphaComponent(0.07).cgColor : nil
            layer?.borderWidth = selected ? 1.5 : 0
            layer?.borderColor = accent.withAlphaComponent(0.9).cgColor
            thumb.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
            thumb.layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
        }
    }
    override func viewDidChangeEffectiveAppearance() { restyle() }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func mouseDown(with event: NSEvent) { onClick() }
}
