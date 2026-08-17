import Foundation

#if os(iOS) || os(tvOS)
import UIKit

/// Host uygulamaya iş düşmeden FCM in-app'i yakalayan AppDelegate kancası.
///
/// SORUN: Engage in-app'i sessiz (background) push olarak gönderiyor —
/// `content-available: 1`, `alert` YOK. iOS böyle bir mesajı yalnızca
/// `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`
/// çağrısına teslim eder; Notification Service Extension background push'ta
/// HİÇ çalışmaz. SDK'nın bu callback'e kendi kancası olmadığı için, bugüne
/// kadar in-app'in iOS'ta görünmesi host uygulamanın o metodu yazıp
/// `customInAppFunction`'ı elle çağırmasına bağlıydı. Android'de böyle bir
/// gereklilik yok (SDK `onMessageReceived`'ı kendisi sahipleniyor), dolayısıyla
/// aynı kampanya Android'de çıkıp iOS'ta çıkmıyordu.
///
/// ÇÖZÜM: kurulum sırasında host'un delegate SINIFINI çalışma zamanında
/// kancalıyoruz — Firebase, OneSignal ve Braze'in yaptığı desenin aynısı.
/// Metot yoksa ekliyoruz, varsa sarıp ÖNCEKİ implementasyonu her hâlükârda
/// çağırıyoruz; zincir kırılmadığı için host'un (ve Firebase'in) kendi
/// işleyişi aynen sürüyor.
///
/// YAPAMADIĞIMIZ tek şey: **Background Modes → Remote notifications** yetkisi.
/// O build-time bir entitlement, ancak uygulamanın kendi projesinde açılır;
/// kapalıysa iOS bu callback'i hiç çağırmaz ve kanca da devreye giremez.
@objc public final class PaylisherRemoteNotificationProxy: NSObject {
    private static let lock = NSLock()
    private static var installed = false

    /// Aynı mesajın iki ayrı selector'dan gelip iki kez çizilmesini engeller.
    private static var recentlyHandled: [String: TimeInterval] = [:]
    private static let handledWindowSeconds: TimeInterval = 15

    // MARK: - Kurulum

    @objc public static func installIfNeeded() {
        lock.lock()
        if installed {
            lock.unlock()
            return
        }
        installed = true
        lock.unlock()

        // Delegate, uygulama didFinishLaunching'e girdiğinde atanmış olur.
        // setup() daha erken çağrılmış olabileceği için ana kuyruğa erteliyoruz.
        DispatchQueue.main.async {
            guard let delegate = UIApplication.shared.delegate else {
                PaylisherInAppDiagnostics.shared.record("proxy.no_app_delegate")
                return
            }
            guard let delegateClass = object_getClass(delegate) else { return }

            let modern = hookFetchHandlerVariant(on: delegateClass)
            let legacy = hookLegacyVariant(on: delegateClass)

            PaylisherInAppDiagnostics.shared.record("proxy.installed", [
                "delegateClass": String(describing: delegateClass),
                "fetchHandlerVariant": modern,
                "legacyVariant": legacy,
            ])
        }
    }

    /// `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`
    /// Sessiz push'un iOS'taki ASIL teslim noktası.
    ///
    /// Selector'ı `#selector` yerine string'den üretiyoruz: `UIApplicationDelegate`
    /// üzerinde çok sayıda `application(_:...)` aşırı yüklemesi var ve derleyici
    /// tarafında belirsizliğe açık; imza zaten Apple tarafından sabit.
    private static func hookFetchHandlerVariant(on cls: AnyClass) -> String {
        let selector = NSSelectorFromString(
            "application:didReceiveRemoteNotification:fetchCompletionHandler:"
        )

        typealias Original = @convention(c) (
            AnyObject, Selector, UIApplication, [AnyHashable: Any],
            @escaping (UIBackgroundFetchResult) -> Void
        ) -> Void

        // ÖNCE yakala: metot miras alınmışsa bu üst sınıfın implementasyonudur
        // ve zinciri ona bağlamamız gerekir.
        let hadImplementation = class_respondsToSelector(cls, selector)
        let originalImp: IMP? = hadImplementation
            ? class_getMethodImplementation(cls, selector)
            : nil

        let block: @convention(block) (
            AnyObject, UIApplication, [AnyHashable: Any],
            @escaping (UIBackgroundFetchResult) -> Void
        ) -> Void = { receiver, application, userInfo, completion in
            handleIfPaylisherInApp(userInfo)
            if let originalImp {
                let original = unsafeBitCast(originalImp, to: Original.self)
                original(receiver, selector, application, userInfo, completion)
            } else {
                // Metodu biz ekledik: completion'ı çağırmak BİZE düşüyor,
                // yoksa iOS uygulamayı "cevap vermedi" diye cezalandırır.
                completion(.noData)
            }
        }

        return install(block: block, on: cls, selector: selector, types: "v@:@@@")
    }

