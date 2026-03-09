# SENARYO 1: DEFERRED DEEPLINK ENTEGRASYONU
# (Uygulama Yuklu Degil - Install Attribution)

---

## GENEL BAKIS

Bu dokuman, uygulamaniz **yuklu olmayan** kullanicilar icin deferred deeplink
entegrasyonunu aciklar. Kullanici bir pazarlama linkine tiklar, App Store'dan
uygulamayi indirir ve ilk acilista otomatik olarak dogru sayfaya yonlendirilir.

**Kullanim Senaryosu:**
- Instagram reklaminda "%50 indirim" kampanyasi
- Kullanici tiklar ama uygulama yuklu degil
- App Store'dan uygulama indirilir
- Uygulama acilir ve OTOMATIK %50 indirim sayfasina gider

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

**Ornek Link:** `uygulamaniz://promo?campaign=holiday_sale`

### 1.2. Universal Links (Opsiyonel ama Onerilen)

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:link.uygulamaniz.com</string>
</array>
```

**Ornek Link:** `https://link.uygulamaniz.com/promo`

### 1.3. App Tracking Transparency (ZORUNLU)

Deferred deeplink icin IDFA kullaniliyorsa (varsayilan: evet):

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Uygulama yuklemelerini pazarlama kampanyalarina baglayarak deneyiminizi
iyilestirmek icin cihaz bilgilerinizi kullaniyoruz.</string>
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

        // 2. Deferred Deeplink Konfigurasyonu
        setupDeferredDeepLink(config: config)

        // 3. SDK'yi Baslat
        PaylisherSDK.shared.setup(config)

        // 4. Deferred Deeplink Kontrolu (KRITIK!)
        checkForDeferredDeepLink()

        return true
    }
}
```

### 2.2. Deferred Deeplink Konfigurasyonu

```swift
extension AppDelegate {

    func setupDeferredDeepLink(config: PaylisherConfig) {
        // Production ayarlari
        let deferredConfig = PaylisherDeferredDeepLinkConfig.forProduction()

        // Veya manuel ayarlar:
        // let deferredConfig = PaylisherDeferredDeepLinkConfig()
        //     .withEnabled(true)
        //     .withAttributionWindow(24 * 60 * 60 * 1000) // 24 saat
        //     .withIDFA(true)  // IDFA dahil et (daha iyi eslesme)
        //     .withDebugLogging(false)  // Production'da false
        //     .withAutoHandle(true)  // Otomatik yonlendirme

        config.deferredDeepLinkConfig = deferredConfig
    }
}
```

### 2.3. Deferred Deeplink Kontrolu

```swift
extension AppDelegate {

    func checkForDeferredDeepLink() {
        PaylisherSDK.shared.checkDeferredDeepLink(
            onSuccess: { deepLink in
                // BASARILI! Install attribution bulundu
                print("✅ Deferred match: \(deepLink.url)")
                print("   Destination: \(deepLink.destination)")
                print("   Campaign: \(deepLink.campaignKeyName ?? "N/A")")

                // SDK otomatik olarak yonlendirecek (autoHandle = true)
                // Eger manuel handle isterseniz:
                // self.navigateToDeepLink(deepLink)
            },
            onNoMatch: {
                // Normal install (organik)
                print("ℹ️ Deferred match bulunamadi - organik install")

                // Normal onboarding akisina devam et
                self.showOnboarding()
            },
            onError: { error in
                // Hata olustu (network hatasi, timeout, vs.)
                print("❌ Deferred deeplink hatasi: \(error.localizedDescription)")

                // Fallback: Normal onboarding
                self.showOnboarding()
            }
        )
    }

    func showOnboarding() {
        // Onboarding ekranlarinizi gosterin
        let onboardingVC = OnboardingViewController()
        window?.rootViewController = onboardingVC
    }
}
```

---

## 3. DEEPLINK HANDLER KURULUMU

### 3.1. Protocol Implementation

**AppDelegate.swift:**

```swift
extension AppDelegate: PaylisherDeepLinkHandler {

