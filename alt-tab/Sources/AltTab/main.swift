// Alt-Tab — ⌥Tab ile canlı önizlemeli pencere değiştirici.
import AppKit
import AltTabKit

let args = CommandLine.arguments
if args.contains("--list") {  // izinsiz kontrol: pencere listesini yaz
    altTabPrintWindows()
    exit(0)
}

setvbuf(stdout, nil, _IOLBF, 0)
print("Erişilebilirlik:", AXIsProcessTrusted(), "Ekran Kaydı:", CGPreflightScreenCaptureAccess())
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if let i = args.firstIndex(of: "--preview"), i + 1 < args.count {
    altTabPreview(to: args[i + 1])
    app.run()
}

altTabStart()
app.run()
