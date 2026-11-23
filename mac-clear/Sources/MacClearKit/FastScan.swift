import AppKit
import CoreServices
import Darwin

// MARK: - Hızlı disk taraması
// FileManager.enumerator + URL.resourceValues dosya başına nesne/sistem çağrısı üretir ve yavaştır.
// Burada getattrlistbulk ile klasör başına tek çağrıda ad/tür/tarih/boyut alınır, klasörler paralel gezilir.

struct RawEntry { let name: String; let isDir: Bool; let size: Int64; let mtime: Date }

/// Tek klasörün çocukları (symlink'ler takip edilmez, klasör sayılmaz). Açılamazsa (yok / TCC) nil.
func listDirChecked(_ path: String) -> [RawEntry]? {
    let fd = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
    guard fd >= 0 else { return nil }
    defer { close(fd) }
    var al = attrlist()
    al.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
    al.commonattr = ATTR_CMN_RETURNED_ATTRS | attrgroup_t(ATTR_CMN_NAME | ATTR_CMN_OBJTYPE | ATTR_CMN_MODTIME)
    al.fileattr = attrgroup_t(ATTR_FILE_ALLOCSIZE)
    let cap = 256 * 1024
    let buf = UnsafeMutableRawPointer.allocate(byteCount: cap, alignment: 8)
    defer { buf.deallocate() }
    var out: [RawEntry] = []
    while true {
        let n = getattrlistbulk(fd, &al, buf, cap, 0)
        if n <= 0 { break }
        var p = UnsafeRawPointer(buf)
        for _ in 0..<n {
            let len = Int(p.loadUnaligned(as: UInt32.self))
            var q = p + 4
            let ret = q.loadUnaligned(as: attribute_set_t.self)
            q += MemoryLayout<attribute_set_t>.size
            var name = ""
            if ret.commonattr & attrgroup_t(ATTR_CMN_NAME) != 0 {
                let ref = q.loadUnaligned(as: attrreference_t.self)
                name = String(cString: (q + Int(ref.attr_dataoffset)).assumingMemoryBound(to: CChar.self))
                q += MemoryLayout<attrreference_t>.size
            }
            var type: UInt32 = 0
            if ret.commonattr & attrgroup_t(ATTR_CMN_OBJTYPE) != 0 { type = q.loadUnaligned(as: UInt32.self); q += 4 }
            var mt = timespec()
            if ret.commonattr & attrgroup_t(ATTR_CMN_MODTIME) != 0 { mt = q.loadUnaligned(as: timespec.self); q += MemoryLayout<timespec>.size }
            var size: Int64 = 0
            if ret.fileattr & attrgroup_t(ATTR_FILE_ALLOCSIZE) != 0 { size = q.loadUnaligned(as: Int64.self) }
            out.append(RawEntry(name: name, isDir: type == VDIR.rawValue, size: size,
                                mtime: Date(timeIntervalSince1970: Double(mt.tv_sec) + Double(mt.tv_nsec) / 1e9)))
            p += len
        }
    }
    return out
}

func listDir(_ path: String) -> [RawEntry] { listDirChecked(path) ?? [] }

func join(_ dir: String, _ name: String) -> String { dir == "/" ? "/" + name : dir + "/" + name }

func parentPath(_ p: String) -> String {
    guard let i = p.lastIndex(of: "/") else { return p }
    return i == p.startIndex ? "/" : String(p[..<i])
}

/// Klasörlerin kendi dosya toplamlarından alt ağaç toplamlarını üretir.
func aggregate(_ own: [String: Int64], root: String) -> [String: Int64] {
    var t = own
    // Çocuk yol her zaman ebeveyninden uzundur: uzundan kısaya toplamak alt ağaçları yukarı taşır.
    for k in own.keys.sorted(by: { $0.utf8.count > $1.utf8.count }) where k != root {
        t[parentPath(k), default: 0] += t[k] ?? 0
    }
    return t
}

/// Paralel ağaç gezgini. Klasör başına kendi dosyalarının toplamını ve büyük dosyaları toplar.
// ponytail: sabit bağlantılar (hard link) ve APFS klonları her yolda ayrı sayılır; `du` ile birkaç % fark olabilir.
final class Walker: @unchecked Sendable {
    private let cond = NSCondition()
    private var stack: [String]
    private var active = 0
    private var count = 0
    private var own: [String: Int64] = [:]
    private var large: [Entry] = []
    private let root: String, largeMin: Int64, skip: Set<String>
    // Ölçüldü (ev klasörü, 465 bin klasör): 12 iş parçacığı 24 sn, 32/64 daha yavaş; darboğaz çekirdekte (sys zamanı).
    var threads = max(8, ProcessInfo.processInfo.activeProcessorCount)
    /// İsteğe bağlı: alt klasöre girilsin mi (tam yol, ad). nil = hepsine gir.
    var descend: (@Sendable (String, String) -> Bool)?

