import AppKit
import CoreGraphics

/// Alt-Tab önizlemeleri Ekran Kaydı izni ister; izin yoksa kutucuklarda yalnız uygulama simgesi görünür.
/// İzin uygulama başına verilir: tek başına Alt-Tab'ın izni macOne'a geçmez.
enum Permissions {
    /// Süreç başına önbelleğe alınır: izin verildikten sonra true olması için uygulama yeniden açılmalı.
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }

    static func openScreenRecordingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    /// macOS Ekran Kaydı iznini ancak uygulama yeniden açılınca uygular.
    static func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? p.run()
        NSApp.terminate(nil)
    }
}
