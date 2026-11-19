import SwiftUI
import AppKit

/// macOne simgesinin paneli: her özellik için anahtar (açık olanın menü çubuğunda kendi simgesi belirir), Ayarlar, Çık.
struct MenuView: View {
    @ObservedObject var features: FeatureStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            if features.isOn(Catalog.altTab) && !Permissions.screenRecording {
                MenuRow("Alt-Tab önizlemesi için izin gerekli", symbol: "exclamationmark.circle") { open("settings") }
                    .foregroundStyle(.orange)
            }
            SectionLabel("Menü çubuğunda")
            ForEach(features.features) { f in
                ToggleRow(title: f.title, symbol: f.symbol, on: features.binding(f.id))
            }
            Divider().padding(.vertical, 4)
            if features.isOn(Catalog.macClear) {
                MenuRow("Mac-Clear'ı aç", symbol: "sparkles") { open("mac-clear") }
            }
            MenuRow("Ayarlar…", symbol: "gearshape") { open("settings") }
            MenuRow("macOne'dan çık", symbol: "power") { NSApp.terminate(nil) }
        }
        .padding(8)
        .frame(width: 290)
        .onAppear {  // Stats açık olmalıyken kendi kendine kapandıysa yeniden aç
            if features.isOn(Catalog.stats) { StatsFeature.start() }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("macOne").font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("\(features.features.filter { features.isOn($0.id) }.count)/\(features.features.count) açık")
                .font(.caption).monospacedDigit().foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10).padding(.top, 4)
    }

    private func open(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Küçük, soluk bölüm başlığı.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold)).tracking(0.6)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 10).padding(.top, 6)
    }
}

/// Simge + ad + küçük anahtar; satırın her yerine tıklamak da değiştirir.
struct ToggleRow: View {
    let title: String
    let symbol: String
    @Binding var on: Bool
    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).frame(width: 16)
                .foregroundStyle(on ? Color.accentColor : .secondary)
            Text(title).foregroundStyle(on ? .primary : .secondary)
            Spacer()
            Toggle("", isOn: $on).toggleStyle(.switch).controlSize(.mini).labelsHidden()
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.08) : .clear))
        .contentShape(Rectangle())
        .onTapGesture { on.toggle() }
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: on)
    }
}

/// Üzerine gelince hafif vurgulanan satır (Copy-Hist satırlarıyla aynı dil).
struct MenuRow: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var hover = false

    init(_ title: String, symbol: String, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.action = action
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).frame(width: 16).foregroundStyle(.secondary)
            Text(title)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.1) : .clear))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hover = $0 }
    }
}
