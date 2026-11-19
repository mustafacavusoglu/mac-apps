import AppKit
import SwiftUI

// MARK: - Sistem Çöpü (önbellek, günlük, geliştirici artıkları, Çöp Sepeti)

struct Cat: Identifiable {
    let id: String, title: String, icon: String, note: String
    let roots: [URL]
    var on = true          // tarama sonrası otomatik seçilsin mi
    var permanent = true   // false → Çöp Sepeti'ne taşı
}

let cats: [Cat] = [
    Cat(id: "caches", title: "Uygulama önbellekleri", icon: "internaldrive", note: "Uygulamalar yeniden oluşturur", roots: [lib("Caches")]),
    Cat(id: "logs", title: "Günlükler ve çökme raporları", icon: "doc.text", note: "~/Library/Logs", roots: [lib("Logs"), lib("Application Support/CrashReporter")]),
    Cat(id: "xcode", title: "Xcode artıkları", icon: "hammer", note: "DerivedData, DeviceSupport, simülatör önbelleği",
        roots: ["Xcode/DerivedData", "Xcode/iOS DeviceSupport", "Xcode/watchOS DeviceSupport", "Xcode/DocumentationCache", "CoreSimulator/Caches"].map { lib("Developer/" + $0) }),
    Cat(id: "pkg", title: "Paket yöneticisi önbellekleri", icon: "shippingbox", note: "npm, yarn, pnpm, gradle, cargo",
        roots: [hm(".npm/_cacache"), hm(".yarn/cache"), hm(".pnpm-store"), lib("pnpm/store"), hm(".gradle/caches"), hm(".cargo/registry/cache")]),
    Cat(id: "dotcache", title: "~/.cache", icon: "brain", note: "HuggingFace modelleri burada olabilir, tek tek seç",
        roots: [hm(".cache")], on: false),
    Cat(id: "m2", title: "Maven deposu", icon: "cup.and.saucer", note: "Yeniden indirmesi yavaş", roots: [hm(".m2/repository")], on: false),
    Cat(id: "archives", title: "Xcode arşivleri", icon: "archivebox", note: "Çöpe taşınır (symbolication için gerekebilir)",
        roots: [lib("Developer/Xcode/Archives")], on: false, permanent: false),
    Cat(id: "trash", title: "Çöp Sepeti", icon: "trash", note: "Kalıcı olarak boşaltılır", roots: [hm(".Trash")]),
]

/// Asla listelenmeyenler: sistem / iCloud önbellekleri, uygulamanın kendi dizini ve silme günlüğü.
let neverTouch: Set<String> = ["CloudKit", "com.apple.bird", "FamilyCircle", appID, "Mac-Clear.log"]
/// Listelenir ama otomatik seçilmez: yeniden indirmesi pahalı olanlar.
let notPreselected: Set<String> = ["ms-playwright", "ms-playwright-go", "huggingface", "torch", "JetBrains", "pip", "uv"]

@MainActor final class CleanModel: ObservableObject {
    @Published var results: [String: [Entry]] = [:]   // kategori → kökün doğrudan çocukları
    @Published var kids: [URL: [Entry]] = [:]         // açılan klasörlerin çocukları (tembel)
    @Published var selected: Set<URL> = []            // en üstteki seçimler; bir klasör seçiliyse altı da seçili sayılır
    @Published var sizes: [String: Int64] = [:]  // yol → boyut (tarama klasör toplamlarını zaten üretir)
    @Published var scanning = false

    func scan() async {
        scanning = true
        defer { scanning = false }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        // Her kök için bir paralel Walker; alt klasör boyutları saklanır, klasör açmak anında olur.
        let found = await withTaskGroup(of: (String, [Entry], [String: Int64]).self) { g in
            for c in cats {
                for root in c.roots {
                    g.addTask {
                        let top = listDir(root.path)
                        if top.isEmpty { return (c.id, [], [:]) }
                        var sizes = Walker(root: root.path, largeMin: .max).run().sizes
                        let items = top
                            .filter { !$0.name.hasPrefix("com.apple.") && !neverTouch.contains($0.name) && $0.name != ".DS_Store" }
                            .map { e -> Entry in
                                if !e.isDir { sizes[join(root.path, e.name)] = e.size }
                                return Entry(in: root.path, e, sizes: sizes)
                            }
                            .filter { $0.size > 0 }
                        return (c.id, items, sizes)
                    }
                }
            }
            var r = Dictionary(uniqueKeysWithValues: cats.map { ($0.id, [Entry]()) }), s: [String: Int64] = [:]
            for await (id, items, sz) in g { r[id, default: []] += items; s.merge(sz) { a, _ in a } }
            return (r, s)
        }
        results = found.0; sizes = found.1; kids = [:]
        selected = Set(cats.filter(\.on).flatMap { results[$0.id] ?? [] }.map(\.url).filter {
            let n = $0.lastPathComponent
            return !running.contains(n) && !notPreselected.contains(n)
        })
    }

