# SENARYO 3: AUTH-REQUIRED DEEPLINK ENTEGRASYONU
# (Giris Gerektiren Sayfalar icin Deeplink)

---

## GENEL BAKIS

Bu dokuman, **authentication (giris) gerektiren** sayfalar icin deeplink
entegrasyonunu aciklar. Kullanici bir link'e tiklar ama hedef sayfa giris
gerektiriyorsa, kullanici once giris yapar sonra otomatik olarak hedef
sayfaya yonlendirilir.

**Kullanim Senaryosu:**
- Kullanici "Siparislerim" linkine tiklar
- Uygulama acilir ama kullanici giris yapmamis
- Giris ekrani gosterilir
- Kullanici giris yapar
- OTOMATIK olarak Siparislerim sayfasina yonlendirilir

---

## 1. AUTH-REQUIRED DESTINATIONS TANIMI

### 1.1. SDK Konfigurasyonu

**AppDelegate.swift:**

```swift
import UIKit
import Paylisher

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(didFinishLaunchingWithOptions) -> Bool {

        let config = PaylisherConfig(apiKey: "PAYLISHER_API_KEY")

        // Deeplink konfigurasyonu
        let deepLinkConfig = PaylisherDeepLinkConfig()

        // Giris gerektiren destination'lari tanimla
        deepLinkConfig.authRequiredDestinations = [
            "orders",      // Siparislerim
            "profile",     // Profilim
            "favorites",   // Favorilerim
            "cart",        // Sepetim
            "checkout",    // Odeme sayfasi
            "wallet",      // Cuzdan
            "settings"     // Ayarlar
        ]

        // Pending deeplink timeout (varsayilan: 300 saniye = 5 dakika)
        deepLinkConfig.pendingDeepLinkTimeout = 300

        // Otomatik handle
        deepLinkConfig.autoHandleDeepLinks = true

        config.deepLinkConfig = deepLinkConfig

        PaylisherSDK.shared.setup(config)
        PaylisherSDK.shared.setDeepLinkHandler(self)

        return true
    }
}
```

### 1.2. URL-Based Auth Requirement

URL'de manuel olarak auth gerekliligi belirtmek:

```swift
// URL'de auth=required parametresi ekleyin
uygulamaniz://product?id=12345&auth=required

// SDK otomatik olarak algilar
```

Bu ozellik config'deki liste disindaki sayfalar icin kullanislidir.

---

## 2. DEEPLINK HANDLER IMPLEMENTATION

### 2.1. Protocol Implementation

**AppDelegate.swift:**

```swift
extension AppDelegate: PaylisherDeepLinkHandler {

    // 1. Deeplink alindi
    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        print("📱 Deeplink alindi:")
        print("   Destination: \(deepLink.destination)")
        print("   Auth Required: \(requiresAuth)")

        if requiresAuth {
            // Auth gerekiyor - SDK otomatik pending'e aldi
            print("⏳ Pending deeplink olusturuldu")
            // Bu method'dan cikabilirsiniz - SDK handle edecek
            return
        }

        // Auth gerekmiyorsa direkt yonlendir
        navigateToDestination(deepLink)
    }

    // 2. Auth gerektiginde cagirilir (OPSIYONEL)
    func paylisherDeepLinkRequiresAuth(_ deepLink: PaylisherDeepLink,
                                       completion: @escaping (Bool) -> Void) {
        print("🔐 Auth flow baslatiliyor...")

        // Auth flow'unu baslat
        showAuthenticationFlow { success in
            if success {
                print("✅ Auth basarili - deeplink tamamlanacak")
                // SDK otomatik olarak pending deeplink'i handle edecek
                completion(true)
            } else {
                print("❌ Auth iptal edildi veya basarisiz")
                completion(false)
            }
        }
    }

    // 3. Deeplink basarisiz oldugunda (OPSIYONEL)
    func paylisherDeepLinkDidFail(_ error: Error, url: URL?) {
        print("❌ Deeplink hatasi: \(error.localizedDescription)")

        // Kullaniciya hata mesaji goster
        showAlert(
            title: "Link Hatasi",
            message: "Link acilamadi. Lutfen tekrar deneyin."
        )
    }
}
```

### 2.2. Authentication Flow

