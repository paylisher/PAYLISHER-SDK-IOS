import Foundation

/// In-app teşhis halkası — cihazda in-app'in NEREDE öldüğünü görünür kılar.
///
/// NEDEN AYRI BİR MEKANİZMA: bu SDK'daki her teşhis satırı `hedgeLog`'a gider
/// ve `hedgeLog`, `hedgeLogEnabled` false ise hiçbir şey basmaz;
/// `hedgeLogEnabled` yalnız `toggleHedgeLog(config.debug)` ile açılıyor.
/// Yani `engageInAppConfig.debugLogging = true` TEK BAŞINA hiçbir çıktı
/// üretmez — üretim derlemesinde in-app'in tüm izi susturulmuş durumda.
/// Ayrıca bankanın üretim cihazına Xcode bağlanamıyor, dolayısıyla konsol
/// çıktısı zaten erişilemez.
///
/// Bu sınıf `hedgeLog`'a HİÇ dokunmaz ve hiçbir bayrağa bağlı değildir:
/// sınırlı (128 kayıt) bir bellek halkasına yazar. Halka iki şekilde okunur:
///   1. `PaylisherSDK.shared.inAppDiagnosticsDump()` — host uygulama bir
///      "destek" ekranında gösterebilir/paylaşabilir.
///   2. `diagnosticsBeacon` açıksa (ya da üst üste 3 fetch hatasından sonra
///      otomatik) Engage'in `/push/inapp/diag-beacon` ucuna gönderilir ve
///      operatörün açtığı `/__inapp` çıktısında sunucu kararının YANINDA
///      görünür.
///
/// Kayıtlar PII taşımaz: `distinctId` zaten sunucuya gönderilen değerdir,
/// sdkKey yalnız son 6 hane olarak yazılır, mesaj içeriği hiç yazılmaz.
@objc public final class PaylisherInAppDiagnostics: NSObject {
    @objc public static let shared = PaylisherInAppDiagnostics()

    public struct Event {
        public let at: Date
        public let stage: String
        public let detail: [String: String]
    }

    private static let capacity = 128

    private let lock = NSLock()
    private var ring: [Event] = []
    private var consecutiveFetchFailures = 0
    private var beaconInFlight = false

    override private init() {
        super.init()
    }

    // MARK: - Kayıt

    /// Tek bir olayı halkaya yazar. ASLA fırlatmaz, ASLA log basmaz, ASLA
    /// çağıranı bloke etmez — teşhis, teşhis ettiği akışı bozmamalı.
    func record(_ stage: String, _ detail: [String: String] = [:]) {
        let event = Event(at: Date(), stage: stage, detail: detail)
        lock.lock()
        ring.append(event)
        if ring.count > Self.capacity {
            ring.removeFirst(ring.count - Self.capacity)
        }
        lock.unlock()
    }

    /// Fetch başarısızlıklarını sayar. Üst üste 3 hatadan sonra, bayrak kapalı
    /// olsa bile TEK SEFERLİK beacon gönderilir: bozuk bir kurulum kimse bayrak
    /// açmadan kendini bildirsin. (Yanlış host / ATS reddi tam olarak bu vaka.)
    func recordFetchFailure(_ stage: String, _ detail: [String: String] = [:]) {
        record(stage, detail)
        lock.lock()
        consecutiveFetchFailures += 1
        let shouldSelfReport = consecutiveFetchFailures == 3
        lock.unlock()
        if shouldSelfReport {
            sendBeacon(force: true)
        }
    }

    func recordFetchSuccess(_ stage: String, _ detail: [String: String] = [:]) {
        record(stage, detail)
        lock.lock()
        consecutiveFetchFailures = 0
        lock.unlock()
    }

    // MARK: - Okuma

    /// Halkanın JSON dökümü. Host uygulama destek ekranında gösterebilir.
    @objc public func dumpJSON() -> String {
        let formatter = ISO8601DateFormatter()
        lock.lock()
        let snapshot = ring
        lock.unlock()

        let events: [[String: Any]] = snapshot.map { event in
            [
                "at": formatter.string(from: event.at),
                "stage": event.stage,
                "detail": event.detail,
            ]
        }

        let body: [String: Any] = [
            "platform": "ios",
            "sdkVersion": paylisherVersion,
            "events": events,
        ]

        guard
            let data = try? JSONSerialization.data(
                withJSONObject: body,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let text = String(data: data, encoding: .utf8)
        else {
            return "{\"error\":\"serialization-failed\"}"
        }
        return text
    }

    @objc public func reset() {
        lock.lock()
        ring.removeAll()
        consecutiveFetchFailures = 0
        lock.unlock()
    }

    // MARK: - Beacon

    /// Halkayı Engage'e gönderir. Fetch URL'i ile AYNI tabandan türetilir, yani
    /// hangi yol gerçekten çalışıyorsa onu miras alır. 2xx alınca halka temizlenir.
    func sendBeacon(force: Bool = false) {
        guard let config = PaylisherSDK.shared.config.engageInAppConfig else { return }
        guard force || config.diagnosticsBeacon else { return }

        lock.lock()
        if beaconInFlight {
            lock.unlock()
            return
        }
        beaconInFlight = true
        let snapshot = ring
        lock.unlock()

        guard !snapshot.isEmpty else {
            lock.lock(); beaconInFlight = false; lock.unlock()
            return
        }

        let endpoint = PaylisherEngageInAppService.shared.diagnosticsBeaconURLString()
        guard let url = URL(string: endpoint) else {
            lock.lock(); beaconInFlight = false; lock.unlock()
            return
        }

        let formatter = ISO8601DateFormatter()
        let sdk = PaylisherSDK.shared
        let sdkKey = config.sdkKey?.isEmpty == false ? config.sdkKey! : sdk.config.apiKey

        // 64 KB sınırını aşmamak için en yeni 128 olayın detayları zaten kısa;
        // yine de gövdeyi kırpılabilir tutmak için en yeni 64 olay gönderilir.
        let events: [[String: String]] = snapshot.suffix(64).map { event in
            var flat: [String: String] = [
                "at": formatter.string(from: event.at),
                "stage": event.stage,
            ]
            for (key, value) in event.detail {
                flat[key] = String(value.prefix(300))
            }
            return flat
        }

        var body: [String: Any] = [
            "sdkKey": sdkKey,
            "distinctId": sdk.getDistinctId(),
            "platform": "ios",
            "sdkVersion": paylisherVersion,
            "events": events,
        ]
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            body["appVersion"] = appVersion
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sdkKey, forHTTPHeaderField: "X-SDK-Key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            self.lock.lock()
            self.beaconInFlight = false
            if (200 ... 299).contains(status) {
                self.ring.removeAll()
            }
            self.lock.unlock()
        }.resume()
    }
}
