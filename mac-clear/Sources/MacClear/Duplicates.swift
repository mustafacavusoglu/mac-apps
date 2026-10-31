import CryptoKit
import SwiftUI

// MARK: - Kopyalar (aynı içerikli dosyalar)

struct DupGroup: Identifiable {
    let id = UUID()
    var files: [Entry]  // en eskisi başta
    init(files: [Entry]) { self.files = files.sorted { $0.modified < $1.modified } }
    var size: Int64 { files.first?.size ?? 0 }
    var wasted: Int64 { size * Int64(files.count - 1) }
}

/// Anahtarı aynı olan ≥2 öğelik kümeler; anahtar nil (okunamadı) ise öğe düşer.
func collisions<T, K: Hashable>(_ items: [T], by key: (T) -> K?) -> [[T]] {
    var d: [K: [T]] = [:]
    for i in items { if let k = key(i) { d[k, default: []].append(i) } }
    return d.values.filter { $0.count > 1 }
}

/// Her gruptan en eskisi hariç hepsi.
func allButOldest(_ gs: [DupGroup]) -> Set<URL> { Set(gs.flatMap { $0.files.dropFirst().map(\.url) }) }
/// Seçim bir grubun tüm dosyalarını kapsıyor mu? (yasak durum)
func fullySelected(_ sel: Set<URL>, _ gs: [DupGroup]) -> Bool { gs.contains { $0.files.allSatisfy { sel.contains($0.url) } } }
/// Son güvenlik: tamamı seçilmiş gruplarda en eskiyi seçimden çıkarır.
func keepOne(_ sel: Set<URL>, _ gs: [DupGroup]) -> Set<URL> {
    var s = sel
    for g in gs where g.files.allSatisfy({ sel.contains($0.url) }) { if let f = g.files.first { s.remove(f.url) } }
    return s
}
/// Silinenleri düşer; <2 dosyası kalan gruplar gider.
func prune(_ gs: [DupGroup], removing gone: Set<URL>) -> [DupGroup] {
    gs.map { DupGroup(files: $0.files.filter { !gone.contains($0.url) }) }.filter { $0.files.count > 1 }
}

func partialHash(_ u: URL) -> String? {
    guard let h = try? FileHandle(forReadingFrom: u) else { return nil }
    defer { try? h.close() }
    guard let d = try? h.read(upToCount: 64 * 1024) else { return nil }
    return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
}

func fullHash(_ u: URL) -> String? {
    guard let h = try? FileHandle(forReadingFrom: u) else { return nil }
    defer { try? h.close() }
    var sha = SHA256()
    var more = true
    while more && !Task.isCancelled {
        more = autoreleasepool {
            guard let d = try? h.read(upToCount: 1 << 20), !d.isEmpty else { return false }
            sha.update(data: d)
            return true
        }
    }
    return Task.isCancelled ? nil : sha.finalize().map { String(format: "%02x", $0) }.joined()
}

@MainActor final class DuplicatesModel: ObservableObject {
    @Published var groups: [DupGroup] = []
    @Published var selected: Set<URL> = []
    @Published var scanning = false
    @Published var done = false
    @Published var minMB = 10
    @Published var status = ""
    private var task: Task<Void, Never>?

    func start() { task = Task { await scan() } }
    func cancel() { task?.cancel() }

