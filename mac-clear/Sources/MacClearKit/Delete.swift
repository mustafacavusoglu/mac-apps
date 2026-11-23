import AppKit
import SwiftUI

// MARK: - Silme güvenliği ve ortak işlem akışı
// Bütün sekmelerdeki silme / Çöp Sepeti'ne taşıma / kaldırma / devre dışı bırakma `perform`dan geçer:
// satırlar soluklaşır → yüzen kutuda ilerleme → biten satırlar animasyonla çıkar → sonuç bildirimi (+ Geri al).
// Kural: Çöp Sepeti'ne giden her şey onaysız ve geri alınabilir; kalıcı silme her zaman onay ister (CleanButton sorar).

/// Güvenlik ağı: yalnızca ev dizininin içi (kökün kendisi değil) ve /Applications/*.app silinebilir.
/// Symlink'ler ve `..` çözülür; ~/X klasörleri ve ~/Library/X kökleri korunur (APFS büyük/küçük harf duyarsız).
func isSafe(_ u: URL) -> Bool {
    let c = u.standardizedFileURL.resolvingSymlinksInPath().pathComponents
    let h = home.standardizedFileURL.pathComponents
    if c.count == 3, c[1] == "Applications", c[2].hasSuffix(".app") { return true }
    guard c.count > h.count, Array(c.prefix(h.count)) == h else { return false }
    if c.count == h.count + 1 { // ~/X: sadece dosya ya da ~/Applications değil
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: u.path, isDirectory: &isDir) && !isDir.boolValue
    }
    return !(c.count == h.count + 2 && c[h.count].lowercased() == "library") // ~/Library/Caches gibi kökler korunur
}

/// `mac-clear --selftest`: silme güvenlik ağını doğrular.
func selfTest() {
    let ok = [lib("Caches/foo"), hm("Documents/a.iso"), hm(".Trash/x"), URL(fileURLWithPath: "/Applications/Foo.app")]
    let bad = [home, lib(""), lib("Caches"), hm("library/Caches"), hm("Documents"), URL(fileURLWithPath: "/"), URL(fileURLWithPath: "/Applications"),
               URL(fileURLWithPath: "/System/Library/x"), URL(fileURLWithPath: "/Users/Shared/x"), lib("Caches/../../..")]
    for u in ok { precondition(isSafe(u), "güvenli olmalı: \(u.path)") }
    for u in bad { precondition(!isSafe(u), "reddedilmeli: \(u.path)") }
    print("selftest ok")
}

func log(_ urls: [URL], permanent: Bool) {
    guard !urls.isEmpty else { return }
    let line = urls.map { "\(Date()) \(permanent ? "SİLİNDİ" : "ÇÖPE") \($0.path)\n" }.joined()
    let f = lib("Logs/Mac-Clear.log")
    if let h = try? FileHandle(forWritingTo: f) {
        h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
    } else {
        try? Data(line.utf8).write(to: f)
    }
}

struct Toast: Identifiable {
    let id = UUID()
    let ok: Bool
    let title: String
    let detail: String?
    let undo: (@MainActor () async -> Void)?
}

/// Yüzen kutunun durumu (yalnızca HUD gözlemler; ilerleme tikleri listeleri yeniden çizdirmesin).
@MainActor final class Activity: ObservableObject {
    static let shared = Activity()
    @Published fileprivate(set) var title: String?
    @Published fileprivate(set) var done = 0
    @Published fileprivate(set) var total = 0
    @Published fileprivate(set) var toast: Toast?
    private var dismiss: Task<Void, Never>?

    func show(ok: Bool, _ title: String, detail: String? = nil, undo: (@MainActor () async -> Void)? = nil) {
        let t = Toast(ok: ok, title: title, detail: detail, undo: undo)
        toast = t
        dismiss?.cancel()
        dismiss = Task {
            try? await Task.sleep(for: .seconds(!ok ? 10 : undo == nil ? 4 : 8))
            if toast?.id == t.id { toast = nil }
        }
    }

    func close() { toast = nil }
}

/// İşlemdeki satırlar ve meşguliyet; satırlar ve düğmeler bunu gözlemler (işlem başında ve sonunda değişir).
@MainActor final class Working: ObservableObject {
    static let shared = Working()
    @Published fileprivate(set) var pending: Set<URL> = []
    var busy: Bool { !pending.isEmpty }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    func add() { lock.withLock { n += 1 } }
    var value: Int { lock.withLock { n } }
}

func sizeMap(_ e: [Entry]) -> [URL: Int64] { Dictionary(e.map { ($0.url, $0.size) }, uniquingKeysWith: { a, _ in a }) }

