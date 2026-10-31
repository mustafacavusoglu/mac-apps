import AppKit
import SwiftUI

// MARK: - Mac-Clear: uygulama girişi, kenar çubuğu ve komut satırı bayrakları

let appID = "dev.cavusoglu.mac-clear" // Info.plist ile aynı; önbellek klasörü ve Sistem Çöpü'nden hariç tutma için

enum Tab: Hashable { case care, clean, large, dupes, lens, apps, startup }

struct RootView: View {
    @AppStorage("dark") private var dark = false
    @State private var tab: Tab? = .care
    @State private var fda = hasFullDiskAccess()
    @StateObject private var clean = CleanModel()
    @StateObject private var large = LargeModel()
    @StateObject private var apps = AppsModel()
    @StateObject private var dupes = DuplicatesModel()
    @StateObject private var lens = LensModel()
    @StateObject private var bg = BackgroundModel()

    var body: some View {
        NavigationSplitView {
            List(selection: $tab) {
                Label("Akıllı Bakım", systemImage: "sparkles").tag(Tab.care)
                Section("Temizlik") {
                    Label("Sistem Çöpü", systemImage: "trash").tag(Tab.clean)
                    Label("Büyük Dosyalar", systemImage: "doc.badge.ellipsis").tag(Tab.large)
                    Label("Kopyalar", systemImage: "doc.on.doc").tag(Tab.dupes)
                    Label("Alan Haritası", systemImage: "chart.pie").tag(Tab.lens)
                }
                Section("Uygulamalar ve Hız") {
                    Label("Kaldırıcı", systemImage: "xmark.app").tag(Tab.apps)
                    Label("Başlangıç Öğeleri", systemImage: "power").tag(Tab.startup)
                }
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            VStack(spacing: 0) {
                if !fda {
                    HStack {
                        Image(systemName: "lock.shield").foregroundStyle(.orange)
                        Text("Tam Disk Erişimi yok; bazı klasörler atlanacak.")
                        Spacer()
                        Button("Ayarları aç") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                        }
                        Button("Tekrar kontrol et") { fda = hasFullDiskAccess() }
                    }
                    .padding(10)
                    .background(.orange.opacity(0.12))
                }
                switch tab ?? .care {
                case .care: CareView(clean: clean, bg: bg, tab: $tab)
                case .clean: CleanView(m: clean)
                case .dupes: DuplicatesView(m: dupes)
                case .lens: LensView(m: lens)
                case .startup: BackgroundView(m: bg)
                case .large: LargeView(m: large)
                case .apps: AppsView(m: apps)
                }
            }
            .overlay(alignment: .bottom) { ActivityHUD() }
        }
        .toolbar {
            Button { dark.toggle() } label: { Image(systemName: dark ? "sun.max" : "moon") }.help("Açık / koyu tema")
        }
        .preferredColorScheme(dark ? .dark : .light)
    }
}

/// Komut satırı: `mac-clear --selftest` (testler), `mac-clear --du <klasör>` (hızlı tarama ölçümü).
@main struct MacClearApp: App {
    init() {
        if CommandLine.arguments.contains("--selftest") {
            selfTest(); leftoversSelfTest(); cleanTreeSelfTest(); duplicatesSelfTest(); indexSelfTest()
            Task { await performSelfTest(); exit(0) }
            RunLoop.main.run() // ana aktör görevleri için
        }
        if let i = CommandLine.arguments.firstIndex(of: "--du"), i + 1 < CommandLine.arguments.count { duCommand(CommandLine.arguments[i + 1]); exit(0) }
        setvbuf(stdout, nil, _IOLBF, 0) // terminalden çalıştırınca süre çıktıları anında görünsün
        NSApplication.shared.setActivationPolicy(.regular)
        DiskIndex.shared.start() // kayıtlı dizini yükle / arka planda tara, değişiklikleri izle
    }
    var body: some Scene {
        WindowGroup("Mac-Clear") { RootView().frame(minWidth: 860, minHeight: 560) }
            .windowToolbarStyle(.unified)
    }
}
