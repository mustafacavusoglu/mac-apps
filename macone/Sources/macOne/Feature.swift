import Foundation
import SwiftUI

/// Kullanıcının açıp kapatabildiği bir özellik. Durum UserDefaults'ta "feature.<id>" anahtarında tutulur.
struct Feature: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let start: () -> Void
    let stop: () -> Void
}

/// Özelliklerin açık/kapalı durumunu tutar; açılışta açık olanları başlatır, değişince başlat/durdur çağırır.
@MainActor
final class FeatureStore: ObservableObject {
    let features: [Feature]
    @Published private var on: [String: Bool] = [:]

    init(features: [Feature]) {
        self.features = features
        for f in features { on[f.id] = Self.stored(f.id) }
    }

    func isOn(_ id: String) -> Bool { on[id] ?? false }

    /// Açılışta: açık olan her özelliği başlat.
    func startEnabled() {
        for f in features where isOn(f.id) { f.start() }
    }

    func set(_ id: String, _ value: Bool) {
        guard let f = features.first(where: { $0.id == id }), on[id] != value else { return }
        on[id] = value
        UserDefaults.standard.set(value, forKey: Self.key(id))
        value ? f.start() : f.stop()
    }

    /// Menü çubuğu simgesi için: simge görünürlüğü = özellik açık mı. Simge ⌘-sürüklenip atılırsa özellik kapanır.
    func binding(_ id: String) -> Binding<Bool> {
        Binding(get: { self.isOn(id) }, set: { self.set(id, $0) })
    }

    private static func key(_ id: String) -> String { "feature.\(id)" }
    /// İlk açılışta her özellik açık gelir; kullanıcı istediğini kapatır.
    private static func stored(_ id: String) -> Bool {
        UserDefaults.standard.object(forKey: key(id)) as? Bool ?? true
    }
}