/// Silme / taşıma. `permanent` içindekiler kalıcı silinir, diğerleri Çöp Sepeti'ne gider.
/// Dönen küme: gerçekten kaldırılanlar; çağıran bunları listeden animasyonla çıkarır.
/// - working: kutuda işlem sürerken görünen yazı; headline: sonuç başlığı (yoksa "1,2 GB <verb>").
/// - before: her öğeden önce arka planda çalışır (ör. launchctl bootout).
/// - undone: Geri al'dan sonra, geri gelen URL'lerle çağrılır (listeyi yenilemek için).
@MainActor @discardableResult
func perform(_ urls: [URL], permanent: Set<URL> = [], sizes: [URL: Int64] = [:], verb: String,
             working: String? = nil, headline: String? = nil,
             before: (@Sendable (URL) -> Void)? = nil,
             undone: (@MainActor ([URL]) async -> Void)? = nil) async -> Set<URL> {
    let w = Working.shared, a = Activity.shared
    guard !w.busy, !urls.isEmpty else { return [] }
    let safe = urls.filter(isSafe)
    var errors = urls.filter { !isSafe($0) }.map { "\($0.lastPathComponent): güvenlik nedeniyle atlandı" }

    withAnimation(.easeInOut(duration: 0.2)) { w.pending = Set(urls) }
    a.title = working ?? (permanent.isEmpty ? "Çöp Sepeti'ne taşınıyor…" : "Temizleniyor…")
    a.done = 0; a.total = urls.count; a.toast = nil

    let counter = Counter()
    let poll = Task { while !Task.isCancelled { a.done = counter.value; try? await Task.sleep(for: .milliseconds(100)) } }
    let r = await Task.detached { () -> (errs: [String], moved: [URL: URL], needAuth: [URL]) in
        let lock = NSLock()
        var errs: [String] = [], moved: [URL: URL] = [:], needAuth: [URL] = []
        let perm = safe.filter(permanent.contains), toTrash = safe.filter { !permanent.contains($0) }
        /// Silmeden hemen önce yeniden denetle: büyük işlerde ilk denetimle silme arasında saniyeler geçebilir
        /// (bu arada bir üst klasör symlink'e çevrilirse). ponytail: pencere daralır ama sıfırlanmaz; tam çözüm openat/unlinkat + O_NOFOLLOW.
        func stillSafe(_ u: URL) -> Bool {
            if isSafe(u) { return true }
            lock.withLock { errs.append("\(u.lastPathComponent): güvenlik nedeniyle atlandı") }
            return false
        }
        // Kalıcı silme paralel (büyük önbellek klasörlerinde fark eder); Çöp Sepeti'ne taşıma sıralı (ad çakışması olmasın).
        DispatchQueue.concurrentPerform(iterations: perm.count) { i in
            let u = perm[i]
            defer { counter.add() }
            guard stillSafe(u) else { return }
            before?(u)
            do { try fm.removeItem(at: u) } catch { lock.withLock { errs.append("\(u.lastPathComponent): \(error.localizedDescription)") } }
        }
        for u in toTrash {
            defer { counter.add() }
            guard stillSafe(u) else { continue }
            before?(u)
            var out: NSURL?
            do { try fm.trashItem(at: u, resultingItemURL: &out); if let o = out as URL? { moved[u] = o } }
            catch let e as CocoaError where e.code == .fileWriteNoPermission { needAuth.append(u) } // root'a ait: Finder gibi yetki iste
            catch { errs.append("\(u.lastPathComponent): \(error.localizedDescription)") }
        }
        return (errs, moved, needAuth)
    }.value
    errors += r.errs
    var moved = r.moved
    if !r.needAuth.isEmpty {
        do { moved.merge(try await NSWorkspace.shared.recycle(r.needAuth)) { $1 } }
        catch { if let e = finderTrash(r.needAuth) { errors.append(e) } }
    }
    poll.cancel()

    let gone = Set(safe.filter { !fm.fileExists(atPath: $0.path) })
    log(gone.filter(permanent.contains).sorted { $0.path < $1.path }, permanent: true)
    log(gone.filter { !permanent.contains($0) }.sorted { $0.path < $1.path }, permanent: false)
    DiskIndex.shared.refreshParents(of: Array(gone))

    a.done = a.total
    a.title = nil
    withAnimation(.easeInOut(duration: 0.2)) { w.pending = [] }

    let bytes = gone.reduce(Int64(0)) { $0 + (sizes[$1] ?? 0) }
    let summary = bytes > 0 ? "\(fmt(bytes)) \(verb)" : "\(gone.count) öğe \(verb)"
    let restorable = moved.filter { gone.contains($0.key) }
    var undo: (@MainActor () async -> Void)?
    if !restorable.isEmpty { undo = { await restore(restorable, then: undone) } }
    if errors.isEmpty {
        a.show(ok: true, headline ?? summary, detail: headline != nil ? summary : (bytes > 0 ? "\(gone.count) öğe" : nil), undo: undo)
    } else {
        a.show(ok: false, gone.isEmpty ? "İşlem yapılamadı" : "\(summary), \(errors.count) öğe yapılamadı",
               detail: errors.prefix(2).joined(separator: "\n"), undo: undo)
    }
    return gone
}