```swift
extension AppDelegate {

    func showAuthenticationFlow(completion: @escaping (Bool) -> Void) {
        // Mevcut kullanici giris yapmis mi kontrol et
        if UserManager.shared.isLoggedIn {
            // Zaten giris yapmis - direkt devam et
            completion(true)
            return
        }

        // Giris ekranini goster
        guard let window = window else {
            completion(false)
            return
        }

        let loginVC = LoginViewController()

        // Login basarili olunca
        loginVC.onLoginSuccess = { user in
            print("✅ Giris basarili: \(user.email)")

            // SDK'ya basarili bildir - pending deeplink tamamlanacak
            completion(true)

            // Analytics
            PaylisherSDK.shared.capture("Login From Deeplink", properties: [
                "login_method": "email",
                "has_pending_deeplink": true
            ])
        }

        // Login iptal edilince
        loginVC.onLoginCancel = {
            print("❌ Giris iptal edildi")

            // SDK'ya iptal bildir
            completion(false)

            // Analytics
            PaylisherSDK.shared.capture("Login Cancelled", properties: [
                "source": "deeplink",
                "had_pending_deeplink": true
            ])
        }

        // Login ekranini present et
        if let rootVC = window.rootViewController {
            rootVC.present(loginVC, animated: true)
        }
    }
}
```

---

## 3. PENDING DEEPLINK YONETIMI

### 3.1. Otomatik Pending System

SDK otomatik olarak pending deeplink'leri yonetir:

```
1. Deeplink alindi (auth gerekiyor)
   └─ SDK: Pending deeplink olusturuldu
   └─ Timeout timer baslatildi (5 dakika)

2. Auth flow baslatildi
   └─ Kullanici giris ekraninda

3. Kullanici giris yapti
   └─ completion(true) cagirildi
   └─ SDK: Pending deeplink tamamlaniyor
   └─ Otomatik olarak hedef sayfaya yonlendiriliyor
   └─ Event: "Deep Link Completed"

4. Eger timeout olursa (5 dakika)
   └─ SDK: Pending deeplink iptal edildi
   └─ Event: "Deep Link Timeout"
```

### 3.2. Manuel Pending Deeplink Yonetimi

Isterseniz manuel olarak da yonetebilirsiniz:

```swift
// Pending deeplink'i tamamla
PaylisherSDK.shared.completePendingDeepLink()

// Pending deeplink'i iptal et
PaylisherSDK.shared.cancelPendingDeepLink()

// Pending deeplink'i temizle
PaylisherSDK.shared.clearPendingDeepLink()

// Mevcut pending deeplink'i al
if let pendingDeepLink = PaylisherSDK.shared.pendingDeepLink {
    print("Pending deeplink var: \(pendingDeepLink.destination)")
}
```

---

## 4. ONBOARDING + AUTH SENARYOSU

Uygulama ilk kez yuklendiginde hem onboarding hem auth gerekiyorsa:

### 4.1. Deferred Deeplink + Auth Kombinasyonu

**AppDelegate.swift:**

```swift
func application(didFinishLaunchingWithOptions) -> Bool {
    // SDK setup
    let config = PaylisherConfig(apiKey: "KEY")

    // Deeplink config
    let deepLinkConfig = PaylisherDeepLinkConfig()
    deepLinkConfig.authRequiredDestinations = ["orders", "profile", "cart"]
    config.deepLinkConfig = deepLinkConfig

    // Deferred deeplink config
    let deferredConfig = PaylisherDeferredDeepLinkConfig.forProduction()
    deferredConfig.autoHandleDeepLink = false  // Manuel kontrol icin
    config.deferredDeepLinkConfig = deferredConfig

    PaylisherSDK.shared.setup(config)
    PaylisherSDK.shared.setDeepLinkHandler(self)

    // Deferred deeplink check
    PaylisherSDK.shared.checkDeferredDeepLink(
        onSuccess: { deepLink in
            print("✅ Deferred match: \(deepLink.destination)")

            // Onboarding + Auth flow baslat
            self.showOnboardingAndAuthFlow(pendingDeepLink: deepLink)
        },
        onNoMatch: {
            // Normal onboarding
            self.showOnboarding()
        },
        onError: { _ in
            self.showOnboarding()
        }
    )

    return true
}

func showOnboardingAndAuthFlow(pendingDeepLink: PaylisherDeepLink) {
    // 1. Onboarding ekranlari
    let onboardingVC = OnboardingViewController()

    onboardingVC.onComplete = {
        // 2. Onboarding tamamlandi - simdi auth
        let authVC = SignUpViewController()

        authVC.onSignUpSuccess = { user in
            // 3. Auth basarili - simdi pending deeplink'i handle et
            print("✅ Kayit basarili - deeplink handle ediliyor")

            // Deeplink'i handle et
            PaylisherSDK.shared.handleDeepLink(pendingDeepLink.url)
        }

        authVC.onCancel = {
            // Iptal - ana sayfaya git
            self.showMainScreen()
        }

        self.window?.rootViewController = authVC
    }

    window?.rootViewController = onboardingVC
}
```