    init(root: String, largeMin: Int64, skip: Set<String> = []) {
        self.root = root; self.largeMin = largeMin; self.skip = skip; stack = [root]
    }

    var scanned: Int { cond.lock(); defer { cond.unlock() }; return count }

    /// Bloklar. sizes: alt ağaç dahil klasör toplamları, own: klasörün yalnız kendi dosyaları, large: ≥ largeMin dosyalar.
    func run() -> (sizes: [String: Int64], own: [String: Int64], large: [Entry]) {
        let g = DispatchGroup()
        for _ in 0..<threads { g.enter(); Thread { self.work(); g.leave() }.start() }
        g.wait()
        return (aggregate(own, root: root), own, large)
    }

    private func work() {
        while true {
            cond.lock()
            while stack.isEmpty && active > 0 { cond.wait() }
            guard let dir = stack.popLast() else { cond.unlock(); return }
            active += 1
            cond.unlock()

            var sum: Int64 = 0, subs: [String] = [], big: [Entry] = []
            let entries = listDir(dir)
            for e in entries {
                let p = join(dir, e.name)
                if e.isDir {
                    if !skip.contains(p) && descend?(p, e.name) != false { subs.append(p) }
                } else {
                    sum += e.size
                    if e.size >= largeMin { big.append(Entry(url: URL(fileURLWithPath: p, isDirectory: false), size: e.size, date: e.mtime)) }
                }
            }

            cond.lock()
            own[dir] = sum; stack += subs; large += big; count += entries.count; active -= 1
            cond.broadcast()
            cond.unlock()
        }
    }
}

// MARK: - Kalıcı, kendini güncelleyen disk dizini

let largeMin: Int64 = 100_000_000 // dizine alınan en küçük "büyük dosya"
let scanSkip: Set<String> = ["/Volumes", "/System/Volumes", "/dev", "/net", "/home"]

struct IndexState: Sendable {
    var own: [String: Int64] = [:]    // klasörün yalnız kendi dosyaları
    var total: [String: Int64] = [:]  // alt ağaç dahil
    var large: [Entry] = []
    var root = ""
    var minLarge = largeMin

    /// k'nin kendi boyutunu v yapar (nil: siler) ve farkı dizindeki tüm üst klasörlere yansıtır.
    /// Ekleme yaparken önce ebeveyn eklenmeli (kısa yoldan uzuna); silmede sıra önemsiz.
    mutating func setOwn(_ k: String, _ v: Int64?) {
        let old = own[k]
        if let v { own[k] = v; if old == nil { total[k] = 0 } } else { own[k] = nil; total[k] = nil }
        let d = (v ?? 0) - (old ?? 0)
        guard d != 0 else { return }
        var a = k
        while true {
            if own[a] != nil { total[a, default: 0] += d }
            if a == root || a.utf8.count <= root.utf8.count { break }
            a = parentPath(a)
        }
    }

