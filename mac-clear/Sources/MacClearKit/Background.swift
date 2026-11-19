import AppKit
import SwiftUI

// MARK: - Başlangıç Öğeleri (LaunchAgents / LaunchDaemons)

struct BgItem: Identifiable, Hashable {
    var id: URL { plist }
    let plist: URL
    let label: String
    let program: String?       // çözümlenmiş çalıştırılabilir yol
    let scope: String          // "Kullanıcı" / "Sistem ajanı" / "Sistem servisi"
    var loaded = false

    var isUser: Bool { scope == "Kullanıcı" }
}

func bgLaunchctl(_ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return -1 }
}

/// Program / ProgramArguments[0]; kabuk ya da yorumlayıcıysa ilk mutlak yol argümanı (betik).
func bgProgram(_ d: [String: Any]) -> String? {
    let args = d["ProgramArguments"] as? [String] ?? []
    guard let p = (d["Program"] as? String) ?? args.first else { return nil }
    let p0 = (p as NSString).expandingTildeInPath
    let interp: Set<String> = ["sh", "bash", "zsh", "env", "python", "python3", "perl", "ruby", "osascript", "node"]
    if interp.contains(URL(fileURLWithPath: p0).lastPathComponent), let s = args.dropFirst().first(where: { $0.hasPrefix("/") || $0.hasPrefix("~") }) {
        return (s as NSString).expandingTildeInPath
    }
    return p0
}

func bgScan() async -> [BgItem] {
    let uid = getuid()
    let srcs: [(URL, String)] = [(lib("LaunchAgents"), "Kullanıcı"), (URL(fileURLWithPath: "/Library/LaunchAgents"), "Sistem ajanı"),
                                 (URL(fileURLWithPath: "/Library/LaunchDaemons"), "Sistem servisi")]
    let base: [BgItem] = srcs.flatMap { dir, scope in
        children(dir).filter { $0.pathExtension == "plist" }.compactMap { u in
            guard let data = try? Data(contentsOf: u),
                  let d = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
            let label = d["Label"] as? String ?? u.deletingPathExtension().lastPathComponent
            return label.hasPrefix("com.apple.") ? nil : BgItem(plist: u, label: label, program: bgProgram(d), scope: scope)
        }
    }
    return await withTaskGroup(of: BgItem.self) { g in
        for var it in base {
            g.addTask {
                it.loaded = bgLaunchctl(["print", (it.scope == "Sistem servisi" ? "system/" : "gui/\(uid)/") + it.label]) == 0
                return it
            }
        }
        return await g.reduce(into: []) { $0.append($1) }
    }
}

@MainActor final class BackgroundModel: ObservableObject {
    @Published var items: [BgItem] = []
    @Published var scanning = false

    func scan() async {
        scanning = true
        defer { scanning = false }
        items = await Task.detached { await bgScan() }.value
    }

    /// Yalnızca kullanıcı kapsamı: önce bootout, sonra plist Çöp Sepeti'ne. Geri al: plist yerine döner ve yeniden yüklenir.
    func disable(_ its: [BgItem]) async {
        let uid = getuid()
        let gone = await perform(its.filter(\.isUser).map(\.plist), verb: "devre dışı bırakıldı", working: "Devre dışı bırakılıyor…",
            before: { u in _ = bgLaunchctl(["bootout", "gui/\(uid)", u.path]) }, // yüklü değilse hata verir; sorun değil
            undone: { [weak self] back in
                for u in back { _ = await Task.detached { bgLaunchctl(["bootstrap", "gui/\(uid)", u.path]) }.value }
                await self?.scan()
            })
        withAnimation(.easeInOut(duration: 0.3)) { items.removeAll { gone.contains($0.plist) } }
    }
}

struct BackgroundView: View {
    @ObservedObject var m: BackgroundModel
    @State private var sel: Set<URL> = []
    @ObservedObject private var working = Working.shared

    var shown: [BgItem] { m.items.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending } }
    var chosen: [BgItem] { m.items.filter { sel.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            Text("Başlangıç Öğeleri").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading).padding([.horizontal, .top]).padding(.bottom, 8)
            Table(shown, selection: $sel) {
                TableColumn("Ad") { Text($0.label).lineLimit(1).help($0.plist.path).pending($0.plist) }
                TableColumn("Kapsam") { Text($0.scope).foregroundStyle(.secondary).pending($0.plist) }.width(100)
                TableColumn("Program") {
                    Text($0.program.map(tilde) ?? "–")
                        .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary).help($0.program ?? "").pending($0.plist)
                }
                TableColumn("Durum") { Text($0.loaded ? "Yüklü" : "Yüklü değil").foregroundStyle(.secondary).pending($0.plist) }.width(80)
            }
            .contextMenu(forSelectionType: URL.self) { urls in
                Button("Finder'da göster") { NSWorkspace.shared.activateFileViewerSelecting(Array(urls)) }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button { Task { await m.scan() } } label: { Label("Yeniden tara", systemImage: "arrow.clockwise") }.disabled(m.scanning)
                    if m.scanning { ProgressView().controlSize(.small) }
                    Button("Giriş Öğeleri'ni aç") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                    }
                    BulkButtons(all: { sel = Set(shown.map(\.id)) }, none: { sel = [] })
                    Spacer()
                    Text("\(m.items.count) öğe").monospacedDigit()
                    Button("Finder'da göster") { NSWorkspace.shared.activateFileViewerSelecting(chosen.map(\.plist)) }.disabled(sel.isEmpty)
                    Button("Devre dışı bırak") { let c = chosen; sel = []; Task { await m.disable(c) } }
                        .buttonStyle(.borderedProminent).disabled(chosen.isEmpty || !chosen.allSatisfy(\.isUser) || m.scanning || working.busy)
                        .help("Ajan durdurulur ve plist Çöp Sepeti'ne taşınır; bildirimden geri alınabilir.")
                }
                Text("Sistem ajanları/servisleri yönetici izni gerektirir; burada yalnızca Finder'da gösterilir.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .task { if m.items.isEmpty { await m.scan() } }
    }
}