### 4.2. Progressive Onboarding

Onboarding'i erteleyerek daha hizli auth:

```swift
func showOnboardingAndAuthFlow(pendingDeepLink: PaylisherDeepLink) {
    // Onboarding'i atla - direkt quick auth
    let quickAuthVC = QuickSignUpViewController()

    // Pending deeplink bilgisini goster
    quickAuthVC.showPendingDeeplinkBanner(
        title: "Ozel Teklif Seni Bekliyor!",
        message: "Kaydini tamamla, hemen indirime yonlendirileceksin"
    )

    quickAuthVC.onSignUpSuccess = { user in
        // Auth basarili - deeplink'i handle et
        PaylisherSDK.shared.handleDeepLink(pendingDeepLink.url)

        // Onboarding'i ertele (sonra goster)
        self.scheduleOnboardingForLater()
    }

    window?.rootViewController = quickAuthVC
}

func scheduleOnboardingForLater() {
    // Kullanici ilk islemini yaptiktan sonra inline tips goster
    UserDefaults.standard.set(true, forKey: "show_onboarding_tips")
}
```

---

## 5. TIMEOUT YONETIMI

### 5.1. Timeout Konfigurasyonu

```swift
let deepLinkConfig = PaylisherDeepLinkConfig()

// 5 dakika timeout (varsayilan)
deepLinkConfig.pendingDeepLinkTimeout = 300

// Veya daha kisa (test icin)
deepLinkConfig.pendingDeepLinkTimeout = 60  // 1 dakika

// Veya daha uzun
deepLinkConfig.pendingDeepLinkTimeout = 600  // 10 dakika
```

### 5.2. Timeout Event'i

Timeout oldugunda SDK otomatik event yakalar:

```json
{
  "event": "Deep Link Timeout",
  "destination": "orders",
  "timeout_seconds": 300,
  "waited_seconds": 301,
  "auth_required": true
}
```

### 5.3. Timeout Handling

```swift
// Timeout sonrasi kullaniciya bilgi verin
extension AppDelegate: PaylisherDeepLinkHandler {

    func paylisherDeepLinkDidFail(_ error: Error, url: URL?) {
        // Timeout hatasi kontrolu
        if error.localizedDescription.contains("timeout") {
            print("⏱️ Pending deeplink timeout oldu")

            // Kullaniciya mesaj goster
            showAlert(
                title: "Zaman Asimi",
                message: "Link sureniz doldu. Lutfen tekrar deneyin."
            )

            // Ana sayfaya yonlendir
            showMainScreen()
        }
    }
}
```

---

## 6. ANALYTICS EVENTS

### 6.1. Auth-Related Events

SDK otomatik olarak su event'leri yakalar:

**"Deep Link Opened"** (Auth Required)
```json
{
  "event": "Deep Link Opened",
  "destination": "orders",
  "auth_required": true,
  "auth_from_url": false,
  "auth_from_config": true,
  "pending": true
}
```

**"Deep Link Completed"** (Auth Basarili)
```json
{
  "event": "Deep Link Completed",
  "destination": "orders",
  "time_to_complete": 45.3,
  "completed_at": "2025-01-08T12:30:00Z"
}
```

**"Deep Link Cancelled"** (Auth Iptal)
```json
{
  "event": "Deep Link Cancelled",
  "destination": "orders",
  "time_before_cancel": 23.1,
  "reason": "user_cancelled"
}
```

