import Cocoa
import ApplicationServices

// Finder öndeyken ⌘X (kes) ve ⌘V (kesilenleri buraya taşı). Erişilebilirlik izni ister.
// Metin alanı odakta ise (yeniden adlandırma, arama) dokunmaz. ⌘C kesmeyi iptal eder.
private var tap: CFMachPort?

private func textFieldFocused() -> Bool {
    var el: CFTypeRef?
    guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &el) == .success,
          let el else { return false }
    var role: CFTypeRef?
    AXUIElementCopyAttributeValue(el as! AXUIElement, kAXRoleAttribute as CFString, &role)
    return ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role as? String ?? "")
}

private func finder(_ src: String) -> String? {
    var err: NSDictionary?
    return NSAppleScript(source: "tell application \"Finder\"\n\(src)\nend tell")?.executeAndReturnError(&err).stringValue
}

private func cutSelection() {
    let out = finder("""
    set o to ""
    repeat with i in (selection as alias list)
      set o to o & POSIX path of i & linefeed
    end repeat
    return o
    """)
    let paths = (out ?? "").split(separator: "\n").map(String.init)
    if !paths.isEmpty { cutPaths = paths }
}

private func pasteCut() {
    let dir = finder("return POSIX path of (target of front Finder window as alias)") ?? NSHomeDirectory() + "/Desktop"
    moveCut(to: URL(fileURLWithPath: dir))
}

private func handle(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return pass
    }
    guard type == .keyDown,
          NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder",
          event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]) == .maskCommand,
          !textFieldFocused() else { return pass }
    switch event.getIntegerValueField(.keyboardEventKeycode) {
    case 7:  DispatchQueue.main.async(execute: cutSelection); return nil             // ⌘X
    case 9 where !cutPaths.isEmpty: DispatchQueue.main.async(execute: pasteCut); return nil  // ⌘V
    case 8:  cutPaths = []                                                           // ⌘C: kesme iptal
    default: break
    }
    return pass
}

// İzin verilene kadar 2 sn'de bir dener.
func startShortcuts() {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    guard AXIsProcessTrustedWithOptions(opts),
          let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                    eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue), callback: handle, userInfo: nil)
    else { DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: startShortcuts); return }
    tap = t
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
}
