import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

@objc public enum InAppAckStatus: Int {
    case delivered, seen, clicked, dismissed
    var rawString: String {
        switch self {
        case .delivered: return "DELIVERED"
        case .seen: return "SEEN"
        case .clicked: return "CLICKED"
        case .dismissed: return "DISMISSED"
        }
    }
}

/// Engage in-app "pull" delivery. Mirrors paylisher-android's in-app flow
/// (PaylisherAndroid.kt + PaylisherEngageInAppApi.kt) 1:1:
///  - foreground fetch (triggered by PaylisherSDK.handleAppDidBecomeActive with a
///    2s delay, mirroring Android ProcessLifecycleOwner.onResume + foregroundFetchDelayMs)
///  - sdkKey derived from the SDK apiKey, fetchEndpoint from the SDK host
///  - shouldDisplayMessage gate (displayTime - 60s buffer / expireDate)
///  - 1-hour de-dup window keyed by pushId (processedNotifications)
///  - delayed rendering: max(condition.delay minutes, displayTime - now)
///  - DELIVERED ack sent at enqueue time
final class PaylisherEngageInAppService: NSObject {
    static let shared = PaylisherEngageInAppService()

    private let queueLock = NSLock()
    private var pendingMessages: [[String: Any]] = []

    // De-dup: key -> first-seen epoch seconds. Mirrors Android processedNotifications
    // (notificationTimeoutMs = 1h). Same pushId is not re-shown within the window.
    private let processedLock = NSLock()
    private var processedNotifications: [String: TimeInterval] = [:]
    private let notificationTimeoutSeconds: TimeInterval = 3600 // Android: 3600000ms (1 hour)

    // Ekran değişiminde fetch (Android fetchEngageInAppMessagesOnScreenChange 1:1).
    // Debounce: process-global 15s. Pencere içindeyse istek DÜŞMEZ; pencere dolunca
    // bir kez çalışacak şekilde ERTELENİR (kullanıcı bir daha ekran değiştirmezse kaybolmasın).
    private let screenChangeFetchLock = NSLock()
    private var lastScreenChangeFetchAt: TimeInterval = 0
    private var pendingScreenChangeFetch = false
    private let screenChangeFetchMinIntervalSeconds: TimeInterval = 15 // Android: 15_000L

    // Yapılandırma anlık görüntüsü halkaya bir kez yazılır.
    private let configSnapshotLock = NSLock()
    private var configSnapshotRecorded = false

    override private init() {
        super.init()
        #if os(iOS) || os(tvOS)
        // Render queued messages when the app becomes active. The fetch itself is
        // triggered by PaylisherSDK.handleAppDidBecomeActive (2s delay), mirroring
        // Android where ProcessLifecycleOwner.onResume fetches and onActivityResumed
        // renders. We intentionally do NOT fetch here to avoid a duplicate request.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForegroundForRender),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Fetch

    func refresh(using sdk: PaylisherSDK, target: String? = nil) {
        guard let config = sdk.config.engageInAppConfig else {
            // Bugün tamamen sessiz: engageInAppConfig atanmamışsa in-app ÖZELLİĞİ
            // hiç yoktur ve hiçbir yerde iz kalmaz. Entegrasyon hatasının en sık
            // hâli tam olarak budur.
            PaylisherInAppDiagnostics.shared.record("skip.no_engage_config")
            return
        }

        recordConfigSnapshotOnce(config: config, sdk: sdk)

        let distinctId = sdk.getDistinctId().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !distinctId.isEmpty else {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app fetch skipped: distinctId is empty")
            }
            PaylisherInAppDiagnostics.shared.record("skip.empty_distinct_id")
            return
        }

        let endpoint = resolveFetchURLString(config: config, sdk: sdk)
        guard let url = URL(string: endpoint) else {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app fetch skipped: invalid fetchEndpoint \(endpoint)")
            }
            PaylisherInAppDiagnostics.shared.record("skip.invalid_url", ["endpoint": endpoint])
            return
        }

        let effectiveSdkKey = resolveSdkKey(config: config, sdk: sdk)