    /// FSEvents'ten gelen değişiklikleri uygular. dirs: içeriği değişen klasörler, subtrees: baştan taranacak alt ağaçlar.
    func applying(dirs: Set<String>, subtrees: Set<String>) -> IndexState {
        var s = self
        var gone = Set<String>(), walks = Set<String>()
        for t in subtrees { gone.insert(t); if fm.fileExists(atPath: t) { walks.insert(t) } }

        let plain = dirs.subtracting(subtrees).filter { s.own[$0] != nil }
        var oldKids: [String: Set<String>] = [:]
        if !plain.isEmpty {
            for k in s.own.keys where k != s.root { let p = parentPath(k); if plain.contains(p) { oldKids[p, default: []].insert(k) } }
        }
        var listings: [String: [RawEntry]] = [:]
        for d in plain {
            guard let es = listDirChecked(d) else {
                if !fm.fileExists(atPath: d) { gone.insert(d) } // silinmiş; okunamıyorsa (TCC) olduğu gibi kalır
                continue
            }
            listings[d] = es
            let now = Set(es.filter(\.isDir).map { join(d, $0.name) }).subtracting(scanSkip)
            let before = oldKids[d] ?? []
            gone.formUnion(before.subtracting(now))
            walks.formUnion(now.subtracting(before))
        }

        if !gone.isEmpty {
            let prefixes = gone.map { $0 + "/" }
            for k in s.own.keys where gone.contains(k) || prefixes.contains(where: { k.hasPrefix($0) }) { s.setOwn(k, nil) }
            s.large.removeAll { e in prefixes.contains { e.url.path.hasPrefix($0) } }
        }
        for (d, es) in listings where s.own[d] != nil {
            s.setOwn(d, es.reduce(0) { $0 + ($1.isDir ? 0 : $1.size) })
            s.large.removeAll { parentPath($0.url.path) == d }
            s.large += es.filter { !$0.isDir && $0.size >= s.minLarge }
                .map { Entry(url: URL(fileURLWithPath: join(d, $0.name), isDirectory: false), size: $0.size, date: $0.mtime) }
        }
        for w in walks where !walks.contains(where: { w.hasPrefix($0 + "/") }) && s.own[parentPath(w)] != nil {
            let r = Walker(root: w, largeMin: s.minLarge, skip: scanSkip).run()
            for k in r.own.keys.sorted(by: { $0.utf8.count < $1.utf8.count }) { s.setOwn(k, r.own[k]) }
            s.large += r.large
        }
        return s
    }
}

/// Alan Haritası ve Büyük Dosyalar'ın paylaştığı dizin. Diske kaydedilir; açılışta FSEvents geçmişiyle
/// aradaki değişiklikler, çalışırken de canlı değişiklikler uygulanır. Tam tarama yalnızca ilk seferde gerekir.
@MainActor final class DiskIndex: ObservableObject {
    static let shared = DiskIndex()
    nonisolated static let cacheFile = lib("Caches/\(appID)/index-v1")

    @Published private(set) var sizes: [String: Int64] = [:]
    @Published private(set) var large: [Entry] = []
    @Published private(set) var scanning = false
    @Published private(set) var scanned = 0
    private(set) var root: String?
    private var state = IndexState()
    private var lastEvent: FSEventStreamEventId = 0
    private var stream: FSEventStreamRef?
    private var queue: Task<Void, Never>?
    private var started = false  // FSEvents izleniyor mu (pencere açık)
    private var loaded = false   // kayıt yüklendi / ilk tarama başladı

    func covers(_ path: String) -> Bool { root.map { $0 == "/" || path == $0 || path.hasPrefix($0 + "/") } ?? false }

