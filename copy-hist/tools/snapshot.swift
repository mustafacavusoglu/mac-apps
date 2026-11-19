// docs/screenshot.png üretir (örnek verilerle; gerçek geçmişe dokunmaz).
//   swiftc -o /tmp/snap tools/snapshot.swift $(ls Sources/CopyHistKit/*.swift) && /tmp/snap docs/screenshot.png
import SwiftUI

@main
struct Snapshot {
    @MainActor static func main() {
        let texts = [
            "git commit -m 'Tabula: README ekle'", "https://github.com/mustafacavusoglu/mac-apps",
            "ssh root@192.168.1.20", "SELECT id, name FROM users WHERE active = 1;",
            "Toplantı yarın 14:00'te, notları hazırla", "docker compose up -d --build",
            "npm run build && npm test", "kubectl get pods -n production -o wide",
            "Selçuklu Devleti 1037'de kuruldu", "pip install -r requirements.txt",
            "brew install ffmpeg", "python3 -m http.server 8080",
        ]
        let store = Store(sample: texts.map { Clip(text: $0, date: Date()) })
        // ImageRenderer ScrollView çizmez: ilk 10 satırı (kaydırmadan görünen kısım) düz VStack olarak çiz.
        let panel = VStack(spacing: 4) {
            VStack(spacing: 0) {
                ForEach(store.clips.prefix(Config.visibleCount)) { Row(clip: $0, onCopy: {}, onDelete: {}) }
            }
            HStack {
                Text("\(store.clips.count)").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Image(systemName: "trash"); Image(systemName: "power")
            }.foregroundStyle(.secondary).padding(.horizontal, 10).padding(.bottom, 2)
        }
        .padding(6).frame(width: 340)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.97).opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.1)))
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
            .padding(36)
            .background(LinearGradient(colors: [Color(red: 0.55, green: 0.65, blue: 0.85), Color(red: 0.75, green: 0.6, blue: 0.8)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .environment(\.colorScheme, .light)
        let r = ImageRenderer(content: panel)
        r.scale = 2
        guard let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { fatalError("render başarısız") }
        try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
