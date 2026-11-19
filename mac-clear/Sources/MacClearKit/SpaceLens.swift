import AppKit
import Combine
import SwiftUI

// MARK: - Alan Haritası

@MainActor final class LensModel: ObservableObject {
    @Published var dir = home
    @Published var items: [Entry] = []
    @Published var selection: Set<URL> = []
    @Published var scanning = false
    @Published var free: Int64 = 0

    private var task: Task<Void, Never>?
    private var started = false

    var total: Int64 { items.totalSize }

    /// Kökten `dir`e kadar olan üst klasörler (breadcrumb).
    var crumbs: [URL] {
        var out: [URL] = [], u = dir
        while true {
            out.insert(u, at: 0)
            if u.path == "/" { return out }
            u = u.deletingLastPathComponent()
        }
    }

    func start() { if !started { started = true; open(home) } }

    func open(_ url: URL) {
        task?.cancel()
        dir = url
        selection = []
        free = freeSpace()
        load(url, rescan: false)
    }

    func rescan() { load(dir, rescan: true) }

    func pick() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false; p.directoryURL = dir
        if p.runModal() == .OK, let u = p.url { open(u) }
    }

    /// Dizin canlı güncellenince (FSEvents) bulunulan klasörü sessizce yeniden listeler; seçim korunur.
    func refresh() {
        guard !scanning else { return }
        let p = dir.path
        Task {
            let raw = await Task.detached { listDir(p) }.value
            guard dir.path == p, !scanning else { return }
            show(p, raw)
            selection.formIntersection(items.map(\.url))
        }
    }

    /// Klasör boyutları ortak dizinden gelir (tek tarama); burada yalnızca bu klasörün çocukları listelenir.
    private func load(_ url: URL, rescan: Bool) {
        task?.cancel()
        scanning = true
        task = Task {
            let p = url.path
            if rescan { await DiskIndex.shared.scan(p) } else { await DiskIndex.shared.ensure(p) }
            guard !Task.isCancelled else { return } // başka klasöre geçildi; sonuç eski
            let raw = await Task.detached { listDir(p) }.value
            guard !Task.isCancelled else { return }
            show(p, raw)
            scanning = false
        }
    }

    private func show(_ p: String, _ raw: [RawEntry]) {
        let sizes = DiskIndex.shared.sizes
        items = raw.map { Entry(in: p, $0, sizes: sizes) }
    }

    func trash(_ urls: [URL]) async {
        let chosen = items.filter { urls.contains($0.url) }
        let gone = await perform(chosen.map(\.url), sizes: sizeMap(chosen), verb: "Çöp Sepeti'ne taşındı",
                                 undone: { [weak self] _ in self?.refresh() })
        withAnimation(.easeInOut(duration: 0.3)) { items.removeAll { gone.contains($0.url) } }
        selection.subtract(gone)
    }
}

struct LensView: View {
    @ObservedObject var m: LensModel
    @ObservedObject private var index = DiskIndex.shared
    @ObservedObject private var working = Working.shared
    @AppStorage("sortLens") private var sort = SortKey.size
    @State private var limit = pageSize

    var body: some View {
        let rows = sorted(m.items, by: sort)
        let peak = max(rows.map(\.size).max() ?? 1, 1)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(m.crumbs, id: \.path) { u in
                            Button(u.path == "/" ? "/" : u.lastPathComponent) { m.open(u) }
                                .buttonStyle(.link).disabled(u == m.dir)
                            if u != m.dir { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
                HStack {
                    Text(tilde(m.dir.path)).font(.headline).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text("Klasör: \(fmt(m.total))").monospacedDigit()
                    Text("Boş: \(fmt(m.free))").monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .padding([.horizontal, .top], 10).padding(.bottom, 6)
            Divider()
            List(selection: $m.selection) {
                ForEach(rows.prefix(limit)) { e in
                    HStack {
                        Image(nsImage: icon(e.url.path)).resizable().frame(width: 22, height: 22)
                        Text(e.name).lineLimit(1).truncationMode(.middle)
                        if e.url.hasDirectoryPath {
                            Button { m.open(e.url) } label: { Image(systemName: "chevron.right.circle") }
                                .buttonStyle(.borderless).help("Aç")
                        }
                        Spacer()
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule().fill(.tint).frame(width: 150 * CGFloat(e.size) / CGFloat(peak))
                        }
                        .frame(width: 150, height: 6)
                        DateSize(date: e.date, size: e.size)
                    }
                    .pending(e.url)
                }
                if rows.count > limit { ShowMore(remaining: rows.count - limit) { limit += pageSize } }
            }
            .contextMenu(forSelectionType: URL.self) { urls in
                if !urls.isEmpty {
                    Button("Finder'da göster") { NSWorkspace.shared.activateFileViewerSelecting(Array(urls)) }
                    Button("Çöpe taşı") { Task { await m.trash(Array(urls)) } }.disabled(working.busy)
                }
            } primaryAction: { urls in
                if let u = urls.first, u.hasDirectoryPath { m.open(u) }
            }
            .overlay { if m.scanning { ProgressView(index.scanning ? "\(index.scanned.formatted()) öğe tarandı…" : "Hesaplanıyor…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)) } }
            Divider()
            HStack {
                Button("Klasör seç…") { m.pick() }
                Button { m.rescan() } label: { Label("Yeniden tara", systemImage: "arrow.clockwise") }.disabled(m.scanning)
                SortPicker(key: $sort)
                BulkButtons(all: { m.selection = Set(rows.map(\.url)) }, none: { m.selection = [] })
                if m.scanning { ProgressView().controlSize(.small) }
                Spacer()
                SelectedSize(bytes: rows.filter { m.selection.contains($0.url) }.totalSize)
                Button("Finder'da göster") { NSWorkspace.shared.activateFileViewerSelecting(Array(m.selection)) }.disabled(m.selection.isEmpty)
                Button("Çöpe taşı") { Task { await m.trash(Array(m.selection)) } }.buttonStyle(.borderedProminent).disabled(m.selection.isEmpty || working.busy)
            }
            .padding()
        }
        .task { m.start() }
        .onChange(of: m.dir) { limit = pageSize }
        .onReceive(index.$sizes.dropFirst().debounce(for: .seconds(1), scheduler: RunLoop.main)) { _ in m.refresh() }
    }
}
