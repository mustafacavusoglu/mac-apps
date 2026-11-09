import Foundation

/// Geçmiş listesi: en yeni başta, tekrarlar öne alınır, en fazla Config.maxCount kayıt, diske yazılır.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var clips: [Clip] = []

    init() { load() }
    init(sample: [Clip]) { clips = sample }   // tools/snapshot.swift için; diske dokunmaz

    func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= Config.maxChars else { return }
        clips.removeAll { $0.text == text }          // aynı metin varsa eskisini at, yenisini öne koy
        clips.insert(Clip(text: text, date: Date()), at: 0)
        if clips.count > Config.maxCount { clips.removeLast(clips.count - Config.maxCount) }
        save()
    }

    func remove(_ clip: Clip) { clips.removeAll { $0.id == clip.id }; save() }
    func clear() { clips = []; save() }

    private func load() {
        guard let data = try? Data(contentsOf: Config.storeURL),
              let list = try? JSONDecoder().decode([Clip].self, from: data) else { return }
        clips = Array(list.prefix(Config.maxCount))
    }

    private func save() {
        try? JSONEncoder().encode(clips).write(to: Config.storeURL, options: .atomic)
    }
}
