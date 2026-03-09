# SENARYO 2: DIRECT DEEPLINK ENTEGRASYONU
# (Uygulama Yuklu - Direkt Yonlendirme)

---

## GENEL BAKIS

Bu dokuman, uygulamaniz **yuklu olan** kullanicilar icin direct deeplink
entegrasyonunu aciklar. Kullanici bir link'e tiklar ve uygulama direkt dogru
sayfada acilir.

**Kullanim Senaryosu:**
- Email'de "Sepetindeki urunler seni bekliyor" linki
- Kullanici tiklar (uygulama yuklu)
- Uygulama acilir ve DIREKT sepet sayfasina gider

---

## 1. INFO.PLIST AYARLARI

### 1.1. URL Scheme Ekleme

`Info.plist` dosyaniza URL scheme ekleyin:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.sirketiniz.uygulama</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>uygulamaniz</string>
        </array>
    </dict>
</array>
```

**Ornek Linkler:**
```
uygulamaniz://product?id=12345
uygulamaniz://cart
uygulamaniz://promo?campaign=summer_sale
```

### 1.2. Universal Links (ONERILEN)

Universal Link'ler kullanici deneyimini iyilestirir ve App Store fallback saglar.

**Info.plist:**

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:link.uygulamaniz.com</string>
    <string>applinks:www.uygulamaniz.com</string>
</array>
```

**Ornek Universal Linkler:**
```
https://link.uygulamaniz.com/product/12345
https://link.uygulamaniz.com/cart
https://link.uygulamaniz.com/promo
```

### 1.3. AASA Dosyasi (Universal Links icin)

Sunucunuzda `apple-app-site-association` dosyasi bulunmalidir:

**Konum:** `https://link.uygulamaniz.com/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.sirketiniz.uygulama",
        "paths": [
          "/product/*",
          "/cart",
          "/promo",
          "/campaign/*"
        ]
      }
    ]
  }
}
```

---

## 2. SDK KURULUMU

### 2.1. Temel SDK Setup

**AppDelegate.swift:**

```swift
import UIKit
import Paylisher

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 1. SDK Konfigurasyonu
        let config = PaylisherConfig(apiKey: "PAYLISHER_API_KEY")

        // 2. Deeplink Konfigurasyonu
        setupDeepLink(config: config)

        // 3. SDK'yi Baslat
        PaylisherSDK.shared.setup(config)

        // 4. Deeplink Handler'i Kaydet
        PaylisherSDK.shared.setDeepLinkHandler(self)

        return true
    }
}
```

### 2.2. Deeplink Konfigurasyonu

```swift
extension AppDelegate {

    func setupDeepLink(config: PaylisherConfig) {
        let deepLinkConfig = PaylisherDeepLinkConfig()

        // URL Scheme'ler (en az 1 tane gerekli)
        deepLinkConfig.customSchemes = ["uygulamaniz"]

        // Universal Link domainleri
        deepLinkConfig.universalLinkDomains = [
            "link.uygulamaniz.com",
            "www.uygulamaniz.com"
        ]

        // Otomatik event yakalama (varsayilan: true)
        deepLinkConfig.captureDeepLinkEvents = true

        // Otomatik handle (varsayilan: true)
        deepLinkConfig.autoHandleDeepLinks = true

        // Debug logging
        deepLinkConfig.debugLogging = false  // Production'da false

        config.deepLinkConfig = deepLinkConfig
    }
}
```

---

## 3. DEEPLINK HANDLER IMPLEMENTATION

### 3.1. Protocol Implementation

**AppDelegate.swift:**

