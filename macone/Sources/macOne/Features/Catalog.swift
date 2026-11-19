import AltTabKit
import CopyHistKit
import FinderPlusKit
import MacClearKit

/// macOne'ın tüm özellikleri. Yeni özellik eklemek = buraya bir satır (+ App.swift'te menü çubuğu simgesi).
enum Catalog {
    static let clipboard = "clipboard", finder = "finder", altTab = "alttab"
    static let macClear = "macclear", speedTest = "speedtest", stats = "stats"

    @MainActor
    static func make() -> [Feature] {
        [
            Feature(id: clipboard, title: "Pano Geçmişi", detail: "Kopyaladığın metinleri tutar; menü çubuğundaki simgesinden seçersin (Copy-Hist).",
                    symbol: "doc.on.clipboard", start: clipboardHistoryStart, stop: clipboardHistoryStop),
            Feature(id: finder, title: "Kes / Taşı ve Finder menüsü",
                    detail: "Finder'da ⌘X / ⌘V ile taşıma, sağ tık menüsünde Yeni Dosya ve Burada Terminal Aç (Finder-Plus).",
                    symbol: "scissors", start: { finderShortcutsStart(); FinderExtension.enable() },
                    stop: { finderShortcutsStop(); FinderExtension.disable() }),
            Feature(id: altTab, title: "Alt-Tab", detail: "⌥Tab ile canlı önizlemeli pencere değiştirici.",
                    symbol: "rectangle.on.rectangle", start: { altTabStart(showStatusItem: false) }, stop: altTabStop),
            Feature(id: macClear, title: "Mac-Clear", detail: "Disk temizleyici ve alan analizcisi. macOne simgesinden açılır.",
                    symbol: "internaldrive", start: macClearPrepare, stop: {}),
            Feature(id: speedTest, title: "Hız Testi", detail: "Ping, indirme ve yükleme hızı. Menü çubuğundaki simgesine tıklayınca açılır.",
                    symbol: "speedometer", start: {}, stop: {}),
            Feature(id: stats, title: "Stats", detail: "CPU, bellek, disk, ağ, sıcaklık, pil (exelban/stats). Menü çubuğundaki simgeleri Stats'ın kendisi gösterir; hangi modüllerin görüneceğini Stats'ın ayarlarından seç.",
                    symbol: "chart.xyaxis.line", start: StatsFeature.start, stop: StatsFeature.stop),
        ]
    }
}