/// Root'a ait ya da macOS'un Uygulama Yönetimi korumasındaki uygulamalar (ör. Zoom) bizim süreçten taşınamaz.
/// Finder'a bırakılır: o gerekirse yönetici parolasını sorar, öğe Çöp Sepeti'ne gider.
@MainActor func finderTrash(_ urls: [URL]) -> String? {
    let esc = { (s: String) in s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
    let list = urls.filter { fm.fileExists(atPath: $0.path) }.map { "POSIX file \"\(esc($0.path))\"" }
    guard !list.isEmpty else { return nil }
    var err: NSDictionary?
    NSAppleScript(source: "tell application \"Finder\" to delete {\(list.joined(separator: ", "))}")?.executeAndReturnError(&err)
    return err.map { "Finder: \($0[NSAppleScript.errorMessage] as? String ?? "taşınamadı")" }
}

@MainActor private func restore(_ moved: [URL: URL], then: (@MainActor ([URL]) async -> Void)?) async {
    let a = Activity.shared
    a.toast = nil
    var errs: [String] = []
    for (orig, t) in moved {
        do { try fm.moveItem(at: t, to: orig) } catch { errs.append("\(orig.lastPathComponent): \(error.localizedDescription)") }
    }
    let back = moved.keys.filter { fm.fileExists(atPath: $0.path) }
    DiskIndex.shared.refreshParents(of: back)
    await then?(back)
    a.show(ok: errs.isEmpty, errs.isEmpty ? "\(back.count) öğe geri alındı" : "Bazı öğeler geri alınamadı", detail: errs.first)
}

/// `mac-clear --selftest` parçası: kalıcı silme, Çöp Sepeti'ne taşıma ve Geri al uçtan uca (geçici klasörde).
@MainActor func performSelfTest() async {
    let base = lib("Caches/mac-clear-perform-test")
    defer { try? fm.removeItem(at: base) }
    try? fm.createDirectory(at: base, withIntermediateDirectories: true)
    let (a, b, c) = (base.appendingPathComponent("a"), base.appendingPathComponent("b"), base.appendingPathComponent("c"))
    for u in [a, b, c] { fm.createFile(atPath: u.path, contents: Data(count: 4096)) }
    let link = base.appendingPathComponent("link")
    try? fm.createSymbolicLink(at: link, withDestinationURL: URL(fileURLWithPath: "/System"))
    precondition(!isSafe(link.appendingPathComponent("Library")), "symlink üzerinden ev dışına çıkılmamalı")

    var gone = await perform([a], permanent: [a], verb: "temizlendi")
    precondition(gone == [a] && !fm.fileExists(atPath: a.path), "kalıcı silme")
    precondition(Activity.shared.toast?.undo == nil, "kalıcı silmede Geri al olmamalı")

    var restored: [URL] = []
    gone = await perform([b, c], sizes: [b: 10, c: 20], verb: "Çöp Sepeti'ne taşındı", undone: { restored = $0 })
    precondition(gone == [b, c] && !fm.fileExists(atPath: b.path), "Çöp Sepeti'ne taşıma")
    precondition(Activity.shared.toast?.title == "\(fmt(30)) Çöp Sepeti'ne taşındı", "özet: \(Activity.shared.toast?.title ?? "-")")
    await Activity.shared.toast?.undo?()
    precondition(fm.fileExists(atPath: b.path) && fm.fileExists(atPath: c.path) && Set(restored) == [b, c], "Geri al")

    gone = await perform([URL(fileURLWithPath: "/System/x")], verb: "temizlendi")
    precondition(gone.isEmpty && Activity.shared.toast?.ok == false, "güvensiz yol reddedilmeli")
    precondition(!Working.shared.busy, "işlem sonrası meşgul kalmamalı")
    print("perform selftest ok")
}