```swift
extension AppDelegate: PaylisherDeepLinkHandler {

    // 1. Deeplink alindigi zaman cagirilir
    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        print("📱 Deeplink alindi:")
        print("   URL: \(deepLink.url)")
        print("   Destination: \(deepLink.destination)")
        print("   Scheme: \(deepLink.scheme)")
        print("   Parameters: \(deepLink.parameters)")

        if requiresAuth {
            // Auth gerekiyor - bu senaryo icin bakiniz: SENARYO-3
            print("⏳ Auth gerekiyor")
            return
        }

        // Direkt yonlendir
        navigateToDestination(deepLink)
    }

    // 2. Navigation fonksiyonu
    func navigateToDestination(_ deepLink: PaylisherDeepLink) {
        // Ana navigation controller'i al
        guard let window = window,
              let navigationController = window.rootViewController as? UINavigationController else {
            print("❌ Navigation controller bulunamadi")
            return
        }

        // Destination'a gore yonlendirme yap
        switch deepLink.destination {

        case "product":
            // Urun detay sayfasi
            // URL: uygulamaniz://product?id=12345
            if let productID = deepLink.parameters["id"] {
                let productVC = ProductDetailViewController()
                productVC.productID = productID
                navigationController.pushViewController(productVC, animated: true)
            }

        case "cart":
            // Sepet sayfasi
            // URL: uygulamaniz://cart
            let cartVC = CartViewController()
            navigationController.pushViewController(cartVC, animated: true)

        case "promo":
            // Kampanya sayfasi
            // URL: uygulamaniz://promo?campaign=summer_sale
            let promoVC = PromoViewController()
            promoVC.campaignID = deepLink.parameters["campaign"]
            promoVC.campaignKey = deepLink.campaignKeyName
            navigationController.pushViewController(promoVC, animated: true)

        case "category":
            // Kategori sayfasi
            // URL: uygulamaniz://category?id=electronics
            if let categoryID = deepLink.parameters["id"] {
                let categoryVC = CategoryViewController()
                categoryVC.categoryID = categoryID
                navigationController.pushViewController(categoryVC, animated: true)
            }

        case "profile":
            // Profil sayfasi
            // URL: uygulamaniz://profile
            let profileVC = ProfileViewController()
            navigationController.pushViewController(profileVC, animated: true)

        case "search":
            // Arama sayfasi
            // URL: uygulamaniz://search?q=iPhone
            let searchVC = SearchViewController()
            searchVC.initialQuery = deepLink.parameters["q"]
            navigationController.pushViewController(searchVC, animated: true)

        default:
            // Bilinmeyen destination - ana sayfaya git
            print("⚠️ Bilinmeyen destination: \(deepLink.destination)")
            navigationController.popToRootViewController(animated: true)
        }

        // Analytics event (otomatik yakalaniyor ama custom event de ekleyebilirsiniz)
        PaylisherSDK.shared.capture("Custom Deeplink Navigation", properties: [
            "destination": deepLink.destination,
            "source": deepLink.source ?? "unknown",
            "has_campaign": deepLink.campaignKeyName != nil
        ])
    }
}
```

---

## 4. URL HANDLING

### 4.1. iOS 13+ (SceneDelegate)

**SceneDelegate.swift:**

```swift
import UIKit
import Paylisher

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // METOD 1: Custom URL Scheme
    func scene(_ scene: UIScene,
               openURLContexts URLContexts: Set<UIOpenURLContext>) {

        guard let url = URLContexts.first?.url else { return }

        print("📱 URL Scheme acildi: \(url)")

        // Paylisher SDK'ya ilet
        let handled = PaylisherSDK.shared.handleDeepLink(url)

        if handled {
            print("✅ Deeplink handle edildi")
        } else {
            print("❌ Deeplink handle edilemedi")
        }
    }

    // METOD 2: Universal Links
    func scene(_ scene: UIScene,
               continue userActivity: NSUserActivity) {

        // Universal Link kontrolu
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return
        }

        print("🌐 Universal Link acildi: \(url)")

        // Paylisher SDK'ya ilet
        let handled = PaylisherSDK.shared.handleDeepLink(url)

        if handled {
            print("✅ Universal link handle edildi")
        } else {
            print("❌ Universal link handle edilemedi")
        }
    }

    // BONUS: Widget veya Shortcut'tan gelen deeplink'ler
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        // URL context kontrolu
        if let urlContext = connectionOptions.urlContexts.first {
            PaylisherSDK.shared.handleDeepLink(urlContext.url)
        }

        // User activity kontrolu
        if let userActivity = connectionOptions.userActivities.first,
           userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            PaylisherSDK.shared.handleDeepLink(url)
        }
    }
}
```

