import SwiftUI
import SpeedTestKit
import AppKit
import CopyHistKit
import MacClearKit

/// macOne: açıp kapatma macOne simgesinden (merkez) yapılır. Pano ve Hız Testi'nin menü çubuğunda kendi
/// simgesi var; Stats kendi simgelerini kendisi çizer. Mac-Clear macOne panelinden açılır.
/// Arka planda çalışanlar (Alt-Tab, Kes/Taşı) simgesizdir, yalnız açık/kapalı.
@main
struct MacOneApp: App {
    @StateObject private var features: FeatureStore

    init() {
        Snapshot.runIfRequested()
        let store = FeatureStore(features: Catalog.make())
        store.startEnabled()
        _features = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        // Merkez: özellikleri aç/kapat, Ayarlar, Çık.
        MenuBarExtra("macOne", systemImage: "laptopcomputer") {
            MenuView(features: features)
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra("Pano Geçmişi", systemImage: "doc.on.clipboard", isInserted: features.binding(Catalog.clipboard)) {
            FeaturePanel(title: "Pano Geçmişi", symbol: "doc.on.clipboard", turnOff: { features.set(Catalog.clipboard, false) }) {
                ClipboardHistoryMenu()
            }
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra("Hız Testi", systemImage: "speedometer", isInserted: features.binding(Catalog.speedTest)) {
            FeaturePanel(title: "Hız Testi", symbol: "speedometer", turnOff: { features.set(Catalog.speedTest, false) }) {
                SpeedTestView().frame(width: 400)
            }
        }
        .menuBarExtraStyle(.window)

        Window("Mac-Clear", id: "mac-clear") {
            MacClearView().frame(minWidth: 860, minHeight: 560)
        }
        .windowToolbarStyle(.unified)

        Window("macOne Ayarları", id: "settings") {
            SettingsView(features: features).frame(width: 520)
        }
        .windowResizability(.contentSize)
    }
}
