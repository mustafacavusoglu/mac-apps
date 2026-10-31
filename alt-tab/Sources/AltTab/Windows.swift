// Pencere listesi, odaklama ve küçük resim — tümü public API, bir tek _AXUIElementGetWindow hariç.
import AppKit
import ScreenCaptureKit

// Private ama yaygın kullanılan API: AX penceresini CGWindowID'ye eşler.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ el: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

struct Win {
    let id: CGWindowID, pid: pid_t, app: String, title: String, icon: NSImage?, size: CGSize
}

// ponytail: yalnız geçerli Space'teki görünür pencereler, z-sırası = son kullanılan sırası.
// Küçültülmüş/diğer Space pencereleri için SkyLight + AX gözlemcileri gerekir.
func listWindows() -> [Win] {
    guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
    return info.compactMap { d in
        guard (d[kCGWindowLayer as String] as? Int) == 0,
              let id = d[kCGWindowNumber as String] as? CGWindowID,
              let pid = d[kCGWindowOwnerPID as String] as? pid_t, pid != getpid(),
              let b = d[kCGWindowBounds as String] as? [String: CGFloat], let w = b["Width"], let h = b["Height"], w > 80, h > 80,
              let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular
        else { return nil }
        return Win(id: id, pid: pid, app: app.localizedName ?? "?", title: d[kCGWindowName as String] as? String ?? "",
                   icon: app.icon, size: CGSize(width: w, height: h))
    }
}

func focus(_ w: Win) {
    let axApp = AXUIElementCreateApplication(w.pid)
    var ref: CFTypeRef?
    if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref) == .success, let wins = ref as? [AXUIElement],
       let el = wins.first(where: { var id: CGWindowID = 0; return _AXUIElementGetWindow($0, &id) == .success && id == w.id }) {
        AXUIElementPerformAction(el, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(el, kAXMainAttribute as CFString, kCFBooleanTrue)
    }
    // Arka plan uygulaması NSRunningApplication.activate ile başkasını öne alamayabilir; AX ile alıyoruz.
    AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
}

/// Görüntü yalnız bellekte tutulur, diske yazılmaz.
func thumbnail(_ id: CGWindowID, size: CGSize, in content: SCShareableContent) async -> NSImage? {
    guard let w = content.windows.first(where: { $0.windowID == id }) else { return nil }
    let cfg = SCStreamConfiguration()
    cfg.width = Int(size.width * 2); cfg.height = Int(size.height * 2); cfg.showsCursor = false  // Retina için 2x
    guard let img = try? await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: w), configuration: cfg) else { return nil }
    return NSImage(cgImage: img, size: size)
}
