// ⌥Tab'ı yakalayan klavye olay musluğu (Erişilebilirlik izni gerekir).
// Yalnız tuş koduna ve ⌥/⇧'e bakar; hiçbir tuş kaydedilmez ya da yazdırılmaz.
import AppKit
import Carbon.HIToolbox

private var tap: CFMachPort?
private var target: Switcher!

/// true → olay yutulur, öndeki uygulamaya gitmez.
private func handle(_ type: CGEventType, _ e: CGEvent) -> Bool {
    let opt = e.flags.contains(.maskAlternate)
    if type == .flagsChanged { if !opt && target.isOpen { target.commit() }; return false }
    let key = Int(e.getIntegerValueField(.keyboardEventKeycode))
    if key == kVK_Tab && opt {
        let back = e.flags.contains(.maskShift)
        if target.isOpen { target.step(back ? -1 : 1) } else { target.open(backwards: back) }
        return true
    }
    guard target.isOpen else { return false }
    switch key {
    case kVK_Escape: target.cancel()
    case kVK_Return: target.commit()
    case kVK_LeftArrow: target.step(-1)
    case kVK_RightArrow: target.step(1)
    case kVK_UpArrow: target.row(-1)
    case kVK_DownArrow: target.row(1)
    default: return false
    }
    return true
}

/// Musluğu kurar; izin yoksa false döner.
func startHotkey(_ s: Switcher) -> Bool {
    target = s
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.flagsChanged.rawValue)
    tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
                            callback: { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {  // macOS yavaş musluğu kapatır; geri aç
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        return handle(type, event) ? nil : Unmanaged.passUnretained(event)
    }, userInfo: nil)
    guard let tap else { return false }
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    print("⌥Tab hazır")
    return true
}