### 4.2. iOS 12 ve Oncesi (AppDelegate)

**AppDelegate.swift:**

```swift
// Custom URL Scheme
func application(_ app: UIApplication,
                 open url: URL,
                 options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

    print("📱 URL Scheme acildi: \(url)")

    return PaylisherSDK.shared.handleDeepLink(url)
}

// Universal Links
func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else {
        return false
    }

    print("🌐 Universal Link acildi: \(url)")

    return PaylisherSDK.shared.handleDeepLink(url)
}
```

---

## 5. CAMPAIGN RESOLUTION (OTOMATIK)

SDK otomatik olarak campaign bilgilerini backend'den cekmektedir.

### 5.1. Campaign Key Formatlari

SDK su formatlardaki campaign key'lerini otomatik algilar:

```swift
// Format 1: Query parameter
uygulamaniz://promo?keyName=CAMPAIGN_KEY_123

// Format 2: Short parameter
uygulamaniz://promo?key=CAMPAIGN_KEY_123
uygulamaniz://promo?k=CAMPAIGN_KEY_123

// Format 3: Path-based
uygulamaniz://campaign/CAMPAIGN_KEY_123
uygulamaniz://c/CAMPAIGN_KEY_123

// Format 4: Direct (min 10 karakter)
uygulamaniz://CAMPAIGN_KEY_123
```

### 5.2. Campaign Data Kullanimi

Campaign resolve edildikten sonra data'ya erismek:

```swift
func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {

    // Campaign data var mi kontrol et
    if let campaignData = deepLink.campaignData {
        print("📊 Campaign bilgileri:")
        print("   Title: \(campaignData.title ?? "N/A")")
        print("   Type: \(campaignData.type ?? "N/A")")
        print("   Expires: \(campaignData.daysUntilExpire ?? 0) gun")

        // Web URL varsa
        if let webURL = campaignData.webUrl {
            print("   Web URL: \(webURL)")
        }

        // Metadata'ya erisim
        if let metadata = campaignData.metadata {
            print("   Metadata: \(metadata)")
        }
    }

    // Normal navigation
    navigateToDestination(deepLink)
}
```

---

## 6. PARAMETRE YONETIMI

### 6.1. Query Parametreleri

```swift
// URL: uygulamaniz://product?id=12345&color=red&size=L

func navigateToProduct(_ deepLink: PaylisherDeepLink) {
    // Parametreleri al
    let productID = deepLink.parameters["id"]  // "12345"
    let color = deepLink.parameters["color"]   // "red"
    let size = deepLink.parameters["size"]     // "L"

    let productVC = ProductDetailViewController()
    productVC.productID = productID
    productVC.selectedColor = color
    productVC.selectedSize = size

    // Navigate
    navigationController?.pushViewController(productVC, animated: true)
}
```

### 6.2. UTM Parametreleri

UTM parametreleri otomatik yakalanir:

```swift
// URL: uygulamaniz://promo?utm_source=instagram&utm_campaign=summer_sale

func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
    // Source ve Campaign ID otomatik parse edilir
    print("Source: \(deepLink.source ?? "unknown")")  // "instagram"
    print("Campaign: \(deepLink.campaignId ?? "unknown")")  // "summer_sale"

    // Parameters'dan da ulasabilirsiniz
    let utmMedium = deepLink.parameters["utm_medium"]
    let utmContent = deepLink.parameters["utm_content"]
}
```

---

## 7. JOURNEY ID TRACKING