    func size(_ u: URL) -> Int64 { sizes[u.path] ?? 0 }
    /// Güncel boyutlarla (alt öğe silinince üst klasörler küçülür).
    func fresh(_ es: [Entry]) -> [Entry] { es.map { Entry(url: $0.url, size: size($0.url), date: $0.date) } }

    func loadKids(_ u: URL) async {
        guard kids[u] == nil else { return }
        let p = u.path
        let known = sizes
        // @Published sözlüğe döngüde yazmak her seferinde tüm sözlüğü kopyalar (binlerce dosyada donma): arka planda topla, bir kez yaz.
        let (es, files) = await Task.detached { () -> ([Entry], [String: Int64]) in
            var es: [Entry] = [], files: [String: Int64] = [:]
            for e in listDir(p) where e.name != ".DS_Store" {
                if !e.isDir { files[join(p, e.name)] = e.size }
                es.append(Entry(in: p, e, sizes: known))
            }
            return (es, files)
        }.value
        sizes.merge(files) { $1 }
        kids[u] = es
    }

    // MARK: Seçim (ağaç)

    private func dirURL(_ p: String) -> URL { URL(fileURLWithPath: p, isDirectory: true) }

    /// u'yu kapsayan seçim (kendisi ya da en yakın seçili üst klasör).
    func covering(_ u: URL) -> URL? {
        if selected.contains(u) { return u }
        var p = u.path
        while true {
            let q = parentPath(p)
            if q == p { return nil }
            p = q
            if selected.contains(dirURL(p)) { return dirURL(p) }
        }
    }

    /// Silinecek en küçük küme: üst klasörü zaten seçili olanlar tekrar sayılmaz.
    var minimalSelection: [URL] { selected.filter { covering(dirURL(parentPath($0.path))) == nil } }

    var selectedSize: Int64 { minimalSelection.reduce(0) { $0 + size($1) } }
    func selectedSize(_ c: Cat) -> Int64 {
        let roots = c.roots.map { $0.path + "/" }
        return minimalSelection.filter { u in roots.contains { u.path.hasPrefix($0) } }.reduce(0) { $0 + size($1) }
    }

    func binding(_ u: URL) -> Binding<Bool> {
        Binding(get: { self.covering(u) != nil }, set: { on in
            let below = u.path + "/"
            if on {
                self.selected = self.selected.filter { !$0.path.hasPrefix(below) }
                self.selected.insert(u)
            } else if let a = self.covering(u) {
                self.selected.remove(a)
                // Üst klasör seçiliydi: onu kaldırıp yol boyunca kardeşleri seç, böylece yalnızca u dışarıda kalır.
                var node = u
                while node.path != a.path {
                    let parent = self.dirURL(parentPath(node.path))
                    for s in self.kids[parent] ?? [] where s.url.path != node.path { self.selected.insert(s.url) }
                    node = parent
                }
                self.selected = self.selected.filter { !$0.path.hasPrefix(below) }
            }
        })
    }

    /// Yeniden tarama yok: silinenler listeden hemen çıkar, üst klasör boyutları küçülür.
    /// Kalıcı siler: yalnızca CleanButton'ın onayından sonra çağrılır.
    func clean() async {
        let chosen = minimalSelection
        let archives = cats.filter { !$0.permanent }.flatMap(\.roots).map { $0.path + "/" }
        let perm = Set(chosen.filter { u in !archives.contains { u.path.hasPrefix($0) } })
        let gone = await perform(chosen, permanent: perm, sizes: Dictionary(uniqueKeysWithValues: chosen.map { ($0, size($0)) }),
                                 verb: "temizlendi", undone: { [weak self] _ in await self?.scan() })
        var sz = sizes // yerel kopya; döngüde @Published'a yazmak her adımda kopyalar
        for g in gone {
            let s = sz[g.path] ?? 0
            var p = parentPath(g.path)
            while let v = sz[p] { sz[p] = v - s; let q = parentPath(p); if q == p { break }; p = q }
        }
        let prefixes = gone.map { $0.path + "/" }, paths = Set(gone.map(\.path))
        sz = sz.filter { k, _ in !paths.contains(k) && !prefixes.contains { k.hasPrefix($0) } }
        withAnimation(.easeInOut(duration: 0.3)) {
            sizes = sz
            results = results.mapValues { $0.filter { !gone.contains($0.url) } }
            kids = kids.filter { k, _ in !gone.contains(k) }.mapValues { $0.filter { !gone.contains($0.url) } }
            selected.subtract(gone)
        }
    }
}

