import AppKit
import SwiftUI

/// macOne normalde arka plan uygulamasıdır (LSUIElement): Dock'ta, ⌘Tab'da ve Alt-Tab'da görünmez.
/// Mac-Clear ya da Ayarlar penceresi açıkken normal uygulamaya döner, son pencere kapanınca geri gizlenir.
@MainActor enum DockPresence {
    private static var open = 0
    static func opened() { open += 1; NSApp.setActivationPolicy(.regular) }
    static func closed() {
        open = max(0, open - 1)
        if open == 0 { NSApp.setActivationPolicy(.accessory) }
    }
}

extension View {
    func showsInAppSwitcher() -> some View {
        onAppear(perform: DockPresence.opened).onDisappear(perform: DockPresence.closed)
    }
}