Her deeplink otomatik olarak Journey ID (jid) set eder.

### 7.1. Otomatik JID Set

```swift
// URL: uygulamaniz://promo?jid=journey_abc123

// SDK otomatik olarak jid'yi set eder
// Sonraki tum event'ler bu jid ile isaretlenir
```

### 7.2. Journey Bilgilerine Erismek

```swift
// Mevcut journey ID'yi al
if let jid = PaylisherJourneyContext.shared.getJourneyId() {
    print("Active Journey ID: \(jid)")
}

// Journey metadata
if let metadata = PaylisherJourneyContext.shared.getJourneyMetadata() {
    print("Journey Source: \(metadata["source"] ?? "unknown")")
    print("Journey Age: \(metadata["age_hours"] ?? 0) saat")
}

// Journey aktif mi?
if PaylisherJourneyContext.shared.hasActiveJourney {
    print("Kullanicinin aktif journey'i var")
}
```

---

## 8. ANALYTICS EVENTS

### 8.1. Otomatik Event'ler

SDK otomatik olarak su event'leri yakalar:

**"Deep Link Opened"**
```json
{
  "event": "Deep Link Opened",
  "destination": "product",
  "scheme": "uygulamaniz",
  "full_url": "uygulamaniz://product?id=12345",
  "jid": "journey_abc123",
  "campaign_key": "CAMPAIGN_KEY_123",
  "campaign_resolved": true,
  "campaign_title": "Yaz Indirimleri",
  "parameters": {
    "id": "12345"
  }
}
```

### 8.2. Custom Event'ler

Kendi event'lerinizi ekleyebilirsiniz:

```swift
func navigateToDestination(_ deepLink: PaylisherDeepLink) {
    // Navigation
    // ...

    // Custom event
    PaylisherSDK.shared.capture("Product Viewed From Deeplink", properties: [
        "product_id": deepLink.parameters["id"] ?? "",
        "source": deepLink.source ?? "unknown",
        "has_campaign": deepLink.campaignKeyName != nil,
        "referrer": deepLink.parameters["ref"] ?? "direct"
    ])
}
```

---

## 9. TEST ETME

### 9.1. Simulator'de Test

**Terminal'den URL acma:**

```bash
# Custom URL Scheme
xcrun simctl openurl booted "uygulamaniz://product?id=12345"

# Universal Link
xcrun simctl openurl booted "https://link.uygulamaniz.com/product/12345"
```

**Safari'den Test:**

1. Safari'yi simulatorde acin
2. Adres cubuguna linki yapin
3. Git'e basin
4. Uygulamaniz acilmali

### 9.2. Fiziksel Cihazda Test

**Notes uygulamasindan:**

1. Notes uygulamasini acin
2. Yeni not olusturun
3. Link'i yapin: `uygulamaniz://product?id=12345`
4. Link'e tiklin
5. Uygulamaniz acilmali

**iMessage'dan:**

1. Kendinize mesaj gonderin
2. Link'i gonderin
3. Link'e tiklin

### 9.3. Debug Logging

Test sirasinda debug logging'i acin:

```swift
func setupDeepLink(config: PaylisherConfig) {
    let deepLinkConfig = PaylisherDeepLinkConfig()
    deepLinkConfig.debugLogging = true  // Test icin acik

    config.deepLinkConfig = deepLinkConfig
}
```

Console'da gormelisiniz:

```
[PaylisherDeepLink] URL alindi: uygulamaniz://product?id=12345
[PaylisherDeepLink] Scheme: uygulamaniz
[PaylisherDeepLink] Destination: product
[PaylisherDeepLink] Parameters: ["id": "12345"]
[PaylisherDeepLink] Campaign key bulundu: CAMPAIGN_KEY_123
[PaylisherDeepLink] Campaign resolve ediliyor...
[PaylisherDeepLink] Campaign resolved!
[PaylisherDeepLink] Event yakalandi: Deep Link Opened
```