**"Deep Link Timeout"**
```json
{
  "event": "Deep Link Timeout",
  "destination": "orders",
  "timeout_seconds": 300,
  "waited_seconds": 301
}
```

### 6.2. Custom Auth Events

Kendi event'lerinizi ekleyin:

```swift
func showAuthenticationFlow(completion: @escaping (Bool) -> Void) {
    let loginVC = LoginViewController()

    loginVC.onLoginSuccess = { user in
        // Success event
        PaylisherSDK.shared.capture("Login Success From Deeplink", properties: [
            "login_method": user.loginMethod,
            "user_type": user.isNewUser ? "new" : "returning",
            "time_to_login": Date().timeIntervalSince(loginVC.startTime)
        ])

        completion(true)
    }

    loginVC.onLoginCancel = {
        // Cancel event
        PaylisherSDK.shared.capture("Login Cancelled From Deeplink", properties: [
            "time_before_cancel": Date().timeIntervalSince(loginVC.startTime),
            "screen": loginVC.currentScreen
        ])

        completion(false)
    }
}
```

---

## 7. SESSION YONETIMI

### 7.1. Token Expiration

Kullanici token'i suresi dolmussa:

```swift
func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
    if requiresAuth {
        // Token var mi kontrol et
        if UserManager.shared.hasValidToken() {
            // Token gecerli - direkt navigate et
            navigateToDestination(deepLink)
            return
        }

        // Token yok veya expired - auth flow baslat
        showAuthenticationFlow { success in
            // SDK otomatik handle edecek
        }
    }
}
```

### 7.2. Biometric Auth

Biometric auth destegi:

```swift
func showAuthenticationFlow(completion: @escaping (Bool) -> Void) {
    // Biometric auth mevcut mu?
    if BiometricAuthManager.shared.isAvailable {
        // Face ID / Touch ID ile hizli giris
        BiometricAuthManager.shared.authenticate { success in
            if success {
                print("✅ Biometric auth basarili")
                completion(true)
            } else {
                // Fallback: Normal giris
                self.showLoginScreen(completion: completion)
            }
        }
    } else {
        // Biometric yok - normal giris
        showLoginScreen(completion: completion)
    }
}
```

---

## 8. ERROR HANDLING

### 8.1. Auth Failures

```swift
loginVC.onLoginFailure = { error in
    print("❌ Giris hatasi: \(error)")

    // Kullaniciya mesaj goster
    self.showAlert(
        title: "Giris Hatasi",
        message: "Giris yapilamadi: \(error.localizedDescription)"
    )

    // Pending deeplink hala aktif - kullanici tekrar deneyebilir

    // Analytics
    PaylisherSDK.shared.capture("Login Failed From Deeplink", properties: [
        "error": error.localizedDescription,
        "attempt_count": loginVC.attemptCount
    ])
}
```

### 8.2. Network Errors

```swift
loginVC.onNetworkError = { error in
    print("🌐 Network hatasi: \(error)")

    // Kullaniciya mesaj goster
    self.showAlert(
        title: "Baglanti Hatasi",
        message: "Internet baglantinizi kontrol edin"
    )

    // Pending deeplink timeout'a kadar bekleyecek
    // Kullanici network duzeldikten sonra tekrar deneyebilir
}
```

---

## 9. TEST ETME

### 9.1. Test Senaryolari

**Senaryo 1: Giris Yapmis Kullanici**
```swift
// Test URL
uygulamaniz://orders

// Beklenen Sonuc:
// - requiresAuth = false (cunku zaten giris yapmis)
// - Direkt Siparislerim sayfasina gider
```

**Senaryo 2: Giris Yapmamis Kullanici**
```swift
// Test URL
uygulamaniz://orders

// Beklenen Sonuc:
// - requiresAuth = true
// - Giris ekrani gosterilir
// - Giris sonrasi otomatik Siparislerim'e gider
```

**Senaryo 3: Timeout**
```swift
// Config
deepLinkConfig.pendingDeepLinkTimeout = 10  // 10 saniye (test icin)

// Test URL
uygulamaniz://orders

// Beklenen Sonuc:
// - Giris ekrani acilir
// - 10 saniye bekle (giris yapma)
// - Timeout event'i yakalanir
// - Pending deeplink iptal edilir
```

