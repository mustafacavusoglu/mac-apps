import Cocoa

// Menü eylemlerinin işi. Menü kurulumu FinderSync.swift'te.

func createFile(in dir: URL, type t: (title: String, ext: String, content: String)) {
    let url = uniqueURL(dir, name: "Yeni Dosya.\(t.ext)")
    do {
        try t.content.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    } catch {
        NSLog("Tabula yeni dosya: \(error)")
    }
}

func openTerminal(at dir: URL) {
    NSWorkspace.shared.open([dir], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                            configuration: NSWorkspace.OpenConfiguration())
}