    // 1. Deeplink alindigi zaman cagirilir
    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        print("📱 Deeplink alindi: \(deepLink.destination)")

        if requiresAuth {
            // Auth gerekiyor - SDK otomatik pending'e aldi
            print("⏳ Auth gerekiyor, pending...")
            return
        }

        // Auth gerekmiyorsa direkt yonlendir
        navigateToDestination(deepLink)
    }

    // 2. Navigation fonksiyonu
    func navigateToDestination(_ deepLink: PaylisherDeepLink) {
        // Mevcut root view controller'i al
        guard let rootVC = window?.rootViewController else { return }

        // Destination'a gore yonlendirme
        switch deepLink.destination {
        case "promo":
            let promoVC = PromoViewController()
            promoVC.campaignKey = deepLink.campaignKeyName
            rootVC.present(promoVC, animated: true)

        case "product":
            let productID = deepLink.parameters["id"]
            let productVC = ProductViewController(productID: productID)
            rootVC.present(productVC, animated: true)

        case "cart":
            let cartVC = CartViewController()
            rootVC.present(cartVC, animated: true)

        default:
            // Bilinmeyen destination - ana sayfaya git
            let mainVC = MainViewController()
            window?.rootViewController = mainVC
        }
    }
}
```

### 3.2. Handler'i Kaydet

```swift
func application(didFinishLaunchingWithOptions) -> Bool {
    // ... SDK setup

    // Handler'i kaydet
    PaylisherSDK.shared.setDeepLinkHandler(self)

    return true
}
```

---

## 4. URL HANDLING (SceneDelegate veya AppDelegate)

### 4.1. iOS 13+ (SceneDelegate)

**SceneDelegate.swift:**

```swift
import UIKit
import Paylisher

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // Custom URL Scheme
    func scene(_ scene: UIScene,
               openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        // Paylisher SDK'ya ilet
        PaylisherSDK.shared.handleDeepLink(url)
    }

    // Universal Links
    func scene(_ scene: UIScene,
               continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return
        }

        // Paylisher SDK'ya ilet
        PaylisherSDK.shared.handleDeepLink(url)
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

    return PaylisherSDK.shared.handleDeepLink(url)
}
```

---

## 5. TEST ETME

### 5.1. Test Konfigurasyonu

Test icin daha kisa attribution window kullanin:

```swift
func setupDeferredDeepLink(config: PaylisherConfig) {
    let deferredConfig = PaylisherDeferredDeepLinkConfig.forTesting()
    // Test ayarlari:
    // - Attribution window: 1 saat (hizli test icin)
    // - IDFA dahil degil (izin gerektirmez)
    // - Debug logging: aktif

    config.deferredDeepLinkConfig = deferredConfig
}
```

### 5.2. Test Adimlari

1. **Uygulamayi Simulatordan Silin:**
   ```
   Simulator -> Device -> Erase All Content and Settings
   ```

2. **Backend'e Test Link Kaydedin:**
   - API cagrisiniz olacak (backend ekibi ile koordine edin)
   - Test fingerprint + URL kaydedin

3. **Uygulamayi Yeniden Yukleyin:**
   - Xcode'dan Run
   - Veya TestFlight'tan install

4. **Loglari Takip Edin:**
   ```
   [PaylisherDeferredDeepLink] Starting check...
   [PaylisherDeferredDeepLink] First launch detected
   [PaylisherDeferredDeepLink] Fingerprint generated: a1b2c3d4...
   [PaylisherDeferredDeepLink] Checking backend...
   [PaylisherDeferredDeepLink] Match found!
   [PaylisherDeferredDeepLink] JID set: journey_abc123
   ```

5. **Deeplink Yonlendirmesini Dogrulayin:**
   - Uygulama otomatik olarak dogru sayfada acilmali

### 5.3. Test Sonrasi Reset

```swift
// Test sonrasi state'i resetlemek icin
PaylisherSDK.shared.resetDeferredDeepLinkForTesting()
```

---

## 6. PRODUCTION DEPLOYMENT

### 6.1. Production Checklist

- [ ] `Info.plist` ayarlari tamamlandi
- [ ] `NSUserTrackingUsageDescription` eklendi
- [ ] Production API key kullaniliyor
- [ ] Debug logging kapatildi
- [ ] Attribution window 24 saat (varsayilan)
- [ ] IDFA dahil (daha iyi attribution icin)
- [ ] Deeplink handler implement edildi
- [ ] Test edildi ve calisiyor

### 6.2. Production Config

```swift
func setupDeferredDeepLink(config: PaylisherConfig) {
    let deferredConfig = PaylisherDeferredDeepLinkConfig()
        .withEnabled(true)
        .withAttributionWindow(24 * 60 * 60 * 1000)  // 24 saat
        .withIDFA(true)  // En iyi attribution icin
        .withDebugLogging(false)  // Production'da kapali
        .withAutoHandle(true)  // Otomatik yonlendirme
        .withAdditionalEventProperties([
            "environment": "production",
            "app_version": Bundle.main.appVersion
        ])

    config.deferredDeepLinkConfig = deferredConfig
}
```

---

## 7. ANALYTICS EVENTS

SDK otomatik olarak su event'leri yakalar:

### 7.1. "Deferred Deep Link Match"

Install attribution basarili:

```json
{
  "event": "Deferred Deep Link Match",
  "url": "uygulamaniz://promo?campaign=holiday_sale",
  "campaign_key": "CAMPAIGN_KEY_123",
  "jid": "journey_abc123",
  "source": "deferred_deeplink",
  "destination": "promo",
  "is_first_launch": true,
  "attribution_window_seconds": 86400,
  "click_timestamp": "2025-01-08T10:30:00Z"
}
```

### 7.2. "Deferred Deep Link Check"

Match bulunamadi (organik install):

```json
{
  "event": "Deferred Deep Link Check",
  "is_first_launch": true,
  "status": "no_match"
}
```

### 7.3. "Deferred Deep Link Error"

Hata olustu:

```json
{
  "event": "Deferred Deep Link Error",
  "is_first_launch": true,
  "status": "error",
  "error_message": "Network timeout"
}
```

---

## 8. SIKCA SORULAN SORULAR

### S: Attribution window nedir?

**C:** Kullanicinin link'e tiklayip uygulamayi yukledigi sure arasindaki maksimum
sure. Varsayilan 24 saat. Yani kullanici linkten 24 saat sonra yuklerse artik
eslesme olmaz.

### S: IDFA kullanmak zorunlu mu?

**C:** Hayir. IDFA kullanmazsaniz sadece IDFV (Vendor ID) kullanilir. Ancak IDFA
ile eslesme orani daha yuksektir. IDFA icin kullanici izni gerekir (iOS 14.5+).

### S: Deferred deeplink her zaman calisir mi?

**C:** Hayir. Probabilistic matching kullanir. Basari orani genelde %60-80
araligindadir. IDFA ile bu oran %90+ olabilir.

### S: Backend entegrasyonu gerekli mi?

**C:** Evet. Link tiklandiginda backend'inizin cihaz fingerprint + URL'i
kaydetmesi gerekir. Paylisher backend'i bunu sizin icin yapar.

### S: Test ederken hep "no match" aliyor

um?

**C:** Kontrol edin:
- Uygulama gercekten ilk kez mi yukleniyor? (Simulator reset edin)
- Backend'de test link kayitli mi?
- Attribution window icinde misiniz? (Test icin 1 saat kullanin)
- Debug logging acik mi? Log'lari kontrol edin

---

## 9. DESTEK

Sorun yasiyorsaniz:

1. Debug logging'i acin:
   ```swift
   deferredConfig.withDebugLogging(true)
   ```

2. Log'lari kontrol edin:
   ```
   [PaylisherDeferredDeepLink] ...
   ```

3. Paylisher destek ekibi ile iletisime gecin:
   - Email: support@paylisher.com
   - Dokuman: https://docs.paylisher.com

---

**Dokuman Versiyonu:** 1.0
**Son Guncelleme:** 08 Ocak 2025
**SDK Versiyonu:** 1.6.0+
