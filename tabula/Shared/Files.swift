import Cocoa

// Ana uygulama ile Finder eklentisinin ortak kodu: çakışmayan ad, "kesilenler" listesi, taşıma.

func uniqueURL(_ dir: URL, name: String) -> URL {
    var url = dir.appendingPathComponent(name)
    let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
    var n = 2
    while FileManager.default.fileExists(atPath: url.path) {
        url = dir.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"); n += 1
    }
    return url
}

// Kesilenler dosyada durur: eklenti sandbox'ta, ana uygulama dışında; ikisi de gerçek ev klasörünü görür.
private let cutFile: URL = {
    let home = String(cString: getpwuid(getuid()).pointee.pw_dir)
    return URL(fileURLWithPath: home + "/Library/Application Support/Tabula/cut.txt")
}()

var cutPaths: [String] {
    get { ((try? String(contentsOf: cutFile, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
    set {
        try? FileManager.default.createDirectory(at: cutFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? newValue.joined(separator: "\n").write(to: cutFile, atomically: true, encoding: .utf8)
    }
}

func moveCut(to dir: URL) {
    var moved: [URL] = []
    let dirPath = dir.standardizedFileURL.path
    for path in cutPaths {
        let src = URL(fileURLWithPath: path)
        let srcPath = src.standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: srcPath),
              src.deletingLastPathComponent().standardizedFileURL.path != dirPath,  // zaten orada
              !(dirPath + "/").hasPrefix(srcPath + "/")                              // klasör kendi içine taşınmaz
        else { continue }
        let dst = uniqueURL(dir, name: src.lastPathComponent)
        do { try FileManager.default.moveItem(at: src, to: dst); moved.append(dst) }
        catch { NSLog("Tabula taşıma: \(error)") }
    }
    cutPaths = []
    if !moved.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(moved) }
}