    /// Mac-Clear penceresi açılınca: kayıtlı dizini yükle (yoksa arka planda ev klasörünü tara) ve değişiklikleri izle.
    /// Tekrar açılışta yalnız izleme yeniden başlar; kapalıyken olanlar FSEvents geçmişinden (lastEvent) oynatılır.
    func start() {
        guard !started else { return }
        started = true
        if loaded { watch(); return }
        loaded = true
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { DiskIndex.save(DiskIndex.shared.state, event: DiskIndex.shared.lastEvent) }
        }
        Task {
            await serial {
                let t0 = Date()
                guard let (s, ev) = await Task.detached(operation: { DiskIndex.load() }).value else { return }
                self.publish(s); self.lastEvent = ev; self.watch()
                print("dizin kayıttan yüklendi: \(s.own.count) klasör, \(String(format: "%.2f", Date().timeIntervalSince(t0))) sn")
            }
            if root == nil { await scan(home.path) }
        }
    }

    /// Pencere kapanınca: izlemeyi bırak, kaydet. Ev klasörü sürekli değiştiği için açık kalan izleme
    /// her birkaç saniyede yüz binlerce klasörlük dizini kopyalıyor, pili bitiriyordu.
    func stop() {
        guard started else { return }
        started = false
        unwatch()
        let s = state, ev = lastEvent
        Task.detached(priority: .background) { DiskIndex.save(s, event: ev) }
    }

    func ensure(_ path: String) async {
        if let q = queue { await q.value } // açılıştaki yükleme bitsin
        if !covers(path) { await scan(path) }
    }

    /// Dizin path'i kapsıyorsa yalnızca o alt ağacı yeniler; kapsamıyorsa (veya path kökse) baştan tarar.
    func scan(_ path: String) async {
        if covers(path) && path != root { await update(dirs: [], subtrees: [path]); return }
        await serial {
            let w = Walker(root: path, largeMin: largeMin, skip: scanSkip)
            let since = FSEventsGetCurrentEventId() // tarama sırasında olan değişiklikler sonra yeniden oynatılır
            self.scanning = true; self.scanned = 0
            let poll = Task { while !Task.isCancelled { self.scanned = w.scanned; try? await Task.sleep(for: .milliseconds(250)) } }
            let t0 = Date()
            let r = await Task.detached { w.run() }.value
            poll.cancel()
            print("tam tarama: \(path), \(r.own.count) klasör, \(String(format: "%.2f", Date().timeIntervalSince(t0))) sn")
            self.publish(IndexState(own: r.own, total: r.sizes, large: r.large, root: path))
            self.lastEvent = since
            self.scanning = false
            self.watch()
            let s = self.state
            Task.detached(priority: .background) { DiskIndex.save(s, event: since) }
        }
    }

    /// Silinen / geri alınan öğelerin üst klasörlerini hemen yeniler (FSEvents de birkaç saniye içinde yapardı).
    func refreshParents(of urls: [URL]) {
        let parents = Set(urls.map { parentPath($0.path) }).filter(covers)
        Task { await update(dirs: parents, subtrees: []) }
    }

    private func update(dirs: Set<String>, subtrees: Set<String>, event: FSEventStreamEventId = 0) async {
        await serial {
            guard self.root != nil else { return }
            let s0 = self.state
            let s = await Task.detached { s0.applying(dirs: dirs, subtrees: subtrees) }.value
            self.publish(s)
            self.lastEvent = max(self.lastEvent, event)
        }
    }

    /// İşleri sırayla çalıştırır (tarama ile artımlı güncelleme çakışmasın).
    private func serial(_ job: @escaping @MainActor () async -> Void) async {
        let prev = queue
        let t = Task { await prev?.value; await job() }
        queue = t
        await t.value
    }

    private func publish(_ s: IndexState) {
        state = s; root = s.root
        sizes = s.total; large = s.large
    }

    // MARK: FSEvents

    private func unwatch() {
        if let s = stream { FSEventStreamStop(s); FSEventStreamInvalidate(s); FSEventStreamRelease(s); stream = nil }
    }

    private func watch() {
        unwatch()
        guard started, let root else { return }  // pencere kapalıyken biten tarama izlemeyi yeniden açmasın
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let cb: FSEventStreamCallback = { _, info, n, paths, flags, ids in
            let me = Unmanaged<DiskIndex>.fromOpaque(info!).takeUnretainedValue()
            let ps = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            let fl = Array(UnsafeBufferPointer(start: flags, count: n))
            let last = n > 0 ? ids[n - 1] : 0
            MainActor.assumeIsolated { me.handle(ps, fl, last) }
        }
        let since = lastEvent == 0 ? FSEventStreamEventId(kFSEventStreamEventIdSinceNow) : lastEvent
        stream = FSEventStreamCreate(nil, cb, &ctx, [root] as CFArray, since, 3.0,
                                     FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot))
        if let s = stream { FSEventStreamSetDispatchQueue(s, .main); FSEventStreamStart(s) }
    }

    private func handle(_ paths: [String], _ flags: [FSEventStreamEventFlags], _ last: FSEventStreamEventId) {
        let has = { (f: FSEventStreamEventFlags, x: Int) in f & FSEventStreamEventFlags(x) != 0 }
        var dirs = Set<String>(), subs = Set<String>(), full = false
        for (p0, f) in zip(paths, flags) {
            if has(f, kFSEventStreamEventFlagHistoryDone) { continue }
            if has(f, kFSEventStreamEventFlagRootChanged) || has(f, kFSEventStreamEventFlagEventIdsWrapped) { full = true; continue }
            var p = p0
            while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
            guard covers(p), !scanSkip.contains(p) else { continue }
            if has(f, kFSEventStreamEventFlagMustScanSubDirs) { subs.insert(p) } else { dirs.insert(p) }
        }
        guard let root, full || !dirs.isEmpty || !subs.isEmpty else { lastEvent = max(lastEvent, last); return }
        Task {
            if full || subs.contains(root) { await scan(root) } else { await update(dirs: dirs, subtrees: subs, event: last) }
        }
    }

    // MARK: Kayıt (metin: "D\tboyut\tyol", "L\tboyut\tzaman\tyol")
    // ponytail: adında satır sonu olan yollar kaydedilmez; bir sonraki tam taramada geri gelir.

    nonisolated static func save(_ s: IndexState, event: FSEventStreamEventId) {
        guard !s.root.isEmpty else { return }
        var out = "MACCLEAR1\t\(event)\t\(s.root)\n"
        out.reserveCapacity(s.own.count * 90)
        for (k, v) in s.own where !k.contains("\n") { out += "D\t\(v)\t\(k)\n" }
        for e in s.large where !e.url.path.contains("\n") { out += "L\t\(e.size)\t\(e.modified.timeIntervalSince1970)\t\(e.url.path)\n" }
        try? fm.createDirectory(at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(out.utf8).write(to: cacheFile, options: .atomic)
    }

    nonisolated static func load() -> (IndexState, FSEventStreamEventId)? {
        guard let data = try? Data(contentsOf: cacheFile), let text = String(data: data, encoding: .utf8) else { return nil }
        var lines = text.split(separator: "\n")[...]
        guard let head = lines.popFirst() else { return nil }
        let h = head.split(separator: "\t", maxSplits: 2)
        guard h.count == 3, h[0] == "MACCLEAR1", let ev = UInt64(h[1]) else { return nil }
        var s = IndexState(root: String(h[2]))
        s.own.reserveCapacity(lines.count)
        for l in lines {
            if l.hasPrefix("D\t") {
                let f = l.split(separator: "\t", maxSplits: 2)
                if f.count == 3, let v = Int64(f[1]) { s.own[String(f[2])] = v }
            } else if l.hasPrefix("L\t") {
                let f = l.split(separator: "\t", maxSplits: 3)
                if f.count == 4, let v = Int64(f[1]), let t = Double(f[2]) {
                    s.large.append(Entry(url: URL(fileURLWithPath: String(f[3]), isDirectory: false), size: v, date: Date(timeIntervalSince1970: t)))
                }
            }
        }
        s.total = aggregate(s.own, root: s.root)
        return (s, ev)
    }
}

