import Foundation

/// Tüm sabitler tek yerde.
enum Config {
    static let visibleCount = 10      // kaydırmadan görünen satır sayısı
    static let maxCount = 50          // saklanan en fazla kayıt
    static let pollInterval = 0.5     // pano değişim kontrolü (sn)
    static let rowHeight: CGFloat = 28
    static let maxChars = 100_000     // bundan uzun metin saklanmaz
    static let previewChars = 90      // satırda gösterilen en fazla karakter

    static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Copy-Hist", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }
}
