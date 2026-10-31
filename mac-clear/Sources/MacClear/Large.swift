import AppKit
import Combine
import SwiftUI

// MARK: - Büyük Dosyalar

/// Paket içindeki dosyalar (.photoslibrary, .app…) listelenmez: tek tek silmek paketi bozar.
func insidePackage(_ u: URL) -> Bool {
    var d = u.deletingLastPathComponent()
    while d.path.count > home.path.count {
        if NSWorkspace.shared.isFilePackage(atPath: d.path) { return true }
        d = d.deletingLastPathComponent()
    }
    return false
}

@MainActor final class LargeModel: ObservableObject {
    @Published var files: [Entry] = []
    @Published var selection: Set<URL> = []
    @Published var minMB = 500 { didSet { refilter() } }
    private var pool: [Entry] = []

    /// Ortak disk dizinini kullanır; force=true ev klasörünü yeniden tarar.
    func scan(force: Bool = false) async {
        if force || !DiskIndex.shared.covers(home.path) { await DiskIndex.shared.scan(home.path) }
        let skip = [lib("").path + "/", hm(".Trash").path + "/"]
        let all = DiskIndex.shared.large
        // isFilePackage klasör başına sistem çağrısı: ana iş parçacığından uzakta
        pool = await Task.detached { all.filter { e in !skip.contains { e.url.path.hasPrefix($0) } && !insidePackage(e.url) } }.value
        refilter()
        selection.formIntersection(files.map(\.url))
    }

    func refilter() { files = pool.filter { $0.size >= Int64(minMB) * 1_000_000 } }

    func trash(_ urls: Set<URL>) async {
        let chosen = files.filter { urls.contains($0.url) }, before = pool
        let gone = await perform(chosen.map(\.url), sizes: sizeMap(chosen), verb: "Çöp Sepeti'ne taşındı",
                                 undone: { [weak self] _ in self?.pool = before; self?.refilter() })
        withAnimation(.easeInOut(duration: 0.3)) { pool.removeAll { gone.contains($0.url) }; refilter() }
        selection.subtract(gone)
    }
}

struct LargeView: View {
    @ObservedObject var m: LargeModel
    @ObservedObject private var index = DiskIndex.shared
    @ObservedObject private var working = Working.shared
    @State private var order = [KeyPathComparator(\Entry.size, order: .reverse)]

    var body: some View {
        VStack(spacing: 0) {
            Table(m.files.sorted(using: order), selection: $m.selection, sortOrder: $order) {
                TableColumn("Ad", value: \.name) { Text($0.name).help($0.url.path).pending($0.url) }
                TableColumn("Konum", value: \.folder) { Text($0.folder).foregroundStyle(.secondary).pending($0.url) }
                TableColumn("Boyut", value: \.size) { Text(fmt($0.size)).monospacedDigit().pending($0.url) }.width(90)
                TableColumn("Değiştirilme", value: \.modified) { Text(dateText($0.date)).pending($0.url) }.width(110)
            }
            .contextMenu(forSelectionType: URL.self) { urls in
                if !urls.isEmpty {
                    Button("Finder'da göster") { NSWorkspace.shared.activateFileViewerSelecting(Array(urls)) }
                    Button("Çöpe taşı") { Task { await m.trash(urls) } }.disabled(working.busy)
                }
            }
            Divider()
            HStack {
                Picker("En az", selection: $m.minMB) {
                    Text("100 MB").tag(100); Text("500 MB").tag(500); Text("1 GB").tag(1000); Text("5 GB").tag(5000)
                }
                .frame(width: 160)
                Button { Task { await m.scan(force: true) } } label: { Label("Yeniden tara", systemImage: "arrow.clockwise") }.disabled(index.scanning)
                BulkButtons(all: { m.selection = Set(m.files.map(\.url)) }, none: { m.selection = [] })
                if index.scanning { ProgressView().controlSize(.small); Text("\(index.scanned.formatted()) öğe tarandı…").font(.caption).monospacedDigit() }
                Spacer()
                Text("\(m.files.count) dosya").monospacedDigit().foregroundStyle(.secondary)
                SelectedSize(bytes: m.files.filter { m.selection.contains($0.url) }.totalSize)
                Button("Finder'da göster") { NSWorkspace.shared.activateFileViewerSelecting(Array(m.selection)) }.disabled(m.selection.isEmpty)
                Button("Çöpe taşı") { Task { await m.trash(m.selection) } }.buttonStyle(.borderedProminent).disabled(m.selection.isEmpty || working.busy)
            }
            .padding()
        }
        .task { if m.files.isEmpty { await m.scan() } }
        .onReceive(index.$large.dropFirst().debounce(for: .seconds(1), scheduler: RunLoop.main)) { _ in Task { await m.scan() } }
    }
}
