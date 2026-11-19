import AppKit
import SwiftUI

// MARK: - Kaldırıcı (uygulama + ~/Library kalıntıları)

struct AppInfo: Identifiable, Hashable {
    var id: URL { url }
    let url: URL, name: String, bundleID: String
}

/// Kalıntılar sadece tam bundle id (veya "id." öneki / ".id" soneki) ile eşleşir; isimle bulanık eşleşme yok.
/// Bundle id uygulamanın kendi Info.plist'inden gelir (güvenilmez): "/" içeren id yol olarak birleştirilmez,
/// yoksa "../../Pictures/x" gibi bir id ~/Library dışındaki dosyaları kalıntı diye listeletebilirdi.
func leftovers(_ a: AppInfo) -> [URL] {
    let b = a.bundleID
    guard !b.isEmpty, !b.contains("/") else { return [] }
    var c = ["Application Support/\(b)", "Caches/\(b)", "Preferences/\(b).plist", "Containers/\(b)",
             "Saved Application State/\(b).savedState", "HTTPStorages/\(b)", "HTTPStorages/\(b).binarycookies",
             "WebKit/\(b)", "Logs/\(b)", "Application Scripts/\(b)", "Cookies/\(b).binarycookies"].map(lib)
    c += children(lib("LaunchAgents")).filter { $0.lastPathComponent.hasPrefix(b + ".") }
    c += children(lib("Preferences/ByHost")).filter { $0.lastPathComponent.hasPrefix(b + ".") }
    c += children(lib("Group Containers")).filter { $0.lastPathComponent.hasSuffix("." + b) }
    return c.filter { fm.fileExists(atPath: $0.path) }
}

/// `--selftest` parçası: yol içeren bundle id ile ~/Library dışına çıkılamaz (salt okunur).
func leftoversSelfTest() {
    let evil = AppInfo(url: URL(fileURLWithPath: "/Applications/Evil.app"), name: "Evil", bundleID: "../../Library")
    precondition(leftovers(evil).isEmpty, "bundle id yol geçişi reddedilmeli")
    print("leftovers selftest ok")
}

@MainActor final class AppsModel: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var sizes: [URL: Int64] = [:]
    @Published var dates: [URL: Date] = [:]
    @Published var current: AppInfo?
    @Published var items: [Entry] = []
    @Published var checked: Set<URL> = []
    @Published var query = ""

    func load() async {
        let list = await Task.detached {
            [URL(fileURLWithPath: "/Applications"), hm("Applications")].flatMap(children)
                .filter { $0.pathExtension == "app" }
                .compactMap { u -> AppInfo? in
                    guard let id = Bundle(url: u)?.bundleIdentifier, !id.hasPrefix("com.apple.") else { return nil }
                    return AppInfo(url: u, name: u.deletingPathExtension().lastPathComponent, bundleID: id)
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
        apps = list
        // Tarih: Spotlight'taki son kullanım (eşzamanlı çağrı, ana iş parçacığı dışında), yoksa değiştirilme tarihi
        dates = await Task.detached {
            let ds = parallelMap(list) { a in NSMetadataItem(url: a.url)?.value(forAttribute: "kMDItemLastUsedDate") as? Date ?? modDate(a.url) }
            return Dictionary(uniqueKeysWithValues: zip(list, ds).compactMap { a, d in d.map { (a.url, $0) } })
        }.value
        sizes = await Task.detached { Dictionary(uniqueKeysWithValues: zip(list.map(\.url), parallelMap(list) { allocatedSize($0.url) })) }.value
    }

    func select(_ a: AppInfo?) async {
        current = a
        items = []
        guard let a else { return }
        let found = await Task.detached { ([a.url] + leftovers(a)).map { Entry(url: $0, size: allocatedSize($0), date: modDate($0)) } }.value
        guard current == a else { return }
        items = found
        checked = Set(found.filter { $0.size > 0 }.map(\.url))
    }

    func uninstall() async {
        guard let a = current else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: a.bundleID)
        if !running.isEmpty {
            let alert = NSAlert()
            alert.messageText = "\(a.name) çalışıyor"
            alert.informativeText = "Kaldırmadan önce kapatılmalı."
            alert.addButton(withTitle: "Kapat"); alert.addButton(withTitle: "Vazgeç")
            if alert.runModal() == .alertFirstButtonReturn { running.forEach { $0.terminate() } }
            return
        }
        let chosen = items.filter { checked.contains($0.url) }
        let headline = chosen.contains { $0.url == a.url } ? "\(a.name) kaldırıldı" : "\(a.name) kalıntıları temizlendi"
        let gone = await perform(chosen.map(\.url), sizes: sizeMap(chosen), verb: "Çöp Sepeti'ne taşındı",
                                 working: "\(a.name) kaldırılıyor…", headline: headline,
                                 undone: { [weak self] _ in await self?.load() })
        withAnimation(.easeInOut(duration: 0.3)) {
            if gone.contains(a.url) { apps.removeAll { $0.url == a.url }; current = nil; items = [] }
            else { items.removeAll { gone.contains($0.url) }; checked.subtract(gone) }
        }
    }
}