    func scan() async {
        scanning = true; done = false; groups = []; selected = []
        defer { scanning = false }
        let minSize = Int64(minMB) * 1_000_000
        let report: @Sendable (String) -> Void = { s in Task { @MainActor in self.status = s } }
        let job = Task.detached { () -> [DupGroup] in
            // ~/Library ve gizli klasörler (.Trash, .git…) atlanır; paketler de (aşağıdaki not).
            // ponytail: NSWorkspace.isFilePackage kesin olurdu ama klasör başına çok yavaş; sabit uzantı kümesi yeterince iyi.
            let packageExts: Set<String> = ["app", "photoslibrary", "bundle", "framework", "xcarchive", "musiclibrary", "tvlibrary",
                                            "fcpbundle", "imovielibrary", "plugin", "kext", "pkg", "rtfd", "logicx", "band"]
            let w = Walker(root: home.path, largeMin: minSize, skip: [hm("Library").path, hm(".Trash").path])
            w.descend = { _, name in !name.hasPrefix(".") && !packageExts.contains((name as NSString).pathExtension.lowercased()) }
            let poll = Task { while !Task.isCancelled { report("Taranan öğe: \(w.scanned)"); try? await Task.sleep(for: .milliseconds(250)) } }
            let found = w.run().large // yalnızca ayrılmış boyutu ≥ eşik olan dosyalar (symlink/dizin değil)
            poll.cancel()
            if Task.isCancelled { return [] }
            let n = w.scanned
            // Walker ayrılmış (4K'ya yuvarlı) boyutu verir; eşleştirme için mantıksal boyut gerekir. Yalnızca adaylar için lstat.
            let entries: [Entry] = found.compactMap { f in
                var st = stat()
                guard lstat(f.url.path, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG, Int64(st.st_size) >= minSize else { return nil }
                return Entry(url: f.url, size: Int64(st.st_size), date: f.date)
            }
            // ponytail: APFS klonları blokları paylaşır; bir klonu silmek gösterilenden az yer açabilir. Yükseltme: getattrlist ATTR_CMNEXT_CLONEID ile klonları ele.
            let sizeGroups = collisions(entries) { $0.size }
            var out: [DupGroup] = []
            for (i, g) in sizeGroups.enumerated() {
                if Task.isCancelled { return [] }
                report("Özetleniyor: \(i + 1) / \(sizeGroups.count) grup (\(n) dosya tarandı)")
                for p in collisions(g, by: { partialHash($0.url) }) {
                    for f in collisions(p, by: { fullHash($0.url) }) { out.append(DupGroup(files: f)) }
                }
            }
            return out.sorted { $0.wasted > $1.wasted }
        }
        let r = await withTaskCancellationHandler { await job.value } onCancel: { job.cancel() }
        groups = r
        done = true
        status = Task.isCancelled ? "İptal edildi." : ""
    }

    var selectedSize: Int64 { groups.flatMap(\.files).filter { selected.contains($0.url) }.totalSize }
    var totalWasted: Int64 { groups.reduce(0) { $0 + $1.wasted } }

    func binding(_ u: URL) -> Binding<Bool> {
        Binding(get: { self.selected.contains(u) }, set: { on in
            if !on { self.selected.remove(u); return }
            let s = self.selected.union([u])
            if !fullySelected(s, self.groups) { self.selected = s } // her gruptan en az biri kalmalı
        })
    }

    func selectAllButOldest() { selected = allButOldest(groups) }

    func trash() async {
        let urls = keepOne(selected, groups), before = groups
        let chosen = groups.flatMap(\.files).filter { urls.contains($0.url) }
        let gone = await perform(chosen.map(\.url), sizes: sizeMap(chosen), verb: "Çöp Sepeti'ne taşındı",
                                 undone: { [weak self] _ in self?.groups = before })
        withAnimation(.easeInOut(duration: 0.3)) { groups = prune(groups, removing: gone) }
        selected = selected.intersection(groups.flatMap(\.files).map(\.url))
    }
}

struct DuplicatesView: View {
    @ObservedObject var m: DuplicatesModel
    @ObservedObject private var working = Working.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("En az", selection: $m.minMB) {
                    Text("1 MB").tag(1); Text("10 MB").tag(10); Text("100 MB").tag(100)
                }
                .frame(width: 140).disabled(m.scanning)
                if m.scanning {
                    Button { m.cancel() } label: { Label("İptal", systemImage: "xmark.circle") }
                    ProgressView().controlSize(.small)
                } else {
                    Button { m.start() } label: { Label("Tara", systemImage: "magnifyingglass") }
                }
                Text(m.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if !m.groups.isEmpty { Text("\(m.groups.count) grup, boşa giden \(fmt(m.totalWasted))").monospacedDigit() }
            }
            .padding()
            Divider()
            if m.groups.isEmpty {
                ContentUnavailableView(m.done ? "Kopya bulunamadı" : "Kopya dosyaları bul", systemImage: "doc.on.doc",
                                       description: Text(m.scanning ? "Ev klasörü taranıyor…" : "~/Library ve gizli klasörler hariç; aynı içerikli dosyalar gruplanır."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(m.groups) { g in
                        Section {
                            ForEach(g.files) { e in
                                Toggle(isOn: m.binding(e.url)) {
                                    HStack {
                                        Text(tilde(e.url.path)).lineLimit(1).truncationMode(.middle)
                                        Spacer()
                                        DateSize(date: e.date, size: e.size)
                                    }
                                }
                                .contextMenu { Button("Finder'da göster") { NSWorkspace.shared.activateFileViewerSelecting([e.url]) } }
                                .pending(e.url)
                            }
                        } header: {
                            Text("\(g.files.count) kopya · \(fmt(g.size)) · boşa giden \(fmt(g.wasted))").font(.headline)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button("Her gruptan en eskisi hariç seç") { m.selectAllButOldest() }.disabled(m.groups.isEmpty)
                Button("Hiçbirini seçme") { m.selected = [] }.disabled(m.selected.isEmpty)
                Spacer()
                SelectedSize(bytes: m.selectedSize)
                Button("Çöpe taşı") { Task { await m.trash() } }
                    .buttonStyle(.borderedProminent).disabled(m.selected.isEmpty || m.scanning || working.busy)
            }
            .padding()
        }
    }
}

/// `--selftest` içinden çağrılır: gruplama + seçim korumaları (diske dokunmaz).
func duplicatesSelfTest() {
    func e(_ n: String, _ t: Double) -> Entry { Entry(url: URL(fileURLWithPath: "/x/\(n)"), size: 100, date: Date(timeIntervalSince1970: t)) }
    let g0 = DupGroup(files: [e("a", 3), e("b", 1), e("c", 2)]), g1 = DupGroup(files: [e("d", 5), e("e", 4)])
    let gs = [g0, g1]
    precondition(collisions([1, 2, 2, 3, 3, 3]) { $0 }.map(\.count).sorted() == [2, 3], "çakışma grupları")
    precondition(collisions(["a", "b"]) { $0 == "a" ? nil : $0 }.isEmpty, "nil anahtar düşmeli")
    precondition(g0.files[0].name == "b" && g0.wasted == 200, "en eski başta, boşa giden = boyut × (n-1)")
    let sel = allButOldest(gs)
    precondition(sel.count == 3 && !sel.contains(g0.files[0].url) && !sel.contains(g1.files[0].url), "en eskiler hariç")
    precondition(!fullySelected(sel, gs), "tamamı seçilemez")
    let all = Set(g0.files.map(\.url))
    precondition(fullySelected(all, gs), "tam seçim yakalanmalı")
    let k = keepOne(all, gs)
    precondition(k.count == 2 && !k.contains(g0.files[0].url), "keepOne en eskiyi korur")
    let p = prune(gs, removing: Set(g0.files.dropFirst().map(\.url)))
    precondition(p.count == 1 && p[0].files.count == 2, "<2 dosyalı grup düşer")
    print("duplicates selftest ok")
}