        // İsteğin GERÇEKTEN çıktığının kanıtı. Sunucu tarafında hiç kayıt yoksa
        // ama burada fetch.start varsa, mesaj ağda ölmüştür (yanlış host, ATS,
        // TLS) — sunucu ile istemci arasındaki ayrımın tek dayanağı bu satır.
        PaylisherInAppDiagnostics.shared.record("fetch.start", [
            "endpoint": endpoint,
            "sdkKeySuffix": PaylisherEngageInAppService.maskKey(effectiveSdkKey),
            "distinctId": distinctId,
            "target": target ?? "",
        ])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(effectiveSdkKey, forHTTPHeaderField: "X-SDK-Key")

        // Android passes `target` straight through (null on foreground fetch). We do
        // NOT fall back to the current screen, so server-side target matching behaves
        // identically across platforms.
        let body = buildRequestBody(
            config: config,
            sdkKey: effectiveSdkKey,
            distinctId: distinctId,
            target: target
        )

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app fetch body encode failed: \(error)")
            }
            PaylisherInAppDiagnostics.shared.record("skip.body_encode_failed", [
                "error": String(describing: error),
            ])
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                if config.debugLogging {
                    hedgeLog("[PaylisherSDK] Engage in-app fetch failed: \(error.localizedDescription)")
                }
                // ATS / TLS reddi burada görünür ve SADECE NSError domain+code
                // ile ayırt edilebilir: -1022 ATS (cleartext ya da zayıf TLS),
                // -1202 güvenilmeyen sertifika (özel CA), -1200 genel TLS,
                // -1004 bağlanılamadı. localizedDescription bu ayrımı kaybeder.
                let nsError = error as NSError
                PaylisherInAppDiagnostics.shared.recordFetchFailure("fetch.transport_error", [
                    "domain": nsError.domain,
                    "code": "\(nsError.code)",
                    "hint": PaylisherEngageInAppService.transportErrorHint(nsError),
                    "endpoint": endpoint,
                    "message": error.localizedDescription,
                ])
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                PaylisherInAppDiagnostics.shared.recordFetchFailure("fetch.non_http_response")
                return
            }

            // Sunucu tarafı iziyle eşleşme anahtarı (main.ts taşıma kaydı bunu
            // yanıt başlığında döndürüyor).
            let diagId = httpResponse.value(forHTTPHeaderField: "X-Engage-Diag-Id") ?? ""

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                if config.debugLogging {
                    hedgeLog("[PaylisherSDK] Engage in-app fetch failed with status \(httpResponse.statusCode)")
                }
                // Gövde bugün hiç okunmuyordu: sunucunun "Invalid sdkKey" /
                // "Rate limit exceeded" açıklaması çöpe gidiyordu.
                let bodyHead = data.flatMap { String(data: $0.prefix(512), encoding: .utf8) } ?? ""
                PaylisherInAppDiagnostics.shared.recordFetchFailure("fetch.http_error", [
                    "status": "\(httpResponse.statusCode)",
                    "endpoint": endpoint,
                    "diagId": diagId,
                    "body": bodyHead,
                ])
                return
            }

            guard let data, !data.isEmpty else {
                PaylisherInAppDiagnostics.shared.recordFetchFailure("fetch.empty_body", [
                    "diagId": diagId,
                ])
                return
            }

            PaylisherInAppDiagnostics.shared.recordFetchSuccess("fetch.ok", [
                "status": "\(httpResponse.statusCode)",
                "bytes": "\(data.count)",
                "diagId": diagId,
            ])

            self.handleResponseData(data, debugLogging: config.debugLogging)
        }.resume()
    }

    /// NSURLError kodlarının teşhis karşılığı. Bankada en olası iki vaka
    /// (on-prem `http://` ve özel CA imzalı `https://`) burada ayrışır.
    private static func transportErrorHint(_ error: NSError) -> String {
        guard error.domain == NSURLErrorDomain else { return "" }
        switch error.code {
        case NSURLErrorAppTransportSecurityRequiresSecureConnection:
            return "ATS: uygulama düz http:// adrese izin vermiyor. Info.plist'te NSAppTransportSecurity istisnası gerekir ya da endpoint https:// olmalı."
        case NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasUnknownRoot,
             NSURLErrorServerCertificateNotYetValid,
             NSURLErrorServerCertificateHasBadDate:
            return "Sunucu sertifikası güvenilmiyor: on-prem özel CA cihazda kurulu/güvenilir değil. Android bu durumda kendi trust store'una göre davranır — iOS/Android farkının klasik kaynağı."
        case NSURLErrorSecureConnectionFailed:
            return "TLS el sıkışması başarısız: sunucu TLS sürümü/şifre takımı iOS'un ATS tabanının altında olabilir."
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
            return "Host çözülemedi/bağlanılamadı: fetchEndpoint yanlış host'a bakıyor ya da cihaz o ağda değil."
        case NSURLErrorTimedOut:
            return "Zaman aşımı."
        default:
            return ""
        }
    }

    private static func maskKey(_ key: String) -> String {
        guard !key.isEmpty else { return "" }
        return "…\(key.suffix(6))"
    }

    /// Beacon ucu — fetch URL'i ile AYNI tabandan türetilir ki hangi yol
    /// gerçekten çalışıyorsa onu miras alsın.
    func diagnosticsBeaconURLString() -> String {
        guard let config = PaylisherSDK.shared.config.engageInAppConfig else { return "" }
        let endpoint = resolveFetchURLString(config: config, sdk: PaylisherSDK.shared)
        guard let lastSlash = endpoint.lastIndex(of: "/") else { return endpoint }
        return endpoint[..<endpoint.index(after: lastSlash)] + "diag-beacon"
    }

    /// Yapılandırmanın tek seferlik anlık görüntüsü. `captureScreenViews`
    /// kapalıysa ekran-değişimi fetch'i ve bekleyen kuyruğun boşaltılması HİÇ
    /// çalışmaz (Android'de bu kancalar koşulsuz kurulur) — bu satır olmadan
    /// o fark dışarıdan görülemez.
    private func recordConfigSnapshotOnce(config: PaylisherEngageInAppConfig, sdk: PaylisherSDK) {
        configSnapshotLock.lock()
        let alreadyRecorded = configSnapshotRecorded
        configSnapshotRecorded = true
        configSnapshotLock.unlock()
        guard !alreadyRecorded else { return }

        PaylisherInAppDiagnostics.shared.record("config.snapshot", [
            "sdkVersion": paylisherVersion,
            "host": sdk.config.host.absoluteString,
            "fetchEndpoint": resolveFetchURLString(config: config, sdk: sdk),
            "fetchEndpointExplicit": config.fetchEndpoint?.isEmpty == false ? "true" : "false",
            "captureScreenViews": sdk.config.captureScreenViews ? "true" : "false",
            "autoFetchOnForeground": config.autoFetchOnForeground ? "true" : "false",
            "excludedActivities": config.excludedActivities.joined(separator: ","),
            "maxMessages": "\(config.maxMessages)",
            "debugLogging": config.debugLogging ? "true" : "false",
            "certificatePinsConfigured": sdk.config.certificatePins.isEmpty ? "false" : "true",
        ])
    }

    // MARK: - Ack

    func acknowledge(distinctId: String, pushId: String, status: InAppAckStatus) {
        #if os(iOS) || os(tvOS)
        guard let config = PaylisherSDK.shared.config.engageInAppConfig else {
            return
        }

        // Android acks only when pushId is numeric (toIntOrNull); match that, and
        // send pushId as an integer (the Engage ack DTO expects a number).
        guard let pushIdInt = Int(pushId) else {
            return
        }

        let endpoint = resolveFetchURLString(config: config, sdk: PaylisherSDK.shared)
        let ackEndpoint = ackUrlString(from: endpoint)
        guard let url = URL(string: ackEndpoint) else {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app ack skipped: invalid ack endpoint \(ackEndpoint)")
            }
            return
        }

        let effectiveSdkKey = resolveSdkKey(config: config, sdk: PaylisherSDK.shared)

        var body: [String: Any] = [
            "sdkKey": effectiveSdkKey,
            "distinctId": distinctId,
            "pushId": pushIdInt,
            "status": status.rawString,
        ]
        if let teamId = config.teamId, !teamId.isEmpty { body["teamId"] = teamId }
        if let projectId = config.projectId, !projectId.isEmpty { body["projectId"] = projectId }
        if let sourceId = config.sourceId, !sourceId.isEmpty { body["sourceId"] = sourceId }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(effectiveSdkKey, forHTTPHeaderField: "X-SDK-Key")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app ack body encode failed: \(error)")
            }
            return
        }

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error, config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app ack failed: \(error.localizedDescription)")
            }
        }.resume()
        #endif
    }

    // MARK: - URL / key resolution (mirrors Android resolveFetchUrl / effectiveSdkKey)

    private func resolveFetchURLString(config: PaylisherEngageInAppConfig, sdk: PaylisherSDK) -> String {
        if let endpoint = config.fetchEndpoint, !endpoint.isEmpty {
            return endpoint
        }
        let host = sdk.config.host.absoluteString
        let trimmed = host.hasSuffix("/") ? String(host.dropLast()) : host
        return "\(trimmed)/v1/push/inapp/fetch"
    }

    private func resolveSdkKey(config: PaylisherEngageInAppConfig, sdk: PaylisherSDK) -> String {
        if let key = config.sdkKey, !key.isEmpty {
            return key
        }
        return sdk.config.apiKey
    }

    private func ackUrlString(from fetchEndpoint: String) -> String {
        guard let lastSlash = fetchEndpoint.lastIndex(of: "/") else {
            return fetchEndpoint
        }
        let prefix = fetchEndpoint[..<fetchEndpoint.index(after: lastSlash)]
        return prefix + "ack"
    }

    private func buildRequestBody(
        config: PaylisherEngageInAppConfig,
        sdkKey: String,
        distinctId: String,
        target: String?
    ) -> [String: Any] {
        var body: [String: Any] = [
            "distinctId": distinctId,
            "sdkKey": sdkKey,
            "platform": "ios",
            "maxMessages": max(1, min(config.maxMessages, 5)),
        ]

        if let teamId = config.teamId, !teamId.isEmpty { body["teamId"] = teamId }
        if let projectId = config.projectId, !projectId.isEmpty { body["projectId"] = projectId }
        if let sourceId = config.sourceId, !sourceId.isEmpty { body["sourceId"] = sourceId }
        if let target, !target.isEmpty { body["target"] = target }

        return body
    }

    // MARK: - Response handling / de-dup / display gate

    private func handleResponseData(_ data: Data, debugLogging: Bool) {
        // Üç ayrı vaka bugün TEK bir sessiz `return`'e düşüyor: gövde JSON
        // değil, "messages" anahtarı yok, ya da liste BOŞ. Sonuncusu normaldir
        // (sunucu eleme yaptı — sebebi sunucu tarafındaki /__inapp izinde),
        // ilk ikisi ise sözleşme hatasıdır. Ayırt edilebilmeleri şart.
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let messages = root?["messages"] as? [[String: Any]]

        guard let messages, !messages.isEmpty else {
            PaylisherInAppDiagnostics.shared.record("parse.no_messages", [
                "isJsonObject": root != nil ? "true" : "false",
                "hasMessagesKey": messages != nil ? "true" : "false",
                "count": "\(messages?.count ?? 0)",
                "bodyHead": String(data: data.prefix(256), encoding: .utf8) ?? "",
            ])
            return
        }

        #if os(iOS) || os(tvOS)
        var queuedCount = 0
        queueLock.lock()
        for message in messages {
            // Android applies shouldDisplayMessage + shouldProcessNotification in the
            // fetch callback, before queueing.
            if !shouldDisplayMessage(message) {
                let condition = conditionDict(from: message)
                PaylisherInAppDiagnostics.shared.record("gate.display_window", [
                    "pushId": extractPushId(from: message) ?? "",
                    "displayTime": "\(longValue(condition?["displayTime"]) ?? 0)",
                    "expireDate": "\(longValue(condition?["expireDate"]) ?? 0)",
                    "nowMs": "\(Int64(Date().timeIntervalSince1970 * 1000))",
                ])
                continue
            }
            let key = buildInAppNotificationKey(message)
            if !shouldProcessNotification(key) {
                if debugLogging {
                    hedgeLog("[PaylisherSDK] Skipping duplicate Engage in-app message: \(key)")
                }
                PaylisherInAppDiagnostics.shared.record("gate.duplicate_dedupe", ["key": key])
                continue
            }
            pendingMessages.append(message)
            queuedCount += 1
        }
        queueLock.unlock()

        PaylisherInAppDiagnostics.shared.record("queue.enqueued", [
            "received": "\(messages.count)",
            "queued": "\(queuedCount)",
        ])

        renderPendingMessages(debugLogging: debugLogging)
        #endif
    }

    /// Mirrors Android shouldProcessNotification: 1-hour window, key recorded on first sight.
    private func shouldProcessNotification(_ key: String) -> Bool {
        processedLock.lock()
        defer { processedLock.unlock() }

        let nowSeconds = Date().timeIntervalSince1970
        processedNotifications = processedNotifications.filter { _, timestamp in
            timestamp + notificationTimeoutSeconds >= nowSeconds
        }

        if processedNotifications[key] != nil {
            return false
        }
        processedNotifications[key] = nowSeconds
        return true
    }

    /// Mirrors Android buildInAppNotificationKey: pushId (if present) else "inapp-<ms>".
    /// displayTime is intentionally NOT part of the key (server regenerates it per fetch).
    private func buildInAppNotificationKey(_ message: [String: Any]) -> String {
        if let pushId = extractPushId(from: message), !pushId.isEmpty {
            return pushId
        }
        return "inapp-\(Int(Date().timeIntervalSince1970 * 1000))"
    }

    /// Mirrors Android shouldDisplayMessage: displayTime (60s buffer) / expireDate gate.
    private func shouldDisplayMessage(_ message: [String: Any]) -> Bool {
        let condition = conditionDict(from: message)
        let nowMs = Date().timeIntervalSince1970 * 1000

        if let displayTime = longValue(condition?["displayTime"]) {
            if nowMs < Double(displayTime) - 60_000 {
                return false
            }
        }
        if let expireDate = longValue(condition?["expireDate"]) {
            if nowMs > Double(expireDate) {
                return false
            }
        }
        return true
    }

    /// Mirrors Android showInAppNotification initialDelay:
    /// max(condition.delay minutes, displayTime - now). Returned in seconds.
    private func initialDelaySeconds(for message: [String: Any]) -> TimeInterval {
        let condition = conditionDict(from: message)
        let nowMs = Date().timeIntervalSince1970 * 1000

        let delayMinutes = intValue(condition?["delay"]) ?? 0
        let conditionDelayMs = Double(delayMinutes) * 60_000

        var displayDelayMs: Double = 0
        if let displayTime = longValue(condition?["displayTime"]) {
            displayDelayMs = max(0, Double(displayTime) - nowMs)
        }

        return max(conditionDelayMs, displayDelayMs) / 1000.0
    }

    private func conditionDict(from message: [String: Any]) -> [String: Any]? {
        return (message["payload"] as? [String: Any])?["condition"] as? [String: Any]
    }

    private func longValue(_ value: Any?) -> Int64? {
        switch value {
        case let number as NSNumber: return number.int64Value
        case let string as String: return Int64(string)
        default: return nil
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue
        case let string as String: return Int(string)
        default: return nil
        }
    }

    private func extractPushId(from message: [String: Any]) -> String? {
        let raw = (message["payload"] as? [String: Any])?["pushId"] ?? message["pushId"]
        switch raw {
        case let value as String: return value
        case let value as NSNumber: return String(describing: value)
        default: return nil
        }
    }

    private func isExcludedScreen(currentTarget: String?, config: PaylisherEngageInAppConfig) -> Bool {
        guard let currentTarget, !currentTarget.isEmpty else {
            return false
        }
        for name in config.excludedActivities {
            if currentTarget.range(of: name, options: .caseInsensitive) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Render

    @objc private func handleAppForegroundForRender() {
        let debugLogging = PaylisherSDK.shared.config.engageInAppConfig?.debugLogging ?? false
        renderPendingMessages(debugLogging: debugLogging)
    }

    /// Screen-transition hook (called from UIViewController.viewDidAppear swizzle).
    /// Mirrors Android onFragmentStarted/onActivityResumed 1:1: first render any
    /// queued (not-yet-shown) message, THEN debounced-fetch new ones so a campaign
    /// published while the user browses appears without a background→foreground cycle.
    func onScreenAppeared() {
        let debugLogging = PaylisherSDK.shared.config.engageInAppConfig?.debugLogging ?? false
        renderPendingMessages(debugLogging: debugLogging)
        fetchEngageInAppMessagesOnScreenChange()
    }

    /// Debounced in-app fetch on screen change — Android
    /// fetchEngageInAppMessagesOnScreenChange 1:1. Gated on autoFetchOnForeground,
    /// 15s process-global debounce, deferred-not-dropped, target = nil (no server-side
    /// screen narrowing; untargeted/Everyone campaigns still arrive).
    private func fetchEngageInAppMessagesOnScreenChange() {
        let sdk = PaylisherSDK.shared
        guard let config = sdk.config.engageInAppConfig else { return }
        // Foreground otomatik fetch kapalıysa ekran değişiminde de fetch etme (Android ile aynı).
        guard config.autoFetchOnForeground else { return }

        let now = Date().timeIntervalSince1970
        let waitSeconds: TimeInterval
        screenChangeFetchLock.lock()
        let elapsed = now - lastScreenChangeFetchAt
        if elapsed < screenChangeFetchMinIntervalSeconds {
            // Debounce penceresi içindeyiz. İsteği DÜŞÜRMÜYORUZ: pencere dolunca bir kez
            // çalışacak şekilde erteliyoruz.
            if pendingScreenChangeFetch {
                screenChangeFetchLock.unlock()
                return
            }
            pendingScreenChangeFetch = true
            waitSeconds = screenChangeFetchMinIntervalSeconds - elapsed
        } else {
            lastScreenChangeFetchAt = now
            waitSeconds = 0
        }
        screenChangeFetchLock.unlock()

        if waitSeconds > 0 {
            if config.debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app fetch deferred \(Int(waitSeconds * 1000))ms (debounce)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + waitSeconds) { [weak self] in
                guard let self else { return }
                self.screenChangeFetchLock.lock()
                self.pendingScreenChangeFetch = false
                self.lastScreenChangeFetchAt = Date().timeIntervalSince1970
                self.screenChangeFetchLock.unlock()
                self.refresh(using: PaylisherSDK.shared, target: nil)
            }
            return
        }

        refresh(using: sdk, target: nil)
    }

    private func renderPendingMessages(debugLogging: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            #if os(iOS) || os(tvOS)
            guard let config = PaylisherSDK.shared.config.engageInAppConfig else {
                PaylisherInAppDiagnostics.shared.record("render.no_config")
                return
            }

            guard let scene = self.activeWindowScene() else {
                // BAŞ ŞÜPHELİ. Kuyruk boşaltmanın ÖN KOŞULU `foregroundActive`
                // bir UIWindowScene. UIScene manifesti olmayan (klasik
                // AppDelegate yaşam döngüsü) bir uygulamada `connectedScenes`
                // boş kalabilir; o hâlde in-app HİÇBİR ZAMAN render edilmez ve
                // bugün bu durumdan geriye tek bir iz kalmaz.
                PaylisherInAppDiagnostics.shared.record("render.no_foreground_scene", [
                    "connectedScenes": "\(UIApplication.shared.connectedScenes.count)",
                    "pending": "\(self.pendingCount())",
                ])
                return
            }

            let target = self.currentScreenTarget()
            if self.isExcludedScreen(currentTarget: target, config: config) {
                PaylisherInAppDiagnostics.shared.record("render.excluded_screen", [
                    "screen": target ?? "",
                    "excludedActivities": config.excludedActivities.joined(separator: ","),
                    "pending": "\(self.pendingCount())",
                ])
                return
            }

            self.queueLock.lock()
            let drained = self.pendingMessages
            self.pendingMessages.removeAll()
            self.queueLock.unlock()

            if drained.isEmpty {
                return
            }

            let distinctId = PaylisherSDK.shared.getDistinctId()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for message in drained {
                // Android acks DELIVERED right after enqueue (before the delayed
                // render fires), so we ack here too. acknowledge() no-ops for a
                // non-numeric pushId, mirroring Android's toIntOrNull guard.
                if let pushId = self.extractPushId(from: message), !distinctId.isEmpty {
                    self.acknowledge(distinctId: distinctId, pushId: pushId, status: .delivered)
                }

                let delay = self.initialDelaySeconds(for: message)
                if delay <= 0 {
                    self.presentMessage(message, windowScene: scene, debugLogging: debugLogging)
                } else {
                    // Mirrors Android InAppTaskWorker.setInitialDelay: present after the
                    // delay using whatever scene is foreground at fire time.
                    PaylisherInAppDiagnostics.shared.record("render.delayed", [
                        "pushId": self.extractPushId(from: message) ?? "",
                        "delaySeconds": "\(Int(delay))",
                    ])
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard let self else { return }
                        guard let laterScene = self.activeWindowScene() else {
                            // Mesaj DELIVERED olarak ack'lendi ama gecikme
                            // dolduğunda uygulama önplanda değildi: sunucu
                            // "teslim edildi" sanır, kullanıcı hiçbir şey görmez.
                            PaylisherInAppDiagnostics.shared.record("render.delayed_no_scene", [
                                "pushId": self.extractPushId(from: message) ?? "",
                            ])
                            return
                        }
                        self.presentMessage(message, windowScene: laterScene, debugLogging: debugLogging)
                    }
                }
            }
            #endif
        }
    }

    #if os(iOS) || os(tvOS)
    private func activeWindowScene() -> UIWindowScene? {
        return UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
    }

    private func currentScreenTarget() -> String? {
        guard
            let rootViewController = activeWindowScene()?
                .windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        else {
            return nil
        }

        return topViewController(from: rootViewController)
            .map { String(describing: type(of: $0)) }
    }

    private func topViewController(from viewController: UIViewController) -> UIViewController? {
        if let presented = viewController.presentedViewController {
            return topViewController(from: presented)
        }

        if let navigation = viewController as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }

        if let tabBar = viewController as? UITabBarController,
           let selected = tabBar.selectedViewController {
            return topViewController(from: selected)
        }

        return viewController
    }

    private func presentMessage(
        _ message: [String: Any],
        windowScene: UIWindowScene?,
        debugLogging: Bool
    ) {
        guard let payload = message["payload"] as? [String: Any] else {
            PaylisherInAppDiagnostics.shared.record("present.no_payload_dict", [
                "keys": message.keys.sorted().joined(separator: ","),
            ])
            return
        }

        let layoutType = (payload["layoutType"] as? String) ?? "native"

        // layoutType hem sunucuda hem burada "native"e düşüyor. Sunucu tanımadığı
        // bir tipi native'e çeviriyor, native bloğu boşsa native yöneticisi de
        // sessizce dönüyor — iki ayrı varsayılan üst üste binince mesaj kayboluyor.
        PaylisherInAppDiagnostics.shared.record("present.layout_type", [
            "pushId": extractPushId(from: message) ?? "",
            "layoutType": layoutType,
            "layoutTypeExplicit": payload["layoutType"] is String ? "true" : "false",
            "hasNative": payload["native"] != nil ? "true" : "false",
            "layoutCount": "\((payload["layouts"] as? [Any])?.count ?? 0)",
        ])

        if layoutType == "native" {
            var userInfo = payload
            userInfo["type"] = "IN-APP"

            if let nativePayload = payload["native"] {
                userInfo["native"] = jsonString(from: nativePayload) ?? ""
            }

            if let conditionPayload = payload["condition"] {
                userInfo["condition"] = jsonString(from: conditionPayload) ?? ""
            }

            PaylisherNativeInAppNotificationManager.shared.nativeInAppNotification(
                userInfo: userInfo,
                windowScene: windowScene
            )
            PaylisherInAppDiagnostics.shared.record("present.handoff_native", [
                "pushId": extractPushId(from: message) ?? "",
                "nativeEmpty": (payload["native"] as? [String: Any])?.isEmpty ?? true
                    ? "true" : "false",
            ])
            return
        }

        do {
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            let decodedPayload = try JSONDecoder().decode(CustomInAppPayload.self, from: payloadData)
            PaylisherCustomInAppNotificationManager.shared.showCustomInApp(
                decodedPayload,
                windowScene: windowScene
            )
            PaylisherInAppDiagnostics.shared.record("present.handoff_custom", [
                "pushId": extractPushId(from: message) ?? "",
                "layoutType": layoutType,
            ])
        } catch {
            if debugLogging {
                hedgeLog("[PaylisherSDK] Engage in-app payload decode failed: \(error)")
            }
            // SDK'daki EN DEĞERLİ tek teşhis verisi ve bugün çöpe gidiyor:
            // DecodingError tam kodlama yolunu söyler
            // (ör. layouts[0].blocks.order[2].type). API-pull yolunda sunucu
            // sayıları/boolean'ları string'e ÇEVİRMEDİĞİ için (FCM yolunda
            // çeviriyor) bu hata iOS'a özgüdür.
            PaylisherInAppDiagnostics.shared.record("present.decode_failed", [
                "pushId": extractPushId(from: message) ?? "",
                "layoutType": layoutType,
                "error": String(describing: error),
            ])
        }
    }
    #endif

    private func pendingCount() -> Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return pendingMessages.count
    }

    private func jsonString(from value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value) else {
            return nil
        }

        guard let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
