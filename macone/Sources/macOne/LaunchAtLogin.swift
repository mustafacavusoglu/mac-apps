import Foundation
import ServiceManagement
import AppKit

/// "Oturum açılınca başlat": macOS'un kendi Giriş Öğeleri listesine kayıt (SMAppService).
/// Varsayılan kapalı; kullanıcı Ayarlar'dan açar. Durum macOS'ta tutulur, burada saklanmaz.
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isOn = SMAppService.mainApp.status == .enabled
    /// Kullanıcı Sistem Ayarları'nda onay vermeli (macOS bazen ister).
    @Published private(set) var needsApproval = SMAppService.mainApp.status == .requiresApproval
    @Published private(set) var error: String?

    func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = "Değiştirilemedi: \(error.localizedDescription)"
        }
        refresh()
    }

    func refresh() {
        let s = SMAppService.mainApp.status
        isOn = s == .enabled
        needsApproval = s == .requiresApproval
    }

    func openLoginItemsSettings() { SMAppService.openSystemSettingsLoginItems() }
}
