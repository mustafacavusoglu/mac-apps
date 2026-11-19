import SwiftUI
import SpeedTestKit

/// Speed-Test: menü çubuğunda hız testi. Simgeye tıkla → canlı ibreli panel.
@main
struct SpeedTestApp: App {
    var body: some Scene {
        MenuBarExtra("Speed-Test", systemImage: "speedometer") {
            VStack(spacing: 0) {
                SpeedTestView().frame(width: 400)
                Divider()
                HStack {
                    Spacer()
                    Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Çık")
                }
                .padding(10)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
