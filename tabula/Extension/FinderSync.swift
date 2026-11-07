import Cocoa
import FinderSync

// Finder sağ tık menüsünü kurar; işi Actions.swift yapar.
//   klasörün boş yeri → Yeni Dosya ▸ …, Burada Terminal Aç, Kesilenleri Buraya Taşı
//   seçili öğeler     → Kes (Windows'taki Ctrl+X; sonra boş yerde "Buraya Taşı")
class FinderSync: FIFinderSync {
    private var controller: FIFinderSyncController { .default() }

    override init() {
        super.init()
        controller.directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let menu = NSMenu()
        func add(_ title: String, _ sel: Selector, to m: NSMenu, tag: Int = 0) {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: ""); i.target = self; i.tag = tag; m.addItem(i)
        }
        switch menuKind {
        case .contextualMenuForItems:
            add("Kes", #selector(cutSelected), to: menu)
        case .contextualMenuForContainer:
            let sub = NSMenu()
            for (i, t) in types.enumerated() { add(t.title, #selector(newFile(_:)), to: sub, tag: i) }
            let top = NSMenuItem(title: "Yeni Dosya", action: nil, keyEquivalent: ""); top.submenu = sub
            menu.addItem(top)
            add("Burada Terminal Aç", #selector(terminal), to: menu)
            if !cutPaths.isEmpty { add("Kesilen \(cutPaths.count) Öğeyi Buraya Taşı", #selector(moveHere), to: menu) }
        default:
            return nil
        }
        return menu
    }

    @objc func newFile(_ sender: NSMenuItem) {
        if let dir = controller.targetedURL() { createFile(in: dir, type: types[sender.tag]) }
    }
    @objc func cutSelected() { cutPaths = (controller.selectedItemURLs() ?? []).map(\.path) }
    @objc func moveHere() { if let dir = controller.targetedURL() { moveCut(to: dir) } }
    @objc func terminal() { if let dir = controller.targetedURL() { openTerminal(at: dir) } }
}
