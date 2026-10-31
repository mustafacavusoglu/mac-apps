// Ekranın ortasındaki pencere seçici panel.
import AppKit
import ScreenCaptureKit

final class Switcher {
    let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let root = NSView(), grid = NSStackView()
    private var wins: [Win] = [], tiles: [Tile] = [], sel = 0, perRow = 1
    private var pendingShow: DispatchWorkItem?, thumbs: Task<Void, Never>?
    private(set) var isOpen = false

    init() {
        panel.level = .popUpMenu; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        grid.orientation = .vertical; grid.spacing = 6; grid.alignment = .centerX
        let hint = label("⌥ bırak  geç     ⇥ / ← →  seç     ⇧⇥  geri     esc  vazgeç", size: 11, weight: .regular, color: .tertiaryLabelColor)
        let col = NSStackView(views: [grid, hint]); col.orientation = .vertical; col.spacing = 10
        col.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)
        col.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(col)
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: root.leadingAnchor), col.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            col.topAnchor.constraint(equalTo: root.topAnchor), col.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        if #available(macOS 26, *) {  // Liquid Glass
            let glass = NSGlassEffectView(); glass.cornerRadius = 26; glass.contentView = root
            panel.contentView = glass
        } else {
            let bg = NSVisualEffectView(); bg.material = .popover; bg.state = .active
            bg.wantsLayer = true; bg.layer?.cornerRadius = 20; bg.layer?.cornerCurve = .continuous; bg.layer?.masksToBounds = true
            root.frame = bg.bounds; root.autoresizingMask = [.width, .height]; bg.addSubview(root)
            panel.contentView = bg
        }
    }

    func open(backwards: Bool) {
        wins = listWindows()
        guard !wins.isEmpty, let screen = NSScreen.main else { return }
        isOpen = true
        tiles = wins.indices.map { i in let t = Tile(wins[i]); t.onClick = { [unowned self] in sel = i; commit() }; return t }
        perRow = max(1, min(tiles.count, Int((screen.visibleFrame.width * 0.9 - 32) / (Tile.size.width + 6))))
        grid.setViews(stride(from: 0, to: tiles.count, by: perRow).map { i in
            let r = NSStackView(views: Array(tiles[i..<min(i + perRow, tiles.count)])); r.spacing = 6; return r
        }, in: .top)
        sel = wins.count > 1 ? (backwards ? wins.count - 1 : 1) : 0
        highlight()

        // Hızlı ⌥Tab'da panel hiç görünmeden önceki pencereye geçilir.
        let show = DispatchWorkItem { [self] in
            panel.setContentSize(root.fittingSize)
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - panel.frame.width / 2, y: f.midY - panel.frame.height / 2 + f.height * 0.05))
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
        }
        pendingShow = show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: show)

        guard CGPreflightScreenCaptureAccess() else { return }  // izin yoksa uygulama ikonlarıyla kal
        let jobs = zip(wins, tiles).map { ($0.id, $1.shot.size, $1) }
        thumbs = Task { @MainActor in
            guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) else { return }
            await withTaskGroup(of: Void.self) { g in
                for (id, size, tile) in jobs {
                    g.addTask { @MainActor in if let img = await thumbnail(id, size: size, in: content), !Task.isCancelled { tile.show(img) } }
                }
            }
        }
    }

    func step(_ d: Int) { sel = (sel + d + wins.count) % wins.count; highlight() }
    func row(_ d: Int) { let n = sel + d * perRow; if wins.indices.contains(n) { sel = n; highlight() } }
    private func highlight() { for (i, t) in tiles.enumerated() { t.selected = i == sel } }

    func cancel() {
        pendingShow?.cancel(); thumbs?.cancel(); isOpen = false
        panel.orderOut(nil); grid.setViews([], in: .top); tiles = []
    }
    func commit() { let w = wins.indices.contains(sel) ? wins[sel] : nil; cancel(); if let w { focus(w) } }
}
