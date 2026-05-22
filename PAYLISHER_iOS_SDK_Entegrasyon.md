# Paylisher iOS SDK — Entegrasyon Dökümanı

> **SDK Sürümü:** 1.8.4
> **Minimum iOS:** 13.0 · **Xcode:** 15+ · **Swift:** 5.7 / 5.8 / 5.9
> **Desteklenen platformlar:** iOS, iPadOS, macOS (10.15+), tvOS (13+), watchOS (6+)

Bu döküman, Paylisher iOS SDK'nın bir uygulamaya sıfırdan entegre edilmesi için gereken tüm adımları içerir: kurulum, başlatma, olay takibi, kullanıcı tanımlama, push notification, in-app mesajlar, deep link ve uninstall (kaldırma) tespiti.

---

## İçindekiler

1. [Genel Bakış](#1-genel-bakış)
2. [Gereksinimler](#2-gereksinimler)
3. [Kurulum](#3-kurulum)
4. [Hızlı Başlangıç](#4-hızlı-başlangıç)
5. [SDK Yapılandırması (PaylisherConfig)](#5-sdk-yapılandırması-paylisherconfig)
6. [Kullanıcı Yönetimi](#6-kullanıcı-yönetimi)
7. [Olay (Event) Takibi](#7-olay-event-takibi)
8. [Push Notification Entegrasyonu](#8-push-notification-entegrasyonu)
9. [In-App Mesajlar](#9-in-app-mesajlar)
10. [Deep Link Entegrasyonu](#10-deep-link-entegrasyonu)
11. [Uninstall Tespiti (Heartbeat)](#11-uninstall-tespiti-heartbeat)
12. [Session Replay](#12-session-replay)
13. [Feature Flag'ler](#13-feature-flagler)
14. [API Hızlı Referans](#14-api-hızlı-referans)
15. [Sık Karşılaşılan Sorunlar](#15-sık-karşılaşılan-sorunlar)

---

## 1. Genel Bakış

Paylisher iOS SDK; analytics, etkileşim ve yeniden hedefleme ihtiyaçlarını tek bir kütüphanede toplar:

| Özellik | Açıklama |
|---------|----------|
| **Olay Takibi** | Özel olaylar, ekran görüntülemeleri, otomatik uygulama yaşam döngüsü olayları |
| **Kullanıcı Tanımlama** | `identify`, `alias`, `group`, kişi/grup özellikleri |
| **Push Notification** | FCM üzerinden zengin push, aksiyon bazlı bildirim, görsel ekleme |
| **In-App Mesajlar** | Modal, banner, fullscreen, carousel ve native in-app gösterimleri |
| **Deep Link** | Doğrudan, universal link ve **deferred deep link** (kurulum atıfı) |
| **Geofence** | Konum tabanlı bildirim tetikleme |
| **Uninstall Tespiti** | Sessiz push (heartbeat) ile uygulama kaldırma tespiti |
| **Session Replay** | Kullanıcı oturumu kaydı (deneysel) |
| **Feature Flag** | Sunucu taraflı özellik bayrakları ve A/B varyantları |

> **Mimari not:** SDK, Firebase'i kendi içinde **paketlemez**. Push için Firebase Cloud Messaging entegrasyonu **host (ana) uygulamada** yapılır; alınan FCM token'ı SDK'ya `registerFCMToken(_:)` ile iletilir. Bu sayede uygulamanızda hâlihazırda kullandığınız Firebase sürümüyle çakışma yaşanmaz.

---

## 2. Gereksinimler

Entegrasyona başlamadan önce aşağıdakilerin hazır olması gerekir:

1. **Paylisher API anahtarı (`apiKey`)** ve **host URL'i** — Paylisher ekibi tarafından sağlanır.
   - Örn. host: `https://ds-tr.paylisher.com` (kuruluma özel; bölgenize göre değişir).
2. **Apple Developer hesabı** — Push Notification sertifikası / APNs Auth Key (.p8).
3. **Firebase projesi** — Push ve in-app mesajlar FCM üzerinden geldiği için zorunludur.
   - `GoogleService-Info.plist` dosyası
   - APNs Auth Key'in Firebase Console'a yüklenmiş olması
4. **App Group** — Push & in-app verilerinin saklanması ve tekilleştirilmesi (dedupe) için **zorunludur**.
   - Örn. `group.com.sirketiniz.uygulama`
5. Uygulamada açık olması gereken **Capabilities**:
   - Push Notifications
   - Background Modes → *Remote notifications*
   - App Groups

---

## 3. Kurulum

### 3.1 Swift Package Manager (önerilen)

Xcode'da **File → Add Package Dependencies** menüsünden aşağıdaki URL'i ekleyin:

```
https://github.com/paylisher/PAYLISHER-SDK-IOS.git
```

Sürüm kuralı olarak **"Up to Next Major"** → `1.8.4` seçin.

Veya `Package.swift` ile:

```swift
dependencies: [
    .package(url: "https://github.com/paylisher/PAYLISHER-SDK-IOS.git", from: "1.8.4")
],
targets: [
    .target(
        name: "UygulamanizinTarget",
        dependencies: [
            .product(name: "Paylisher", package: "PAYLISHER-SDK-IOS")
        ]
    )
]
```

### 3.2 CocoaPods

`Podfile` içine ekleyin:

```ruby
platform :ios, '13.0'

target 'UygulamanizinTarget' do
  use_frameworks!

  pod 'Paylisher', '~> 1.8.4'
end
```

Ardından:

```bash
pod install
```

### 3.3 Firebase'in Eklenmesi (Push için zorunlu)

Push ve in-app mesajlar FCM ile geldiği için **host uygulamanıza Firebase Messaging eklenmelidir**.

**SPM ile:**
```
https://github.com/firebase/firebase-ios-sdk.git
```
Eklenecek ürünler: `FirebaseCore`, `FirebaseMessaging`.

**CocoaPods ile:**
```ruby
pod 'FirebaseCore'
pod 'FirebaseMessaging'
```

`GoogleService-Info.plist` dosyasını proje hedefine (target) ekleyin.

---

## 4. Hızlı Başlangıç

En küçük çalışan kurulum (yalnızca analytics):

```swift
import Paylisher

let config = PaylisherConfig(
    apiKey: "phc_XXXXXXXXXXXXXXXXXXXX",
    host: "https://ds-tr.paylisher.com"
)
PaylisherSDK.shared.setup(config)

// Bir olay gönder
PaylisherSDK.shared.capture("uygulama_acildi")
```

> `setup(_:)` yalnızca **bir kez** çağrılmalıdır (genellikle `application(_:didFinishLaunchingWithOptions:)` içinde). Tekrar çağrılırsa SDK uyarı verir ve ikinciyi yok sayar.

Push, in-app ve diğer özellikler için 8. bölümden itibaren ilerleyin.

---

## 5. SDK Yapılandırması (PaylisherConfig)

`PaylisherConfig` üzerinden tüm davranışı özelleştirebilirsiniz:

```swift
let config = PaylisherConfig(apiKey: apiKey, host: host)

// Olay gönderimi
config.flushAt = 20                 // Kaç olayda bir sunucuya gönderilsin (varsayılan 20)
config.flushIntervalSeconds = 30    // Periyodik gönderim aralığı (sn)
config.maxQueueSize = 1000          // Yerel kuyruktaki maksimum olay
config.maxBatchSize = 50            // Tek istekteki maksimum olay
config.dataMode = .any              // .wifi / .cellular / .any

// Otomatik takip
config.captureScreenViews = true                 // UIViewController ekran takibi (varsayılan açık)
config.captureApplicationLifecycleEvents = true  // Installed/Updated/Opened/Backgrounded

// Kişi profili & tanımlama
config.personProfiles = .identifiedOnly          // .never / .identifiedOnly / .always
config.repeatedIdentifyBehavior = .ignore        // .ignore / .capture

// Feature flag
config.preloadFeatureFlags = true                // Başlangıçta flag'leri yükle
config.sendFeatureFlagEvent = true               // Flag çağrıldığında olay gönder

// Gizlilik
config.optOut = false                            // true ise hiçbir olay gönderilmez

// App Group (push/in-app verisi paylaşımı için)
config.appGroupIdentifier = "group.com.sirketiniz.uygulama"

// Uninstall tespiti (heartbeat) — varsayılan açık
config.enableHeartbeat = true

PaylisherSDK.shared.setup(config)
```

### Yapılandırma Referansı

| Alan | Tip | Varsayılan | Açıklama |
|------|-----|-----------|----------|
| `apiKey` | `String` | — | Proje API anahtarı (zorunlu) |
| `host` | `String` | `https://us.i.paylisher.com` | Sunucu adresi (self-hosted için kuruluma özel) |
| `flushAt` | `Int` | `20` | Gönderim eşiği (olay sayısı) |
| `flushIntervalSeconds` | `TimeInterval` | `30` | Periyodik gönderim aralığı |
| `maxQueueSize` | `Int` | `1000` | Yerel kuyruk üst sınırı |
| `maxBatchSize` | `Int` | `50` | Tek batch'teki maksimum olay |
| `dataMode` | `enum` | `.any` | Hangi bağlantıda gönderilsin |
| `captureScreenViews` | `Bool` | `true` | Otomatik ekran takibi (UIKit) |
| `captureApplicationLifecycleEvents` | `Bool` | `true` | Yaşam döngüsü olayları |
| `personProfiles` | `enum` | `.identifiedOnly` | Kişi profili işleme stratejisi |
| `repeatedIdentifyBehavior` | `enum` | `.ignore` | Aynı kullanıcıyla tekrar identify davranışı |
| `preloadFeatureFlags` | `Bool` | `true` | Başlangıçta flag yükleme |
| `sendFeatureFlagEvent` | `Bool` | `true` | Flag kullanım olayı |
| `optOut` | `Bool` | `false` | Tüm takibi durdur |
| `appGroupIdentifier` | `String?` | `nil` | App Group kimliği |
| `enableHeartbeat` | `Bool` | `true` | Sessiz push ile uninstall tespiti |
| `sessionReplay` | `Bool` | `false` | Oturum kaydı (yalnızca iOS) |
| `deferredDeepLinkConfig` | nesne | `nil` | Deferred deep link ayarı |
| `engageInAppConfig` | nesne | `nil` | Engage in-app çekme ayarı |

---

## 6. Kullanıcı Yönetimi

### identify — Kullanıcıyı tanımla

Kullanıcı giriş yaptığında çağrılır. Anonim kullanıcı kimliği, verilen `distinctId` ile birleştirilir.

```swift
PaylisherSDK.shared.identify(
    "musteri_12345",
    userProperties: [
        "email": "kullanici@ornek.com",
        "ad": "Ayşe Yılmaz",
        "platform": "ios"
    ]
)
```

### alias — Takma ad oluştur

```swift
PaylisherSDK.shared.alias("yeni_kimlik")
```

### group — Grup tanımla

```swift
PaylisherSDK.shared.group(
    type: "sirket",
    key: "sirket_42",
    groupProperties: ["isim": "Örnek A.Ş."]
)
```

### register / unregister — Kalıcı (super) özellikler

Buraya eklenen özellikler **sonraki tüm olaylara** otomatik eklenir.

```swift
PaylisherSDK.shared.register(["deviceID": cihazKimligi, "platform": "ios"])
PaylisherSDK.shared.unregister("deviceID")
```

> **Önemli:** `reset()` çağrıldığında super property'ler de silinir. Çıkış (logout) sonrası `deviceID` / `token` gibi değerleri yeniden `register` etmeniz gerekir.

### reset — Çıkışta sıfırla

Kullanıcı çıkış yaptığında çağrılır; kimlik, oturum ve önbellek temizlenir.

```swift
PaylisherSDK.shared.reset()
// Çıkış sonrası cihaza özgü kalıcı değerleri tekrar ekleyin:
PaylisherSDK.shared.register(["deviceID": cihazKimligi, "platform": "ios"])
```

### Kimlik bilgilerini okuma

```swift
let distinctId = PaylisherSDK.shared.getDistinctId()
let anonymousId = PaylisherSDK.shared.getAnonymousId()
let sessionId = PaylisherSDK.shared.getSessionId()
```

---

## 7. Olay (Event) Takibi

### Özel olay gönderme

```swift
PaylisherSDK.shared.capture("urun_tiklandi", properties: [
    "urun_id": "abc123",
    "fiyat": 99.9,
    "kategori": "ayakkabi"
])
```

### Ekran görüntüleme

```swift
PaylisherSDK.shared.screen("Ana Sayfa", properties: ["kaynak": "menu"])
```

> `captureScreenViews = true` iken UIKit ekranları otomatik takip edilir. SwiftUI'da ekran olaylarını manuel `screen(...)` ile göndermeniz önerilir.

### Otomatik gönderilen olaylar

`captureApplicationLifecycleEvents = true` iken SDK şu olayları otomatik üretir:

- `Application Installed`
- `Application Updated`
- `Application Opened`
- `Application Backgrounded`

### Anında gönderim

```swift
PaylisherSDK.shared.flush()   // Bekleyen tüm olayları hemen gönder
```

---

## 8. Push Notification Entegrasyonu

Push akışı şu parçalardan oluşur:
1. Xcode capability'leri ve App Group
2. Firebase/FCM kurulumu ve token kaydı
3. `AppDelegate` bildirim delege'leri
4. (Opsiyonel) Zengin push için Notification Service Extension

### 8.1 Xcode Capability'leri

Hedef (target) → **Signing & Capabilities**:
- **Push Notifications** ekleyin.
- **Background Modes** → *Remote notifications* işaretleyin.
- **App Groups** ekleyin ve bir grup tanımlayın: `group.com.sirketiniz.uygulama`.

### 8.2 App Group + CoreData Yapılandırması

Push & in-app verilerinin saklanması ve tekrar gösterimin engellenmesi (dedupe) için App Group **zorunludur**. `setup` sonrası bir kez çağırın:

```swift
CoreDataManager.shared.configure(appGroupIdentifier: "group.com.sirketiniz.uygulama")
```

> ⚠️ App Group kimliği yanlış/tanımsızsa SDK çalışma zamanında hata verir. Capability'de tanımladığınız değerle birebir aynı olmalıdır.

### 8.3 Tam AppDelegate Örneği

Aşağıdaki `AppDelegate`, push + in-app + uninstall tespiti içeren **eksiksiz** bir kurulumdur:

```swift
import UIKit
import Paylisher
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate,
                   UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                        [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // 1) Firebase
        FirebaseApp.configure()

        // 2) Paylisher SDK
        let config = PaylisherConfig(
            apiKey: "phc_XXXXXXXXXXXXXXXXXXXX",
            host: "https://ds-tr.paylisher.com"
        )
        config.captureScreenViews = true
        config.captureApplicationLifecycleEvents = true
        config.appGroupIdentifier = "group.com.sirketiniz.uygulama"
        PaylisherSDK.shared.setup(config)

        // 3) App Group / CoreData
        CoreDataManager.shared.configure(appGroupIdentifier: "group.com.sirketiniz.uygulama")

        // 4) Soğuk başlangıçta push'a tıklanarak açıldıysa olayı yakala
        NotificationManager.shared.handleLaunchOptions(launchOptions)

        // 5) Bildirim delege'leri
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    // MARK: - APNs token → Firebase
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - FCM token → Paylisher
    func messaging(_ messaging: Messaging,
                   didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty else { return }
        // Uninstall tespiti / hedefleme için token'ı SDK'ya bildir
        PaylisherSDK.shared.registerFCMToken(token)
        // (Opsiyonel) super property olarak da tutabilirsiniz
        PaylisherSDK.shared.register(["token": token, "platform": "ios"])
    }

    // MARK: - Uygulama önplandayken gelen push
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo

        // Paylisher mesajı mı?
        if (userInfo["source"] as? String) == "Paylisher" {
            let type = userInfo["type"] as? String ?? ""

            // In-app mesajı önplanda modal/banner olarak göster
            if type == "IN-APP" {
                let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                let content = notification.request.content.mutableCopy() as! UNMutableNotificationContent
                NotificationManager.shared.customNotification(
                    windowScene: scene,
                    userInfo: userInfo,
                    content,
                    notification.request
                ) { _ in }
                completionHandler([])   // Sistem banner'ını bastır, in-app gösterilecek
                return
            }

            // Diğer Paylisher push'ları: sistem banner'ı + olay takibi
            NotificationManager.shared.handleForegroundPresentation(notification)
        }

        completionHandler([.banner, .list, .sound, .badge])
    }

    // MARK: - Arka plan / sessiz push
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler:
                        @escaping (UIBackgroundFetchResult) -> Void) {

        // 1) Sessiz heartbeat ise SDK işler ve true döner
        if PaylisherSDK.shared.handleSilentPush(userInfo, completionHandler: completionHandler) {
            return
        }

        // 2) Arka planda gelen in-app mesajı
        if (userInfo["source"] as? String) == "Paylisher",
           (userInfo["type"] as? String) == "IN-APP" {
            DispatchQueue.main.async {
                let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                let content = UNMutableNotificationContent()
                content.userInfo = userInfo
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString, content: content, trigger: nil)
                NotificationManager.shared.customNotification(
                    windowScene: scene, userInfo: userInfo, content, request) { _ in }
            }
        }

        completionHandler(.newData)
    }

    // MARK: - Bildirime tıklanması
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Tıklama / kapatma olaylarını yakalar, action URL'i açar
        _ = NotificationManager.shared.handleNotificationResponse(response)
        completionHandler()
    }
}
```

SwiftUI uygulamalarında `AppDelegate`'i şöyle bağlarsınız:

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { WindowGroup { ContentView() } }
}
```

### 8.4 Payload Yapısı ve Mesaj Tipleri

Paylisher push payload'ları daima `source: "Paylisher"` taşır ve `type` alanı mesaj türünü belirtir:

| `type` değeri | Anlamı | SDK davranışı |
|---------------|--------|---------------|
| `PUSH` | Standart push bildirim | Başlık/metin/görsel ile gösterilir |
| `ACTION-BASED` | Aksiyon bazlı bildirim | Aksiyon butonlarıyla gösterilir |
| `GEOFENCE` | Konum tabanlı bildirim | Geofence tetikleyince gösterilir |
| `IN-APP` | Uygulama içi mesaj | Modal/banner/fullscreen/carousel render edilir |
| `SILENT_HEARTBEAT` | Sessiz uninstall yoklaması | Görünmez; `handleSilentPush` işler |

Tüm metin alanları çok dilli (lokalize) JSON olarak gelebilir; SDK `defaultLang` alanına göre doğru dili seçer.

### 8.5 Zengin Push için Notification Service Extension (Opsiyonel)

Görsel ekli ve sunucuda işlenen zengin bildirimler için bir **Notification Service Extension** hedefi ekleyin:

1. Xcode → **File → New → Target → Notification Service Extension**.
2. Extension hedefine de **aynı App Group**'u ekleyin.
3. Extension'ın `NotificationService.swift` dosyasını şu şekilde yazın:

```swift
import UserNotifications
import Paylisher

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttempt: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler:
                                @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let bestAttempt = request.content.mutableCopy()
                as? UNMutableNotificationContent else {
            contentHandler(request.content); return
        }
        self.bestAttempt = bestAttempt

        CoreDataManager.shared.configure(appGroupIdentifier: "group.com.sirketiniz.uygulama")

        NotificationManager.shared.customNotification(
            windowScene: nil, with: bestAttempt, for: request) { updated in
            contentHandler(updated)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let handler = contentHandler, let content = bestAttempt {
            handler(content)
        }
    }
}
```

> Sunucu tarafında push payload'ına `mutable-content: 1` eklenmelidir; aksi halde extension çalışmaz.

---

## 9. In-App Mesajlar

Paylisher in-app mesajları iki yolla gelebilir:

### 9.1 FCM Push ile (varsayılan)

`type: "IN-APP"` taşıyan push geldiğinde, 8.3'teki `AppDelegate` örneğinde gösterildiği gibi `NotificationManager.shared.customNotification(...)` çağrısı mesajı otomatik render eder (modal, banner, fullscreen, carousel veya native).

Bu akış için ek bir kod gerekmez — push delege'leri doğru kurulduğunda çalışır.

### 9.2 Engage Pull ile (sunucudan çekme)

FCM'e bağlı olmadan kampanyaları doğrudan Engage servisinden çekmek isterseniz `engageInAppConfig` tanımlayın:

```swift
let inAppConfig = PaylisherEngageInAppConfig(
    fetchEndpoint: "https://engage.paylisher.com/in-app/fetch",
    teamId: "TEAM_ID",
    projectId: "PROJECT_ID",
    sourceId: "SOURCE_ID",
    sdkKey: "SDK_KEY"
)
inAppConfig.autoFetchOnForeground = true   // Uygulama öne gelince otomatik çek
inAppConfig.maxMessages = 1                 // Tek seferde gösterilecek maksimum mesaj
inAppConfig.excludedActivities = ["Splash", "Login"]  // Bu ekranlarda gösterme

config.engageInAppConfig = inAppConfig
PaylisherSDK.shared.setup(config)
```

Mesajları manuel tetiklemek için:

```swift
PaylisherSDK.shared.refreshEngageInAppMessages()
// veya belirli bir hedefe (target) göre:
PaylisherSDK.shared.refreshEngageInAppMessages(target: "anasayfa")
```

> `autoFetchOnForeground = true` iken uygulama her öne geldiğinde mesajlar otomatik kontrol edilir. `excludedActivities` listesindeki ekranlarda (alt dize eşleşmesi, büyük/küçük harf duyarsız) mesaj gösterilmez; uygun ekran açılınca kuyruktaki mesaj render edilir.

---

## 10. Deep Link Entegrasyonu

SDK üç tür deep link'i destekler: doğrudan (URL scheme), universal link ve **deferred deep link** (kurulum atıfı).

### 10.1 Doğrudan Deep Link & Universal Link

```swift
// URL scheme (iOS)
func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return PaylisherSDK.shared.handleDeepLink(url)
}

// Universal Link
func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    return PaylisherSDK.shared.handleUserActivity(userActivity)
}
```

### 10.2 Auth Gerektiren Hedefler

Bazı sayfalar giriş gerektiriyorsa, bunları SDK'ya bildirin. Auth gerektiren bir link gelirse SDK onu bekletir:

```swift
PaylisherSDK.shared.configureDeepLinks(authRequired: [
    "wallet", "transfer", "profile", "settings", "payment"
])
PaylisherSDK.shared.setDeepLinkHandler(self)   // PaylisherDeepLinkHandler
```

Handler protokolünü uygulayın:

```swift
extension AppDelegate: PaylisherDeepLinkHandler {
    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        if requiresAuth {
            // Kullanıcı giriş yaptıktan sonra:
            // PaylisherSDK.shared.completePendingDeepLink()
        } else {
            navigate(to: deepLink.destination)
        }
    }
    func paylisherDeepLinkRequiresAuth(_ deepLink: PaylisherDeepLink,
                                       completion: @escaping (Bool) -> Void) {
        completion(authManager.isAuthenticated)
    }
    func paylisherDeepLinkDidFail(_ url: URL, error: Error?) { }
}
```

Bekleyen link yönetimi:

```swift
PaylisherSDK.shared.hasPendingDeepLink            // Bekleyen link var mı?
PaylisherSDK.shared.pendingDeepLinkDestination    // Hedef adı
PaylisherSDK.shared.completePendingDeepLink()     // Giriş sonrası tamamla
PaylisherSDK.shared.cancelPendingDeepLink()       // İptal et
```

### 10.3 Deferred Deep Link (Kurulum Atıfı)

Kullanıcı uygulamayı kurmadan önce bir kampanya linkine tıkladıysa, kurulum sonrası ilk açılışta eşleştirme yapılır:

```swift
// Yapılandırma (setup'tan önce)
config.deferredDeepLinkConfig = PaylisherDeferredDeepLinkConfig()
config.deferredDeepLinkConfig?.enabled = true
config.deferredDeepLinkConfig?.autoHandleDeepLink = true   // Eşleşince otomatik yönlendir
config.deferredDeepLinkConfig?.includeIDFA = false
PaylisherSDK.shared.setup(config)

// İlk açılışta kontrol
PaylisherSDK.shared.checkDeferredDeepLink(
    onSuccess: { deepLink in
        print("Eşleşme: \(deepLink.url) → \(deepLink.destination)")
    },
    onNoMatch: { print("Organik kurulum") },
    onError:   { error in print("Hata: \(error)") }
)
```

---

## 11. Uninstall Tespiti (Heartbeat)

SDK, sunucudan gelen sessiz (silent) push'lara "alive" yanıtı vererek uygulamanın kaldırılıp kaldırılmadığını tespit eder. Varsayılan olarak açıktır (`enableHeartbeat = true`).

Yapmanız gereken tek şey, sessiz push'u SDK'ya iletmektir (8.3'teki örnekte mevcut):

```swift
func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                 fetchCompletionHandler completionHandler:
                    @escaping (UIBackgroundFetchResult) -> Void) {
    if PaylisherSDK.shared.handleSilentPush(userInfo, completionHandler: completionHandler) {
        return   // Heartbeat SDK tarafından işlendi
    }
    // ... kendi push işleminiz
}
```

Bunun çalışması için **Background Modes → Remote notifications** capability'sinin açık olması gerekir. `completionHandler`'ın Apple'ın 30 sn limiti içinde çağrılması SDK tarafından garanti edilir.

---

## 12. Session Replay

> Deneysel özelliktir; yalnızca iOS'ta çalışır.

```swift
config.sessionReplay = true
config.sessionReplayConfig.maskAllTextInputs = true   // Metin girişlerini maskele
config.sessionReplayConfig.maskAllImages = true       // Görselleri maskele
config.sessionReplayConfig.captureNetworkTelemetry = true
config.sessionReplayConfig.screenshotMode = true      // SwiftUI desteği için gerekli
```

Belirli bir görünümü maskelemek için `accessibilityIdentifier` veya `accessibilityLabel` değerini `ph-no-capture` yapın. SwiftUI için `paylisherMask()` view modifier'ı da kullanılabilir.

**Kısıtlamalar:** SwiftUI yalnızca `screenshotMode` açıkken desteklenir; WebView desteklenmez (placeholder gösterilir); React Native ve Flutter desteklenmez.

---

## 13. Feature Flag'ler

```swift
// Flag'leri yeniden yükle
PaylisherSDK.shared.reloadFeatureFlags {
    if PaylisherSDK.shared.isFeatureEnabled("yeni_odeme_akisi") {
        // özelliği aç
    }
}

// Değer okuma
let aktif = PaylisherSDK.shared.isFeatureEnabled("yeni_odeme_akisi")
let deger = PaylisherSDK.shared.getFeatureFlag("varyant") as? String
let payload = PaylisherSDK.shared.getFeatureFlagPayload("premium")
```

Flag'ler sunucudan geldiğinde haberdar olmak için:

```swift
NotificationCenter.default.addObserver(
    self, selector: #selector(flaglerGeldi),
    name: PaylisherSDK.didReceiveFeatureFlags, object: nil)
```

---

## 14. API Hızlı Referans

| Kategori | Metot |
|----------|-------|
| **Kurulum** | `setup(_:)`, `close()`, `flush()`, `reset()` |
| **Olay** | `capture(_:properties:)`, `screen(_:properties:)` |
| **Kullanıcı** | `identify(_:userProperties:)`, `alias(_:)`, `group(type:key:groupProperties:)` |
| **Özellik** | `register(_:)`, `unregister(_:)` |
| **Kimlik** | `getDistinctId()`, `getAnonymousId()`, `getSessionId()` |
| **Push** | `registerFCMToken(_:)`, `handleSilentPush(_:completionHandler:)` |
| **In-App** | `refreshEngageInAppMessages(target:)` |
| **Deep Link** | `handleDeepLink(_:)`, `handleUserActivity(_:)`, `configureDeepLinks(authRequired:)`, `checkDeferredDeepLink(...)` |
| **Feature Flag** | `reloadFeatureFlags()`, `isFeatureEnabled(_:)`, `getFeatureFlag(_:)`, `getFeatureFlagPayload(_:)` |
| **Gizlilik** | `optIn()`, `optOut()`, `isOptOut()` |
| **Bildirim (NotificationManager)** | `customNotification(...)`, `handleNotificationResponse(_:)`, `handleForegroundPresentation(_:)`, `handleLaunchOptions(_:)` |

---

## 15. Sık Karşılaşılan Sorunlar

**Olaylar sunucuya ulaşmıyor**
- `apiKey` ve `host` doğru mu? `config.debug = true` ile logları inceleyin.
- `flushAt`'ı test sırasında `1` yaparak anlık gönderimi doğrulayın.

**Push gelmiyor**
- APNs Auth Key (.p8) Firebase Console'a yüklendi mi?
- Push Notifications + Background Modes (Remote notifications) capability'leri açık mı?
- FCM token `registerFCMToken(_:)` ile SDK'ya iletiliyor mu?
- `GoogleService-Info.plist` doğru hedefe eklendi mi?

**In-app mesaj görünmüyor**
- `App Group` hem ana uygulamada hem extension'da **aynı** mı?
- `CoreDataManager.shared.configure(appGroupIdentifier:)` çağrıldı mı?
- Mesaj `source: "Paylisher"` ve `type: "IN-APP"` taşıyor mu?
- Ekran `excludedActivities` listesinde olmasın.

**Uygulama açılışta çöküyor (App Group hatası)**
- `appGroupIdentifier` capability'de tanımlı değer ile birebir aynı olmalı.

**Çıkış sonrası `deviceID`/`token` kayboluyor**
- `reset()` super property'leri siler; çıkış sonrası bunları yeniden `register` edin.

---

### Destek

Teknik sorularınız için: **info@paylisher.com**
Resmi dokümantasyon: **https://docs.paylisher.com**
