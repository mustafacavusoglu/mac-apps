import SwiftUI
import AppKit

/// Özellik simgesine tıklanınca açılan panel (Stats'ın açılır pencereleri gibi):
/// üstte başlık + kapatma düğmesi, altında içerik.
struct FeaturePanel<Content: View>: View {
    let title: String
    let symbol: String
    let turnOff: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(Color.accentColor)
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: turnOff) { Image(systemName: "power") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Bu özelliği kapat (macOne simgesinden yeniden açılır)")
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider()
            content()
        }
    }
}
