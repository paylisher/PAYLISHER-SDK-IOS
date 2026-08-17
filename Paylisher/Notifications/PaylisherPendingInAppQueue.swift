import Foundation

#if os(iOS) || os(tvOS)
import UIKit

/// Önplan beklerken in-app'i saklayan kuyruk.
///
/// SORUN: in-app ancak uygulama önplandayken çizilebiliyor — sunum için
/// `foregroundActive` bir pencere şart. Sessiz push ise uygulama arka plandayken
/// de teslim ediliyor. Bugüne kadar bu durumda mesaj sessizce DÜŞÜYORDU:
/// kullanıcı hiçbir şey görmüyordu ve mesaj bir daha hiç denenmiyordu.
///
/// ÇÖZÜM: çizilemeyen mesajı diske al, uygulama bir sonraki kez öne geldiğinde
/// göster. Diske almak önemli: arka planda uyandırılan uygulama iş bitince
/// tekrar sonlandırılır, bellekteki kuyruk o anda kaybolurdu.
///
/// Kampanyanın bitiş zamanı geçmişse gösterilmez — bayat mesaj göstermek
/// göstermemekten kötüdür.
final class PaylisherPendingInAppQueue {
    static let shared = PaylisherPendingInAppQueue()

    private let storageKey = "com.paylisher.ios.inapp.pending"
    private let maxEntries = 10
    /// Aynı mesaj önplan bekleyip yine çizilemezse sonsuza kadar denenmesin.
    private let maxAttempts = 5

    private let lock = NSLock()
    private var observerToken: NSObjectProtocol?

    private struct Entry: Codable {
        /// "custom" = layout tabanlı (banner/modal/fullscreen/carousel)
        /// "native" = native kart
        let kind: String
        /// custom: CustomInAppPayload JSON'u. native: ham userInfo JSON'u.
        let payloadJSON: String
        /// Kampanyanın bitişi (epoch saniye). 0 = bitiş yok.
        let expiresAt: TimeInterval
        var attempts: Int
    }

    private init() {
        observerToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.drain()
        }
    }

    deinit {
        if let observerToken {
            NotificationCenter.default.removeObserver(observerToken)
        }
    }

    // MARK: - Kuyruğa alma

    func enqueueCustom(_ payload: CustomInAppPayload) {
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        let expiresAt: TimeInterval = {
            guard let ms = payload.condition?.expireDate, ms > 0 else { return 0 }
            return TimeInterval(ms) / 1000.0
        }()

        append(Entry(kind: "custom", payloadJSON: json, expiresAt: expiresAt, attempts: 0))
        PaylisherInAppDiagnostics.shared.record("pending.queued", [
            "kind": "custom",
            "pushId": payload.pushId ?? "?",
        ])
    }

    func enqueueNative(userInfo: [AnyHashable: Any]) {
        // userInfo push gövdesinden geliyor, yani JSON kökenli; yine de
        // serileştirilebilirliğini doğrulamadan diske yazmıyoruz.
        var plain: [String: Any] = [:]
        for (key, value) in userInfo {
            if let key = key as? String { plain[key] = value }
        }
        guard JSONSerialization.isValidJSONObject(plain),
              let data = try? JSONSerialization.data(withJSONObject: plain),
              let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        append(Entry(kind: "native", payloadJSON: json, expiresAt: 0, attempts: 0))
        PaylisherInAppDiagnostics.shared.record("pending.queued", [
            "kind": "native",
            "pushId": (plain["pushId"] as? String) ?? "?",
        ])
    }

    // MARK: - Boşaltma

    /// Uygulama öne geldiğinde çağrılır. Sunum akışının kendi tekrar koruması
    /// olduğu için burada yalnız sıraya sokuyoruz.
    func drain() {
        let entries = takeAll()
        guard !entries.isEmpty else { return }

        let now = Date().timeIntervalSince1970
        PaylisherInAppDiagnostics.shared.record("pending.draining", [
            "count": "\(entries.count)",
        ])

        for var entry in entries {
            if entry.expiresAt > 0, entry.expiresAt <= now {
                PaylisherInAppDiagnostics.shared.record("pending.expired", [
                    "kind": entry.kind,
                ])
                continue
            }

            entry.attempts += 1
            if entry.attempts > maxAttempts {
                PaylisherInAppDiagnostics.shared.record("pending.gave_up", [
                    "kind": entry.kind,
                    "attempts": "\(entry.attempts)",
                ])
                continue
            }

            present(entry)
        }
    }

    private func present(_ entry: Entry) {
        guard let data = entry.payloadJSON.data(using: .utf8) else { return }

        let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene

        switch entry.kind {
        case "custom":
            guard let payload = try? JSONDecoder().decode(CustomInAppPayload.self, from: data) else {
                PaylisherInAppDiagnostics.shared.record("pending.decode_failed", ["kind": "custom"])
                return
            }
            PaylisherCustomInAppNotificationManager.shared.showCustomInApp(
                payload,
                windowScene: scene
            )
        case "native":
            guard let userInfo = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                PaylisherInAppDiagnostics.shared.record("pending.decode_failed", ["kind": "native"])
                return
            }
            PaylisherNativeInAppNotificationManager.shared.nativeInAppNotification(
                userInfo: userInfo,
                windowScene: scene
            )
        default:
            return
        }
    }

    // MARK: - Depolama

    private func append(_ entry: Entry) {
        lock.lock()
        defer { lock.unlock() }

        var entries = load()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        save(entries)
    }

    private func takeAll() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }

        let entries = load()
        save([])
        return entries
    }

    private func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else {
            return []
        }
        return entries
    }

    private func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
#endif