### 9.2. Debug Logging

```swift
deepLinkConfig.debugLogging = true

// Console'da gormelisiniz:
/*
[PaylisherDeepLink] URL alindi: uygulamaniz://orders
[PaylisherDeepLink] Destination: orders
[PaylisherDeepLink] Auth required: true (from config)
[PaylisherDeepLink] Pending deeplink olusturuldu
[PaylisherDeepLink] Timeout timer baslatildi: 300 saniye
[PaylisherDeepLink] Auth flow callback cagirildi
... (kullanici giris yapiyor)
[PaylisherDeepLink] Auth basarili - pending deeplink tamamlaniyor
[PaylisherDeepLink] Event: Deep Link Completed
[PaylisherDeepLink] Navigate ediliyor: orders
*/
```

---

## 10. PRODUCTION BEST PRACTICES

### 10.1. Checklist

- [ ] Auth-required destination'lar tanimlandi
- [ ] Pending timeout uygun deger (5 dakika onerilir)
- [ ] Auth flow handler implement edildi
- [ ] Timeout handling eklendi
- [ ] Error handling tamamlandi
- [ ] Analytics event'leri kontrol edildi
- [ ] Session yonetimi dogru calistirildi
- [ ] Test edildi (giris var/yok, timeout, iptal)

### 10.2. User Experience

**UX Onerileri:**

1. **Pending Deeplink Gosterimi:**
```swift
// Giris ekraninda pending deeplink olduğunu gosterin
if PaylisherSDK.shared.hasPendingDeepLink() {
    loginVC.showBanner(
        "Siparislerinizi gormek icin giris yapin"
    )
}
```

2. **Progress Indicator:**
```swift
// Auth flow sirasinda progress gosterin
loginVC.showProgress(
    step: 1,
    total: 2,
    message: "Giris yapiliyor..."
)
```

3. **Timeout Warning:**
```swift
// Timeout yaklasirken kullaniciyi uyarin
if timeRemaining < 60 {
    loginVC.showWarning(
        "Link 1 dakika icinde sona erecek"
    )
}
```

### 10.3. Security

```swift
// Auth token'i guvenli saklama
KeychainManager.shared.saveToken(user.token)

// HTTPS kullanin (Universal Links icin)
// HTTP deeplink'lere izin vermeyin

// URL validation
func validateDeepLinkURL(_ url: URL) -> Bool {
    // Guvenli domain kontrolu
    guard let host = url.host else { return false }

    let safeDomains = [
        "link.uygulamaniz.com",
        "uygulamaniz.com"
    ]

    return safeDomains.contains(host)
}
```

---

## 11. SIKCA SORULAN SORULAR

### S: Pending deeplink ne kadar sure saklanir?

**C:** Varsayilan 5 dakika (300 saniye). Config'de degistirebilirsiniz:
```swift
deepLinkConfig.pendingDeepLinkTimeout = 600  // 10 dakika
```

### S: Kullanici giris yapmadan ciksa ne olur?

**C:** Pending deeplink timeout'a kadar bekler. Kullanici uygulamaya geri donup
giris yaparsa hala gecerlidir.

### S: Birden fazla pending deeplink olabilir mi?

**C:** Hayir. Her seferinde sadece bir pending deeplink saklanir. Yeni biri
gelirse eskisi override edilir.

### S: Deferred deeplink auth gerektiriyorsa?

**C:** Ayni sistem calisir. Deferred deeplink match bulunur, pending'e alinir,
kullanici giris yapar, sonra navigate edilir.

### S: Token expired ise ne olur?

**C:** Token kontrolunu handler'da yapin:
```swift
if requiresAuth || UserManager.shared.tokenExpired() {
    showAuthenticationFlow { ... }
}
```

---

## 12. DESTEK

Sorun yasiyorsaniz:

1. Debug logging'i acin
2. Log'lari inceleyin
3. Timeout degerini artirin (test icin)
4. Paylisher destek: support@paylisher.com

---

**Dokuman Versiyonu:** 1.0
**Son Guncelleme:** 08 Ocak 2025
**SDK Versiyonu:** 1.6.0+
