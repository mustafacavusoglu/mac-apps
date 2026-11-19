import Foundation

/// Cloudflare'in herkese açık uç noktalarıyla hız ölçümü (speed.cloudflare.com ile aynı sunucular).
/// İndirme/yükleme 4 paralel bağlantıyla yapılır; her aşama en fazla 10 sn sürer.
/// Hız ilk bayt geldikten sonra ölçülür (bağlantı kurma süresi sayılmaz), canlı değer akarken güncellenir.
@MainActor
final class SpeedTestModel: ObservableObject {
    enum Phase: Equatable { case idle, ping, download, upload, done, failed(String) }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var live: Double = 0          // aşamaya göre ms ya da Mbps
    @Published private(set) var ping: Double?
    @Published private(set) var download: Double?
    @Published private(set) var upload: Double?
    private var task: Task<Void, Never>?

    private static let base = "https://speed.cloudflare.com"
    private static let streams = 4
    private static let downBytes = 25_000_000            // bağlantı başına
    private static let upBytes = 8_000_000
    private static let phaseLimit: TimeInterval = 10

    var isRunning: Bool { [.ping, .download, .upload].contains(phase) }

    func run() {
        guard !isRunning else { return }
        ping = nil; download = nil; upload = nil; live = 0
        task = Task {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.timeoutIntervalForRequest = 10
            cfg.httpMaximumConnectionsPerHost = Self.streams
            let session = URLSession(configuration: cfg)
            defer { session.invalidateAndCancel() }
            do {
                phase = .ping
                ping = try await measurePing(session)
                phase = .download; live = 0
                download = try await transfer(session, upload: false)
                phase = .upload; live = 0
                upload = try await transfer(session, upload: true)
                live = download ?? 0
                phase = .done
            } catch {
                phase = .failed((error as? URLError)?.code == .notConnectedToInternet ? "İnternet bağlantısı yok" : "Ölçüm yapılamadı: \(error.localizedDescription)")
            }
        }
    }

    /// Yalnız `--snapshot` için: ekranı belirli bir anda göstermek.
    func preview(_ phase: Phase, live: Double, ping: Double?, download: Double?, upload: Double?) {
        self.phase = phase; self.live = live; self.ping = ping; self.download = download; self.upload = upload
    }

    func cancel() { task?.cancel(); task = nil; phase = .idle; live = 0 }

    /// İlk istek bağlantıyı (TLS) kurar ve sayılmaz; sonraki 5 isteğin ortancası.
    private func measurePing(_ session: URLSession) async throws -> Double {
        let url = URL(string: "\(Self.base)/__down?bytes=0")!
        _ = try await session.data(from: url)
        var times: [Double] = []
        for _ in 0..<5 {
            let t0 = Date()
            _ = try await session.data(from: url)
            let ms = Date().timeIntervalSince(t0) * 1000
            times.append(ms); live = ms
        }
        return times.sorted()[times.count / 2]
    }

    /// Paralel aktarım; görevlerin bayt sayaçlarını 0,1 sn'de bir okuyup canlı Mbps hesaplar.
    private func transfer(_ session: URLSession, upload: Bool) async throws -> Double {
        let tasks: [URLSessionTask] = (0..<Self.streams).map { _ in
            if upload {
                var req = URLRequest(url: URL(string: "\(Self.base)/__up")!)
                req.httpMethod = "POST"
                return session.uploadTask(with: req, from: Data(count: Self.upBytes))
            }
            return session.dataTask(with: URL(string: "\(Self.base)/__down?bytes=\(Self.downBytes)")!)
        }
        tasks.forEach { $0.resume() }
        defer { tasks.forEach { $0.cancel() } }

        let bytes = { tasks.reduce(Int64(0)) { $0 + (upload ? $1.countOfBytesSent : $1.countOfBytesReceived) } }
        let start = Date()
        var first: (at: Date, bytes: Int64)?
        var result = 0.0
        while true {
            try await Task.sleep(nanoseconds: 100_000_000)
            let now = Date(), total = bytes()
            if first == nil, total > 0 { first = (now, total) }
            if let f = first, now.timeIntervalSince(f.at) > 0.2 {
                result = Double(total - f.bytes) * 8 / now.timeIntervalSince(f.at) / 1_000_000
                live = result
            }
            let finished = tasks.allSatisfy { $0.state == .completed }
            if finished || now.timeIntervalSince(start) > Self.phaseLimit { break }
        }
        if first == nil, let err = tasks.compactMap(\.error).first { throw err }
        return result
    }
}
