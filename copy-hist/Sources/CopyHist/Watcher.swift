import AppKit

/// Panoyu yoklar; yeni düz metni Store'a ekler.
/// Parola yöneticilerinin işaretlediği (gizli/geçici) içerik kaydedilmez — CopyClip da ConcealedType'a bakar.
@MainActor
final class Watcher {
    private let store: Store
    private var lastCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    private static let secret: Set<NSPasteboard.PasteboardType> = [
        .init("org.nspasteboard.ConcealedType"), .init("org.nspasteboard.TransientType"),
    ]

    init(store: Store) { self.store = store }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Config.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastCount else { return }
        lastCount = pb.changeCount
        if let types = pb.types, !Self.secret.isDisjoint(with: types) { return }
        if let text = pb.string(forType: .string) { store.add(text) }
    }

    /// Satıra tıklanınca: panoya yaz. Kendi yazdığımızı tekrar kaydetmemek için sayacı güncelle.
    func copy(_ clip: Clip) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(clip.text, forType: .string)
        lastCount = pb.changeCount
        store.add(clip.text)   // öne al
    }
}