/// `mac-clear --du <klasör>`: hızlı taramayı ölçer (`du -sk` ile karşılaştırmak için).
func duCommand(_ path: String) {
    let t0 = Date()
    let r = Walker(root: path, largeMin: largeMin).run()
    print("\(r.sizes[path].map { $0 / 1024 } ?? 0) KB, \(r.sizes.count) klasör, \(r.large.count) büyük dosya, \(String(format: "%.2f", Date().timeIntervalSince(t0))) sn")
}

/// `mac-clear --selftest` parçası: artımlı güncellemenin tam taramayla aynı sonucu verdiğini geçici bir klasörde doğrular.
func indexSelfTest() {
    let base = fm.temporaryDirectory.appendingPathComponent("mac-clear-test-\(getpid())").path
    defer { try? fm.removeItem(atPath: base) }
    func mk(_ p: String) { try? fm.createDirectory(atPath: join(base, p), withIntermediateDirectories: true) }
    func put(_ p: String, _ kb: Int) { fm.createFile(atPath: join(base, p), contents: Data(count: kb * 1024)) }
    func full() -> IndexState { let r = Walker(root: base, largeMin: 50_000).run(); return IndexState(own: r.own, total: r.sizes, large: r.large, root: base, minLarge: 50_000) }
    func same(_ a: IndexState, _ b: IndexState, _ msg: String) {
        precondition(a.own == b.own, "own farklı: \(msg)")
        precondition(a.total == b.total, "total farklı: \(msg)")
        precondition(Set(a.large.map(\.url.path)) == Set(b.large.map(\.url.path)), "large farklı: \(msg)")
    }
    mk("a/b/c"); mk("d"); put("a/x", 10); put("a/b/y", 100); put("a/b/c/z", 5); put("d/w", 1)
    var s = full()
    put("a/b/c/new", 20); mk("a/e/f"); put("a/e/f/g", 3)            // dosya + yeni alt ağaç
    s = s.applying(dirs: [join(base, "a/b/c"), join(base, "a")], subtrees: [])
    same(s, full(), "ekleme")
    try? fm.removeItem(atPath: join(base, "a/b"))                       // alt ağaç silme
    s = s.applying(dirs: [join(base, "a"), join(base, "a/b/c")], subtrees: [])
    same(s, full(), "silme")
    put("d/w", 80)                                                      // büyüme + büyük dosya
    s = s.applying(dirs: [], subtrees: [join(base, "d")])
    same(s, full(), "alt ağaç yenileme")
    print("index selftest ok")
}
