import SwiftUI

/// Tek paylaşılan Store + Watcher (tembel oluşur).
@MainActor
enum Shared {
    static let store = Store()
    static let watcher = Watcher(store: store)
}

/// Store'u oluşturur ve pano izlemeyi başlatır (tekrar çağrılabilir).
@MainActor
public func clipboardHistoryStart() { Shared.watcher.start() }

/// Pano izlemeyi durdurur; geçmiş dosyası diskte kalır.
@MainActor
public func clipboardHistoryStop() { Shared.watcher.stop() }

/// Geçmiş paneli; ana uygulama kendi menü/popover'ına gömebilir.
@MainActor
public struct ClipboardHistoryMenu: View {
    public init() {}
    public var body: some View { MenuView(store: Shared.store, watcher: Shared.watcher, showsQuit: false) }
}
