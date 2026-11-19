import AppKit

// MARK: - Dosya yardımcıları (bütün sekmeler)

let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser
func lib(_ p: String) -> URL { home.appendingPathComponent("Library/" + p) }
func hm(_ p: String) -> URL { home.appendingPathComponent(p) }
func fmt(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }
/// Ev klasörü yolunu "~" ile kısaltır (ekranda göstermek için).
func tilde(_ p: String) -> String { p.replacingOccurrences(of: home.path, with: "~") }

func children(_ dir: URL) -> [URL] {
    (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
}

/// Ev klasörünün bulunduğu birimde kullanılabilir alan.
func freeSpace() -> Int64 {
    (try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage ?? 0
}

/// Diskte gerçekten kapladığı alan; symlink takip edilmez. Klasörler getattrlistbulk ile gezilir (FastScan.swift).
func allocatedSize(_ url: URL) -> Int64 {
    let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isSymbolicLinkKey, .isDirectoryKey]
    guard let v = try? url.resourceValues(forKeys: keys), v.isSymbolicLink != true else { return 0 }
    guard v.isDirectory == true else { return Int64(v.totalFileAllocatedSize ?? 0) }
    func tree(_ p: String) -> Int64 { listDir(p).reduce(0) { $0 + ($1.isDir ? tree(join(p, $1.name)) : $1.size) } }
    return tree(url.path)
}

/// Satır başına NSWorkspace.icon çağrısı her render'da pahalı; yola göre tek önbellek.
private let iconCache = NSCache<NSString, NSImage>()
func icon(_ path: String) -> NSImage {
    if let i = iconCache.object(forKey: path as NSString) { return i }
    let i = NSWorkspace.shared.icon(forFile: path)
    iconCache.setObject(i, forKey: path as NSString)
    return i
}

/// Sıra korunarak paralel map (çekirdek sayısı kadar iş parçacığı).
func parallelMap<T: Sendable, R: Sendable>(_ a: [T], _ f: @Sendable (T) -> R) -> [R] {
    var out = [R?](repeating: nil, count: a.count)
    out.withUnsafeMutableBufferPointer { buf in
        let p = buf
        DispatchQueue.concurrentPerform(iterations: a.count) { p[$0] = f(a[$0]) }
    }
    return out.map { $0! }
}

/// Resmi API yok; TCC korumalı bir klasörü okumayı deneriz (sezgisel).
func hasFullDiskAccess() -> Bool { (try? fm.contentsOfDirectory(atPath: lib("Safari").path)) != nil }

func modDate(_ u: URL) -> Date? { (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate }
func dateText(_ d: Date?) -> String { d?.formatted(date: .abbreviated, time: .omitted) ?? "–" }

// MARK: - Listelenen öğe

struct Entry: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let size: Int64
    var date: Date? = nil
    var name: String { url.lastPathComponent }
    var folder: String { tilde(url.deletingLastPathComponent().path) }
    var modified: Date { date ?? .distantPast }
}

extension Entry {
    /// listDir sonucundan: klasörün boyutu `sizes`ten (alt ağaç toplamı), dosyanınki kendisinden.
    init(in dir: String, _ e: RawEntry, sizes: [String: Int64]) {
        let p = join(dir, e.name)
        self.init(url: URL(fileURLWithPath: p, isDirectory: e.isDir), size: e.isDir ? sizes[p] ?? 0 : e.size, date: e.mtime)
    }
}

extension Sequence<Entry> {
    var totalSize: Int64 { reduce(0) { $0 + $1.size } }
}

enum SortKey: String, CaseIterable { case size = "Boyut", date = "Tarih", name = "Ad" }

func sorted(_ e: [Entry], by k: SortKey) -> [Entry] {
    switch k {
    case .size: e.sorted { $0.size > $1.size }
    case .date: e.sorted { $0.modified > $1.modified }
    case .name: e.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