/// `--selftest` parçası: ağaç seçimi (diske dokunmaz).
@MainActor func cleanTreeSelfTest() {
    let m = CleanModel()
    let a = URL(fileURLWithPath: "/r/a", isDirectory: true), x = URL(fileURLWithPath: "/r/a/x", isDirectory: false)
    let y = URL(fileURLWithPath: "/r/a/y", isDirectory: true), z = URL(fileURLWithPath: "/r/a/y/z", isDirectory: false)
    m.kids = [a: [Entry(url: x, size: 1), Entry(url: y, size: 2)], y: [Entry(url: z, size: 2)]]
    m.sizes = ["/r/a": 3, "/r/a/x": 1, "/r/a/y": 2, "/r/a/y/z": 2]
    m.selected = [a]
    precondition(m.binding(z).wrappedValue, "üst klasör seçiliyse alt öğe de seçili")
    m.binding(z).wrappedValue = false
    precondition(m.selected == [x], "yalnızca z dışarıda kalmalı: \(m.selected)")
    m.selected = [a, x]
    precondition(m.minimalSelection == [a] && m.selectedSize == 3, "çift sayım olmamalı")
    m.binding(a).wrappedValue = true
    precondition(m.selected == [a], "üst seçilince alt seçimler düşer")
    m.binding(a).wrappedValue = false
    precondition(m.selected.isEmpty, "kaldırma")
    print("clean tree selftest ok")
}

/// Sistem Çöpü ve Akıllı Bakım'ın ortak "Temizle" düğmesi; kalıcı silmeden önce her zaman onay ister.
struct CleanButton: View {
    @ObservedObject var m: CleanModel
    var after: () -> Void = {}
    @ObservedObject private var working = Working.shared
    @State private var confirm = false

    var body: some View {
        Button("Temizle") { confirm = true }
            .buttonStyle(.borderedProminent).disabled(m.selected.isEmpty || m.scanning || working.busy)
            .confirmationDialog("\(fmt(m.selectedSize)) temizlensin mi?", isPresented: $confirm) {
                Button("Temizle", role: .destructive) { Task { await m.clean(); after() } }
            } message: {
                Text("Önbellek, günlük ve Çöp Sepeti öğeleri kalıcı silinir; Xcode arşivleri Çöp Sepeti'ne taşınır.")
            }
    }
}

/// Sistem Çöpü satırı; klasörse açılır ve içi aynı satırlarla listelenir.
struct CleanRow: View {
    @ObservedObject var m: CleanModel
    let e: Entry
    let sort: SortKey
    @State private var open = false
    @State private var limit = pageSize

    var body: some View {
        if e.url.hasDirectoryPath {
            DisclosureGroup(isExpanded: $open) {
                if let ks = m.kids[e.url] {
                    if ks.isEmpty { Text("Boş klasör").font(.caption).foregroundStyle(.secondary) }
                    let all = sorted(m.fresh(ks), by: sort)
                    ForEach(all.prefix(limit)) { k in CleanRow(m: m, e: k, sort: sort) }
                    if all.count > limit { ShowMore(remaining: all.count - limit) { limit += pageSize } }
                } else {
                    ProgressView().controlSize(.small)
                }
            } label: { row }
            .onChange(of: open) { if open { Task { await m.loadKids(e.url) } } }
        } else {
            row
        }
    }

    private var row: some View {
        Toggle(isOn: m.binding(e.url)) {
            HStack(spacing: 6) {
                Image(nsImage: icon(e.url.path)).resizable().frame(width: 16, height: 16)
                Text(e.name).lineLimit(1).truncationMode(.middle)
                Spacer()
                DateSize(date: e.date, size: m.size(e.url))
            }
        }
        .contextMenu { Button("Finder'da göster") { NSWorkspace.shared.activateFileViewerSelecting([e.url]) } }
        .pending(e.url)
    }
}

struct CleanView: View {
    @ObservedObject var m: CleanModel
    @AppStorage("sortClean") private var sort = SortKey.size
    @State private var limits: [String: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(cats) { c in
                    let items = sorted(m.fresh(m.results[c.id] ?? []), by: sort)
                    DisclosureGroup {
                        let limit = limits[c.id] ?? pageSize
                        ForEach(items.prefix(limit)) { e in CleanRow(m: m, e: e, sort: sort) }
                        if items.count > limit { ShowMore(remaining: items.count - limit) { limits[c.id] = limit + pageSize } }
                    } label: {
                        HStack {
                            // sources: kısmen seçiliyse "–" gösterir; boş kaynakla "seçili" göründüğü için boşta sabit kapalı
                            if items.isEmpty {
                                Toggle(isOn: .constant(false)) { Label(c.title, systemImage: c.icon).font(.headline) }.disabled(true)
                            } else {
                                Toggle(sources: items.map { m.binding($0.url) }, isOn: \.self) { Label(c.title, systemImage: c.icon).font(.headline) }
                            }
                            Text(c.note).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(items.isEmpty ? "Boş" : "\(fmt(m.selectedSize(c))) / \(fmt(items.totalSize))")
                                .monospacedDigit().foregroundStyle(items.isEmpty ? .secondary : .primary)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button { Task { await m.scan() } } label: { Label("Yeniden tara", systemImage: "arrow.clockwise") }
                    .disabled(m.scanning)
                SortPicker(key: $sort)
                BulkButtons(all: { m.selected = Set(m.results.values.joined().map(\.url)) }, none: { m.selected = [] })
                if m.scanning { ProgressView().controlSize(.small) }
                Spacer()
                SelectedSize(bytes: m.selectedSize)
                CleanButton(m: m)
            }
            .padding()
        }
        .task { if m.results.isEmpty { await m.scan() } }
    }
}
