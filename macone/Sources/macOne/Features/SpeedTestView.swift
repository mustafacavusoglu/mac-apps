import SwiftUI

/// Hız testi ekranı: canlı ibre yayı, ortada büyük değer, altta üç sonuç.
struct SpeedTestView: View {
    @StateObject private var model: SpeedTestModel
    init(model: SpeedTestModel? = nil) { _model = StateObject(wrappedValue: model ?? SpeedTestModel()) }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Gauge(value: gaugeValue, colors: colors, active: model.isRunning)
                center
            }
            .frame(width: 300, height: 270)
            .padding(.bottom, -36)  // yayın altı açık; boşluğu kapat

            HStack(spacing: 8) {
                Result(title: "Ping", symbol: "wave.3.right", value: model.ping, unit: "ms", active: model.phase == .ping)
                Result(title: "İndirme", symbol: "arrow.down.circle", value: model.download, unit: "Mbps", active: model.phase == .download)
                Result(title: "Yükleme", symbol: "arrow.up.circle", value: model.upload, unit: "Mbps", active: model.phase == .upload)
            }

            footer
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.3), value: model.phase)
    }

    // MARK: - Orta

    @ViewBuilder private var center: some View {
        switch model.phase {
        case .idle:
            StartButton { model.run() }
        case .failed(let message):
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark").font(.system(size: 28)).foregroundStyle(.secondary)
                Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(width: 170)
            }
        default:
            VStack(spacing: 2) {
                Label(phaseTitle, systemImage: phaseSymbol)
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Text(String(format: model.phase == .ping ? "%.0f" : "%.1f", model.live))
                    .font(.system(size: 42, weight: .semibold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText(value: model.live))
                    .animation(.easeOut(duration: 0.15), value: model.live)
                Text(model.phase == .ping ? "ms" : "Mbps").font(.system(size: 12, weight: .medium)).foregroundStyle(.tertiary)
            }
            .offset(y: 6)
        }
    }

    @ViewBuilder private var footer: some View {
        switch model.phase {
        case .done, .failed:
            Button("Tekrar dene") { model.run() }.buttonStyle(.borderedProminent).controlSize(.large)
        case .idle:
            Text("Cloudflare · 4 paralel bağlantı").font(.caption).foregroundStyle(.tertiary).frame(height: 28)
        default:
            Button("Durdur") { model.cancel() }.buttonStyle(.bordered).controlSize(.large)
        }
    }

    // MARK: - Aşamaya göre görünüm

    /// İbre: ping'de boş, aktarımda canlı değer, bitince indirme sonucu.
    private var gaugeValue: Double {
        switch model.phase {
        case .download, .upload: model.live
        case .done: model.download ?? 0
        default: 0
        }
    }
    private var colors: [Color] {
        model.phase == .upload ? [Color(red: 0.75, green: 0.35, blue: 0.95), Color(red: 1, green: 0.4, blue: 0.6)]
                               : [Color(red: 0.25, green: 0.8, blue: 1), Color(red: 0.37, green: 0.36, blue: 0.9)]
    }
    private var phaseTitle: String {
        switch model.phase { case .ping: "Ping"; case .upload: "Yükleme"; case .done: "İndirme"; default: "İndirme" }
    }
    private var phaseSymbol: String {
        switch model.phase { case .ping: "wave.3.right"; case .upload: "arrow.up"; default: "arrow.down" }
    }
}

// MARK: - Parçalar

/// 270°'lik yay; ölçek logaritmik (0–1000 Mbps), canlıyken hafif parlar.
private struct Gauge: View {
    let value: Double
    let colors: [Color]
    let active: Bool
    private static let marks: [Double] = [0, 10, 50, 100, 250, 500, 1000]
    private static let sweep = 0.75

    static func fraction(_ v: Double) -> Double { min(log10(1 + max(v, 0)) / log10(1001), 1) }

    var body: some View {
        GeometryReader { g in
            let size = min(g.size.width, g.size.height)
            let r = size / 2 - 26
            ZStack {
                arc.stroke(Color.primary.opacity(0.07), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                arc.trim(from: 0, to: Self.fraction(value))
                    .stroke(AngularGradient(colors: colors, center: .center, startAngle: .degrees(135), endAngle: .degrees(405)),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .shadow(color: colors.last!.opacity(active ? 0.55 : 0.25), radius: active ? 10 : 5)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: value)
                ForEach(Self.marks, id: \.self) { m in
                    let a = Angle.degrees(135 + 270 * Self.fraction(m))
                    Text(m >= 1000 ? "1G" : "\(Int(m))")
                        .font(.system(size: 9, weight: .medium)).monospacedDigit().foregroundStyle(.tertiary)
                        .position(x: size / 2 + (r - 22) * cos(a.radians), y: size / 2 + (r - 22) * sin(a.radians))
                }
            }
            .frame(width: size, height: size)
            .padding(.horizontal, (g.size.width - size) / 2)
        }
    }

    private var arc: some Shape { GaugeArc(sweep: Self.sweep) }
}

private struct GaugeArc: Shape {
    let sweep: Double
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2 - 26
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r,
                 startAngle: .degrees(135), endAngle: .degrees(135 + 360 * sweep), clockwise: false)
        return p
    }
}

/// Ortadaki "Başla" düğmesi: yavaşça nabız atan halka.
/// Nabız saate göre çizilir (TimelineView). withAnimation(.repeatForever) kullanılmaz: açılır panelde
/// düğmenin konumunu da canlandırıp onu sürekli soldan sağa kaydırıyordu.
private struct StartButton: View {
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        ZStack {
            TimelineView(.animation) { ctx in
                let p = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6  // 0…1
                Circle().stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                    .scaleEffect(1 + 0.18 * p).opacity(1 - p)
            }
            Circle().fill(LinearGradient(colors: [Color(red: 0.25, green: 0.8, blue: 1), Color(red: 0.37, green: 0.36, blue: 0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color(red: 0.37, green: 0.36, blue: 0.9).opacity(hover ? 0.6 : 0.35), radius: hover ? 14 : 8, y: 3)
            Text("Başla").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
        }
        .frame(width: 104, height: 104)
        .scaleEffect(hover ? 1.04 : 1)
        .animation(.easeOut(duration: 0.15), value: hover)
        .contentShape(Circle())
        .onTapGesture(perform: action)
        .onHover { hover = $0 }
    }
}

/// Alttaki sonuç kutucuğu; o anki aşama vurgulanır.
private struct Result: View {
    let title: String, symbol: String
    let value: Double?
    let unit: String
    let active: Bool

    var body: some View {
        VStack(spacing: 4) {
            Label(title, systemImage: symbol).font(.system(size: 10, weight: .medium))
                .foregroundStyle(active ? Color.accentColor : .secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value.map { String(format: unit == "ms" ? "%.0f" : "%.1f", $0) } ?? "—")
                    .font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                Text(unit).font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(active ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(active ? Color.accentColor.opacity(0.35) : .clear))
    }
}