    /// `application(_:didReceiveRemoteNotification:)` — iOS 10'da deprecate
    /// edildi ama hâlâ çağrılabiliyor. Ek kapsama için kancalıyoruz; tek başına
    /// garanti DEĞİL.
    private static func hookLegacyVariant(on cls: AnyClass) -> String {
        let selector = NSSelectorFromString("application:didReceiveRemoteNotification:")

        typealias Original = @convention(c) (
            AnyObject, Selector, UIApplication, [AnyHashable: Any]
        ) -> Void

        let hadImplementation = class_respondsToSelector(cls, selector)
        let originalImp: IMP? = hadImplementation
            ? class_getMethodImplementation(cls, selector)
            : nil

        let block: @convention(block) (
            AnyObject, UIApplication, [AnyHashable: Any]
        ) -> Void = { receiver, application, userInfo in
            handleIfPaylisherInApp(userInfo)
            if let originalImp {
                let original = unsafeBitCast(originalImp, to: Original.self)
                original(receiver, selector, application, userInfo)
            }
        }

        return install(block: block, on: cls, selector: selector, types: "v@:@@")
    }

    /// Kancayı sınıfa yerleştirir.
    ///
    /// Önce `class_addMethod` deneniyor. Bu bilinçli bir sıra:
    /// - metot hiç yoksa → eklenir,
    /// - metot ÜST SINIFTAN miras alınmışsa → bu sınıfa override olarak eklenir
    ///   (doğrudan `method_setImplementation` çağırsaydık ÜST SINIFI değiştirmiş
    ///   olurduk ve aynı tabandan türeyen her sınıf etkilenirdi),
    /// - metot doğrudan bu sınıfta tanımlıysa → `addMethod` false döner ve
    ///   yalnız o zaman implementasyonu takas ederiz.
    private static func install(
        block: Any,
        on cls: AnyClass,
        selector: Selector,
        types: String
    ) -> String {
        let imp = imp_implementationWithBlock(block)

        if class_addMethod(cls, selector, imp, types) {
            return "added"
        }
        guard let method = class_getInstanceMethod(cls, selector) else {
            return "failed"
        }
        method_setImplementation(method, imp)
        return "wrapped"
    }

    // MARK: - İşleme

    /// Yalnız Paylisher kaynaklı IN-APP mesajlarına dokunur. Başka her şey
    /// (kendi push'umuz dâhil) olduğu gibi zincirdeki bir sonrakine bırakılır.
    private static func handleIfPaylisherInApp(_ userInfo: [AnyHashable: Any]) {
        guard PaylisherSDK.shared.config.autoHandleRemoteNotifications else { return }
        guard let source = userInfo["source"] as? String, source == "Paylisher" else { return }
        guard let type = userInfo["type"] as? String, type == "IN-APP" else { return }

        let pushId = (userInfo["pushId"] as? String) ?? "?"

        guard claimHandled(userInfo) else {
            PaylisherInAppDiagnostics.shared.record("proxy.duplicate_skipped", [
                "pushId": pushId,
            ])
            return
        }

        PaylisherInAppDiagnostics.shared.record("proxy.inapp_received", [
            "pushId": pushId,
            "layoutType": (userInfo["layoutType"] as? String) ?? "?",
        ])

        // `notificationReceived` — sunucu tarafı teşhisin cihaz ayağı bu olaya
        // dayanıyor (/__inapp/device). Dedupe, host da aynı push'u işlerse
        // olayın iki kez gitmesini engeller.
        if PaylisherNotificationDedupe.tryClaimReceived(userInfo: userInfo) {
            PaylisherNotificationEventTracker.capture(
                "notificationReceived",
                userInfo: userInfo,
                properties: ["type": "IN-APP"]
            )
        }

        DispatchQueue.main.async {
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene

            if scene == nil {
                // Uygulama önplanda değil: in-app çizilemez. Sessizce
                // kaybolmasın diye kaydediyoruz.
                PaylisherInAppDiagnostics.shared.record("proxy.no_foreground_scene", [
                    "pushId": pushId,
                ])
                return
            }

            // NotificationManager'ın IN-APP dalıyla aynı sıra: native blok
            // varsa native yönetici, layout varsa custom yönetici çizer.
            PaylisherNativeInAppNotificationManager.shared.nativeInAppNotification(
                userInfo: userInfo,
                windowScene: scene
            )
            PaylisherCustomInAppNotificationManager.shared.customInAppFunction(
                userInfo: userInfo,
                windowScene: scene
            )
            PaylisherInAppDiagnostics.shared.record("proxy.rendered", ["pushId": pushId])
        }
    }

    /// Aynı mesaj iki selector'dan da gelirse yalnız ilki işlensin.
    private static func claimHandled(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let key = PaylisherNotificationDedupe.messageKey(from: userInfo) else {
            return true
        }

        lock.lock()
        defer { lock.unlock() }

        let now = Date().timeIntervalSince1970
        recentlyHandled = recentlyHandled.filter { $0.value + handledWindowSeconds >= now }
        if recentlyHandled[key] != nil {
            return false
        }
        recentlyHandled[key] = now
        return true
    }
}
#endif