---

## 10. PRODUCTION BEST PRACTICES

### 10.1. Production Checklist

- [ ] `Info.plist` ayarlari tamamlandi
- [ ] Universal Links domain'leri eklendi
- [ ] AASA dosyasi sunucuda dogru konumda
- [ ] Deeplink handler implement edildi
- [ ] Tum destination'lar handle ediliyor
- [ ] Debug logging kapatildi
- [ ] Test edildi (simulator + fiziksel cihaz)
- [ ] Analytics event'leri kontrol edildi

### 10.2. Hata Yonetimi

Bilinmeyen destination'lar icin fallback saglayin:

```swift
func navigateToDestination(_ deepLink: PaylisherDeepLink) {
    switch deepLink.destination {
    case "product": // ...
    case "cart": // ...

    default:
        // Bilinmeyen destination
        print("⚠️ Bilinmeyen destination: \(deepLink.destination)")

        // Ana sayfaya don
        navigationController?.popToRootViewController(animated: true)

        // Analytics - hata tracking
        PaylisherSDK.shared.capture("Unknown Deeplink Destination", properties: [
            "destination": deepLink.destination,
            "url": deepLink.url.absoluteString
        ])

        // Kullaniciya bilgi ver
        showAlert(
            title: "Sayfa Bulunamadi",
            message: "Aradiginiz sayfa bulunamadi. Ana sayfaya yonlendiriliyorsunuz."
        )
    }
}
```

### 10.3. Network Hatalari

Campaign resolution sirasinda network hatasi olabilir:

```swift
// SDK otomatik olarak handle eder
// Campaign resolve edilemezse deeplink yine de calisir
// Sadece campaign data bos gelir

func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
    if deepLink.campaignData == nil && deepLink.campaignKeyName != nil {
        print("⚠️ Campaign resolve edilemedi ama deeplink calisiyor")
    }

    // Normal navigation devam eder
    navigateToDestination(deepLink)
}
```

---

## 11. SIKCA SORULAN SORULAR

### S: Universal Link vs Custom URL Scheme hangisi daha iyi?

**C:** Universal Link oneriliriz cunku:
- Uygulama yuklu degilse otomatik App Store'a yonlendirir
- Web sayfanizda fallback olarak calisir
- Daha profesyonel gorunur (https://link.uygulamaniz.com)
- iOS tarafindan onceliklidir

### S: Uygulama kapaliyken deeplink calisir mi?

**C:** Evet. iOS uygulamayi acar ve SDK deeplink'i handle eder.

### S: Uygulama background'dayken deeplink calisir mi?

**C:** Evet. iOS uygulamayi foreground'a getirir ve deeplink handle edilir.

### S: Campaign resolution ne kadar surer?

**C:** Genelde 1-2 saniye. Ancak network'e bagli olarak degisir. SDK
asenkron olarak handle eder, kullanici UX'i etkilemez.

### S: Deeplink'ten gelen parametreler nasil validate edilir?

**C:** Handler fonksiyonunda validate edin:

```swift
func navigateToDestination(_ deepLink: PaylisherDeepLink) {
    switch deepLink.destination {
    case "product":
        // Validate product ID
        guard let productID = deepLink.parameters["id"],
              !productID.isEmpty,
              productID.count < 20 else {
            print("❌ Gecersiz product ID")
            return
        }
        // Navigate
    }
}
```

---

## 12. DESTEK

Sorun yasiyorsaniz:

1. Debug logging'i acin
2. Log'lari kontrol edin
3. Universal Link validator kullanin:
   - https://search.developer.apple.com/appsearch-validation-tool/

4. Paylisher destek ekibi ile iletisime gecin:
   - Email: support@paylisher.com
   - Dokuman: https://docs.paylisher.com

---

**Dokuman Versiyonu:** 1.0
**Son Guncelleme:** 08 Ocak 2025
**SDK Versiyonu:** 1.6.0+
