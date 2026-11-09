import Foundation

struct Clip: Codable, Identifiable, Equatable {
    var id = UUID()
    let text: String
    let date: Date

    /// Satırda tek satır önizleme: boşluklar sıkıştırılır, uzunsa kısaltılır.
    var preview: String {
        let flat = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return flat.count > Config.previewChars ? String(flat.prefix(Config.previewChars)) + "…" : flat
    }
}
