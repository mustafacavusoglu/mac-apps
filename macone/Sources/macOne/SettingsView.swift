import SwiftUI

/// Özellik listesi: her satırda simge, ad, kısa açıklama ve anahtar.
struct SettingsView: View {
    @ObservedObject var features: FeatureStore
    @StateObject private var login = LaunchAtLogin()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("macOne").font(.system(size: 20, weight: .semibold))
                Text("Kullanmak istediğin özellikleri aç, gerisini kapat.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            card {
                row(symbol: "power", title: "Oturum açılınca başlat",
                    detail: "Mac açılınca macOne kendiliğinden başlar. Kapalıyken uygulamayı kendin açarsın.",
                    on: login.isOn, set: login.set)
                if login.needsApproval { loginNotice }
                if let e = login.error { Text(e).font(.caption).foregroundStyle(.red).padding(.leading, 52).padding(.bottom, 10) }
            }
            SectionLabel("Özellikler").padding(.leading, -10).padding(.bottom, -10)
            card {
                ForEach(Array(features.features.enumerated()), id: \.element.id) { i, f in
                    if i > 0 { Divider().padding(.leading, 52) }
                    row(symbol: f.symbol, title: f.title, detail: f.detail, on: features.isOn(f.id)) { features.set(f.id, $0) }
                    if f.id == Catalog.altTab && features.isOn(f.id) && !Permissions.screenRecording { screenNotice }
                }
            }
            Text("Kapalı özellik hiç çalışmaz. Finder özelliği değişince Finder yeniden başlar.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(24)
        .onAppear { login.refresh() }  // Sistem Ayarları'ndan değiştirilmiş olabilir
    }

    /// Alt-Tab önizlemesi için Ekran Kaydı izni yoksa: kısa açıklama + iki düğme.
    private var screenNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            Text("Pencere önizlemeleri için Ekran Kaydı izni gerekli. İzni verdikten sonra yeniden başlat.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Ayarları aç", action: Permissions.openScreenRecordingSettings).controlSize(.small)
            Button("Yeniden başlat", action: Permissions.relaunch).controlSize(.small)
        }
        .padding(.leading, 52).padding(.trailing, 12).padding(.bottom, 10)
    }

    /// macOS onay isterse: Giriş Öğeleri ayarına götüren düğme.
    private var loginNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            Text("macOS onay istiyor: Giriş Öğeleri'nde macOne'a izin ver.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Ayarları aç", action: login.openLoginItemsSettings).controlSize(.small)
        }
        .padding(.leading, 52).padding(.trailing, 12).padding(.bottom, 10)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 0, content: content)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
    }

    private func row(symbol: String, title: String, detail: String, on: Bool, set: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(on ? Color.accentColor : .secondary)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(on ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.06)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: Binding(get: { on }, set: set))
                .toggleStyle(.switch).controlSize(.small).labelsHidden()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .animation(.easeOut(duration: 0.15), value: on)
    }
}
