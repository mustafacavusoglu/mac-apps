import Cocoa
import FinderSync

// Finder'da klasörün boş yerine sağ tık → "Yeni Dosya" alt menüsü.
// Yeni tür eklemek için aşağıdaki listeye bir satır yeter.
private let types: [(title: String, ext: String, content: String)] = [
    ("Metin Belgesi (.txt)", "txt", ""),
    ("Markdown (.md)", "md", ""),
    ("JSON (.json)", "json", "{}\n"),
    ("CSV (.csv)", "csv", ""),
    ("HTML (.html)", "html", "<!doctype html>\n<title></title>\n"),
    ("Python (.py)", "py", ""),
    ("Kabuk Betiği (.sh)", "sh", "#!/bin/sh\n"),
]

class FinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer else { return nil }
        let sub = NSMenu()
        for (i, t) in types.enumerated() {
            let item = NSMenuItem(title: t.title, action: #selector(create(_:)), keyEquivalent: "")
            item.tag = i; item.target = self
            sub.addItem(item)
        }
        let menu = NSMenu()
        let top = NSMenuItem(title: "Yeni Dosya", action: nil, keyEquivalent: "")
        top.submenu = sub
        menu.addItem(top)
        return menu
    }

    @objc func create(_ sender: NSMenuItem) {
        guard let dir = FIFinderSyncController.default().targetedURL() else { return }
        let t = types[sender.tag]
        var url = dir.appendingPathComponent("Yeni Dosya.\(t.ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("Yeni Dosya \(n).\(t.ext)"); n += 1
        }
        do {
            try t.content.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSLog("NewFile: \(error)")
        }
    }
}
