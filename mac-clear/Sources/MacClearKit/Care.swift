import SwiftUI

/// Akıllı Bakım: tek tıkla tarama + varsayılan seçimle temizlik.
struct CareView: View {
    @ObservedObject var clean: CleanModel
    @ObservedObject var bg: BackgroundModel
    @Binding var tab: Tab?
    @State private var free: Int64 = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sparkles").font(.system(size: 56)).foregroundStyle(.tint)
            Text("Akıllı Bakım").font(.largeTitle.bold())
            HStack(spacing: 16) {
                card("Gereksiz dosyalar", fmt(clean.selectedSize), "trash", .clean)
                card("Başlangıç öğeleri", "\(bg.items.count) öğe", "power", .startup)
                card("Boş alan", fmt(free), "internaldrive", .lens)
            }
            if clean.scanning || bg.scanning { ProgressView("Taranıyor…").controlSize(.small) }
            HStack {
                Button { Task { await scanAll() } } label: { Label("Tara", systemImage: "arrow.clockwise") }
                CleanButton(m: clean) { free = freeSpace() }
            }
            .controlSize(.large)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { if clean.results.isEmpty { await scanAll() } else { free = freeSpace() } }
    }

    func scanAll() async {
        free = freeSpace()
        async let a: () = clean.scan()
        async let b: () = bg.scan()
        _ = await (a, b)
    }

    func card(_ title: String, _ value: String, _ icon: String, _ target: Tab) -> some View {
        Button { tab = target } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title)
                Text(value).font(.title2.bold()).monospacedDigit()
                Text(title).foregroundStyle(.secondary)
            }
            .frame(width: 170, height: 120)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
