# Paylisher iOS SDK — Entegrasyon Dökümanı

> **SDK Sürümü:** 1.8.4
> **Minimum iOS:** 13.0 · **Xcode:** 15+ · **Swift:** 5.7 / 5.8 / 5.9
> **Desteklenen platformlar:** iOS, iPadOS, macOS (10.15+), tvOS (13+), watchOS (6+)

Bu döküman, Paylisher iOS SDK'nın bir uygulamaya sıfırdan entegre edilmesi için gereken temel adımları içerir: kurulum, başlatma, olay takibi, kullanıcı tanımlama ve push notification.

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
9. [Feature Flag'ler](#9-feature-flagler)
10. [API Hızlı Referans](#10-api-hızlı-referans)
11. [Sık Karşılaşılan Sorunlar](#11-sık-karşılaşılan-sorunlar)

---

## 1. Genel Bakış

Paylisher iOS SDK; analytics, etkileşim ve yeniden hedefleme ihtiyaçlarını tek bir kütüphanede toplar:

| Özellik | Açıklama |
|---------|----------|
| **Olay Takibi** | Özel olaylar, ekran görüntülemeleri, otomatik uygulama yaşam döngüsü olayları |
| **Kullanıcı Tanımlama** | `identify`, `alias`, `group`, kişi/grup özellikleri |
| **Push Notification** | FCM üzerinden zengin push, aksiyon bazlı bildirim, görsel ekleme |
| **In-App Mesajlar** | Modal, banner, fullscreen, carousel ve native in-app gösterimleri |
| **Deep Link** | Doğrudan, universal link ve deferred deep link (kurulum atıfı) |
| **Feature Flag** | Sunucu taraflı özellik bayrakları ve A/B varyantları |

> **Mimari not:** SDK, Firebase'i kendi içinde **paketlemez**. Push için Firebase Cloud Messaging entegrasyonu **host (ana) uygulamada** yapılır; alınan FCM token'ı SDK'ya `registerFCMToken(_:)` ile iletilir. Bu sayede uygulamanızda hâlihazırda kullandığınız Firebase sürümüyle çakışma yaşanmaz.

> Bu döküman çekirdek entegrasyonu kapsar. In-app mesaj, deep link, geofence ve session replay gibi ileri özellikler için resmi dokümantasyona bakın: **https://docs.paylisher.com**

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

Push entegrasyonu ve diğer özellikler için 8. bölümden itibaren ilerleyin.

---

## 5. SDK Yapılandırması (PaylisherConfig)

Aşağıda, **mevcut test uygulamasında kullanılan** yapılandırma yer alır. Çoğu senaryo için bu ayarlar yeterlidir:

```swift
let config = PaylisherConfig(
    apiKey: "phc_XXXXXXXXXXXXXXXXXXXX",
    host: "https://ds-tr.paylisher.com"
)
config.debug = true                              // Geliştirme sırasında SDK loglarını aç
config.flushAt = 1                               // Her olayı anında gönder (test için; prod'da 20 önerilir)
config.captureApplicationLifecycleEvents = true  // Otomatik yaşam döngüsü olayları (auto-capture)
config.captureScreenViews = true                 // Otomatik ekran görüntüleme takibi (auto-capture)
config.repeatedIdentifyBehavior = .capture       // Aynı kullanıcı tekrar identify edilince olay üret

PaylisherSDK.shared.setup(config)
```

| Ayar | Açıklama |
|------|----------|
| `apiKey` | Proje API anahtarı (zorunlu) |
| `host` | Sunucu adresi (kuruluma özel) |
| `debug` | `true` iken SDK ayrıntılı log basar; **prod'da `false` yapın** |
| `flushAt` | Kaç olay birikince sunucuya gönderileceği. Test'te `1` (anında); prod'da varsayılan `20` önerilir |
| `captureApplicationLifecycleEvents` | Otomatik yaşam döngüsü olayları (auto-capture) — aşağıya bakın |
| `captureScreenViews` | Otomatik ekran görüntüleme takibi (auto-capture) — aşağıya bakın |
| `repeatedIdentifyBehavior` | `.capture` → aynı `distinctId` ile tekrar `identify` çağrılınca olay üretir; `.ignore` → yok sayar |

> Buradaki dışındaki yapılandırma seçenekleri için resmi dokümantasyona bakın: **https://docs.paylisher.com**

### Auto-Capture (Otomatik Takip)

SDK iki tür olayı **ek kod yazmadan** otomatik toplar. İkisi de varsayılan olarak **açıktır**:

**`captureScreenViews`** — Ekran görüntülemelerini otomatik takip eder.
- UIKit'te `UIViewController` geçişlerini yakalayıp `$screen` olayı üretir.
- SwiftUI'da otomatik çalışmaz; ekranları manuel `screen(...)` ile gönderin (bkz. Bölüm 7).

**`captureApplicationLifecycleEvents`** — Uygulama yaşam döngüsü olaylarını otomatik üretir:

| Olay | Ne zaman üretilir |
|------|-------------------|
| `Application Installed` | İlk kurulumdan sonraki ilk açılış |
| `Application Updated` | Sürüm güncellemesinden sonraki ilk açılış |
| `Application Opened` | Uygulama her öne geldiğinde |
| `Application Backgrounded` | Uygulama arka plana alındığında |

Bu otomatik takibi kapatmak isterseniz `false` atayın:

```swift
config.captureScreenViews = false
config.captureApplicationLifecycleEvents = false
```

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

Aşağıdaki `AppDelegate`, push ve uygulama içi (in-app) mesaj gösterimini içeren **eksiksiz** bir kurulumdur:

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
        // Push hedefleme için FCM token'ı SDK'ya bildir
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

    // MARK: - Arka plan push (in-app dahil)
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler:
                        @escaping (UIBackgroundFetchResult) -> Void) {

        // Arka planda gelen in-app mesajı
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

## 9. Feature Flag'ler

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

## 10. API Hızlı Referans

| Kategori | Metot |
|----------|-------|
| **Kurulum** | `setup(_:)`, `close()`, `flush()`, `reset()` |
| **Olay** | `capture(_:properties:)`, `screen(_:properties:)` |
| **Kullanıcı** | `identify(_:userProperties:)`, `alias(_:)`, `group(type:key:groupProperties:)` |
| **Özellik** | `register(_:)`, `unregister(_:)` |
| **Kimlik** | `getDistinctId()`, `getAnonymousId()`, `getSessionId()` |
| **Push** | `registerFCMToken(_:)` |
| **Feature Flag** | `reloadFeatureFlags()`, `isFeatureEnabled(_:)`, `getFeatureFlag(_:)`, `getFeatureFlagPayload(_:)` |
| **Gizlilik** | `optIn()`, `optOut()`, `isOptOut()` |
| **Bildirim (NotificationManager)** | `customNotification(...)`, `handleNotificationResponse(_:)`, `handleForegroundPresentation(_:)`, `handleLaunchOptions(_:)` |

---

## 11. Sık Karşılaşılan Sorunlar

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

**Uygulama açılışta çöküyor (App Group hatası)**
- `appGroupIdentifier` capability'de tanımlı değer ile birebir aynı olmalı.

**Çıkış sonrası `deviceID`/`token` kayboluyor**
- `reset()` super property'leri siler; çıkış sonrası bunları yeniden `register` edin.

---

### Destek

Teknik sorularınız için: **info@paylisher.com**
Resmi dokümantasyon: **https://docs.paylisher.com**