struct AppsView: View {
    @ObservedObject var m: AppsModel
    @ObservedObject private var working = Working.shared
    @AppStorage("sortApps") private var sort = SortKey.name

    var shown: [AppInfo] {
        let f = m.apps.filter { m.query.isEmpty || $0.name.localizedCaseInsensitiveContains(m.query) }
        switch sort {
        case .name: return f
        case .size: return f.sorted { (m.sizes[$0.url] ?? 0) > (m.sizes[$1.url] ?? 0) }
        case .date: return f.sorted { (m.dates[$0.url] ?? .distantPast) > (m.dates[$1.url] ?? .distantPast) }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TextField("Uygulama ara", text: $m.query)
                    .textFieldStyle(.roundedBorder)
                    .padding([.horizontal, .top], 8)
                SortPicker(key: $sort).padding(8)
                List(shown, selection: Binding(get: { m.current }, set: { a in if a != m.current { Task { await m.select(a) } } })) { a in
                    HStack {
                        Image(nsImage: icon(a.url.path)).resizable().frame(width: 24, height: 24)
                        VStack(alignment: .leading) {
                            Text(a.name).lineLimit(1)
                            Text("Son kullanım: \(dateText(m.dates[a.url]))").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(m.sizes[a.url].map(fmt) ?? "…").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .pending(a.url)
                    .tag(a)
                }
            }
            .frame(width: 280)
            Divider()

            VStack(alignment: .leading) {
                if let a = m.current {
                    Text(a.name).font(.title2.bold())
                    Text(a.bundleID).font(.caption).foregroundStyle(.secondary)
                    List(m.items) { e in
                        Toggle(isOn: Binding(get: { m.checked.contains(e.url) },
                                             set: { if $0 { m.checked.insert(e.url) } else { m.checked.remove(e.url) } })) {
                            HStack {
                                Text(tilde(e.url.path)).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Text(fmt(e.size)).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                        .pending(e.url)
                    }
                    HStack {
                        BulkButtons(all: { m.checked = Set(m.items.map(\.url)) }, none: { m.checked = [] })
                        Spacer()
                        SelectedSize(bytes: m.items.filter { m.checked.contains($0.url) }.totalSize)
                        Button("Kaldır") { Task { await m.uninstall() } }
                            .buttonStyle(.borderedProminent).disabled(m.checked.isEmpty || working.busy)
                            .help("Seçili öğeler Çöp Sepeti'ne taşınır; bildirimden geri alınabilir.")
                    }
                } else {
                    ContentUnavailableView("Bir uygulama seç", systemImage: "app.dashed",
                                           description: Text("Uygulama ve ~/Library'deki kalıntıları birlikte Çöp Sepeti'ne taşınır."))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { if m.apps.isEmpty { await m.load() } }
    }
}
