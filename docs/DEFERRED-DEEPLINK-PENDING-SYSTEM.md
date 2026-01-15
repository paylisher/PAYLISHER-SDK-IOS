# 🔧 Deferred Deeplink Pending System

## 📋 Problem

Deferred deeplink **başarıyla match oluyor** ancak **ilk yüklenmede navigation target henüz hazır olmadığı için** (TabBar, root view, vb.) yönlendirme yapılamıyor ve deeplink **kayboluyor**.

### Önceki Davranış (❌ Hatalı)

```
1. ✅ Deferred deeplink match bulunur
2. ✅ autoHandle = true → otomatik handle edilir
3. ✅ AppDelegate/SceneDelegate callback tetiklenir (paylisherDidReceiveDeepLink)
4. ❌ Callback içinde navigation target yoksa navigation başarısız olur
5. ❌ SDK deeplink'i pending'e YAZMAZ
6. ❌ hasPendingDeepLink() → false döner
7. ❌ Deeplink kaybolur
```

### Yeni Davranış (✅ Düzeltildi)

```
1. ✅ Deferred deeplink match bulunur
2. ✅ autoHandle = true → otomatik handle edilir
3. ✅ Callback tetiklenir
4. ✅ Callback içinde navigation target yoksa → setPendingDeepLink() çağrılır
5. ✅ SDK deeplink'i pending'e YAZAR
6. ✅ hasPendingDeepLink() → true döner
7. ✅ Navigation target hazır olunca → completePendingDeepLink() çağrılır
8. ✅ Navigation başarılı! 🎉
```

---

## 🛠️ SDK'da Yapılan Değişiklikler

### 1. `setPendingDeepLink()` Public Oldu

**Dosya:** `PaylisherDeepLinkManager.swift`

```swift
/// Set a deep link as pending for later processing
///
/// Use this when you receive a deep link but cannot navigate immediately.
@objc public func setPendingDeepLink(_ deepLink: PaylisherDeepLink) {
    // Implementation...
}
```

**Önceki durum:** `private func setPendingDeepLink(...)`
**Yeni durum:** `@objc public func setPendingDeepLink(...)`

### 2. İyileştirilmiş Debug Logları

**Dosya:** `PaylisherDeferredDeepLinkManager.swift`

```swift
if handled && self.config.debugLogging {
    if PaylisherDeepLinkManager.shared.hasPendingDeepLink() {
        hedgeLog("[PaylisherDeferredDeepLink] ⚠️ Deeplink stored as pending")
        hedgeLog("[PaylisherDeferredDeepLink] 💡 Call completePendingDeepLink() when ready")
    } else {
        hedgeLog("[PaylisherDeferredDeepLink] ✅ Deeplink handled successfully")
    }
}
```

---

## 📱 Implementation Guide

Bu sistem **tüm UI framework'lere** (UIKit, SwiftUI, vb.) uyumludur. Temel mantık aynıdır:

### Genel Akış

1. **Callback'de navigation kontrolü yap**
2. **Eğer navigation yapılamıyorsa → `setPendingDeepLink()` çağır**
3. **Navigation hazır olduğunda → `completePendingDeepLink()` çağır**

---

## 🎯 UIKit Implementation

### Senaryo: TabBar + Onboarding

#### 1️⃣ AppDelegate'de Handler Callback

```swift
extension AppDelegate: PaylisherDeepLinkHandler {

    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        print("🔗 [DeepLink] Callback: \(deepLink.destination)")

        // ✅ UIKit: Check if TabBarController is ready
        guard let tabBarController = window?.rootViewController as? UITabBarController else {
            print("🔗 [Navigation] ⚠️ TabBar not ready - storing as pending...")

            // ✅ Store deeplink for later processing
            PaylisherDeepLinkManager.shared.setPendingDeepLink(deepLink)
            return
        }

        // ✅ TabBar ready - navigate immediately
        print("🔗 [Navigation] ✅ Navigating to \(deepLink.destination)")
        navigateToDestination(deepLink.destination, in: tabBarController)
    }

    private func navigateToDestination(_ destination: String, in tabBar: UITabBarController) {
        switch destination {
        case "profile":
            tabBar.selectedIndex = 3
        case "wallet":
            tabBar.selectedIndex = 2
        case "home":
            tabBar.selectedIndex = 0
        default:
            print("⚠️ Unknown destination: \(destination)")
        }
    }
}
```

#### 2️⃣ Onboarding Son Sayfası (örn: UserInfoPage3VC)

```swift
class UserInfoPage3VC: UIViewController {

    @IBAction func continueButtonTapped(_ sender: UIButton) {
        // Onboarding tamamlandı - TabBar'a geçiyoruz
        let tabBarVC = MainTabBarController()

        // ⚠️ TabBar'ı göstermeden ÖNCE window'a set et
        if let window = view.window {
            window.rootViewController = tabBarVC
            window.makeKeyAndVisible()
        }

        // ✅ TabBar artık hazır - pending deeplink varsa işle
        // NOT: Bu çağrı MainTabBarController.viewDidAppear'da da yapılabilir
        if PaylisherDeepLinkManager.shared.hasPendingDeepLink() {
            print("🔗 [Onboarding] Pending deeplink found - completing...")
            PaylisherDeepLinkManager.shared.completePendingDeepLink()
        }
    }
}
```

#### 3️⃣ TabBarController (Alternatif Yöntem)

```swift
class MainTabBarController: UITabBarController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // ✅ TabBar hazır - pending deeplink varsa tamamla
        if PaylisherDeepLinkManager.shared.hasPendingDeepLink() {
            print("🔗 [TabBar] Completing pending deeplink...")

            // Bu, paylisherDidReceiveDeepLink() callback'ini TEKRAR tetikler
            // Ancak bu sefer TabBar hazır olduğu için navigation başarılı olur
            PaylisherDeepLinkManager.shared.completePendingDeepLink()
        }
    }
}
```

---

## 🎨 SwiftUI Implementation

### Senaryo: ContentView + Onboarding

#### 1️⃣ AppDelegate'de Handler Callback

```swift
class AppDelegate: NSObject, UIApplicationDelegate, PaylisherDeepLinkHandler {

    // Publisher for SwiftUI navigation
    static let deepLinkPublisher = PassthroughSubject<PaylisherDeepLink, Never>()

    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        print("🔗 [DeepLink] Callback: \(deepLink.destination)")

        // ✅ SwiftUI: Check if app scene is ready
        let hasActiveScene = UIApplication.shared.connectedScenes
            .contains(where: { $0.activationState == .foregroundActive })

        guard hasActiveScene else {
            print("🔗 [Navigation] ⚠️ Scene not ready - storing as pending...")

            // ✅ Store deeplink for later processing
            PaylisherDeepLinkManager.shared.setPendingDeepLink(deepLink)
            return
        }

        // ✅ Scene ready - publish to SwiftUI
        print("🔗 [Navigation] ✅ Publishing deeplink to SwiftUI")
        Self.deepLinkPublisher.send(deepLink)
    }
}
```

#### 2️⃣ Main App View

```swift
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isOnboardingComplete = false

    var body: some Scene {
        WindowGroup {
            if isOnboardingComplete {
                ContentView()
                    .onAppear {
                        // ✅ ContentView ready - check for pending deeplink
                        checkPendingDeepLink()
                    }
            } else {
                OnboardingView(onComplete: {
                    isOnboardingComplete = true
                })
            }
        }
    }

    private func checkPendingDeepLink() {
        if PaylisherDeepLinkManager.shared.hasPendingDeepLink() {
            print("🔗 [App] Pending deeplink found - completing...")
            PaylisherDeepLinkManager.shared.completePendingDeepLink()
        }
    }
}
```

#### 3️⃣ ContentView - Deeplink Subscriber

```swift
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            WalletView()
                .tabItem { Label("Wallet", systemImage: "wallet.pass") }
                .tag(1)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(2)
        }
        .onAppear {
            setupDeepLinkSubscription()
        }
    }

    private func setupDeepLinkSubscription() {
        AppDelegate.deepLinkPublisher
            .receive(on: DispatchQueue.main)
            .sink { deepLink in
                navigateToDestination(deepLink.destination)
            }
            .store(in: &cancellables)
    }

    private func navigateToDestination(_ destination: String) {
        switch destination {
        case "profile":
            selectedTab = 2
        case "wallet":
            selectedTab = 1
        case "home":
            selectedTab = 0
        default:
            print("⚠️ Unknown destination: \(destination)")
        }
    }
}
```

---

## 🔄 Akış Diyagramı

### UIKit + Onboarding Senaryosu

```
┌─────────────────────────────────────────────────┐
│ 1. App Launch (First Time)                     │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 2. SDK: Deferred deeplink match found          │
│    (diyetim://profile)                          │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 3. SDK: autoHandle = true                      │
│    → handleURL(diyetim://profile)               │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 4. SDK: Trigger callback                       │
│    → paylisherDidReceiveDeepLink()              │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 5. App: Check navigation target                │
│    ❌ TabBar not ready (onboarding)             │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 6. App: setPendingDeepLink(deepLink) ✅         │
│    💾 Stored in SDK                             │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 7. User: Complete onboarding screens           │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 8. App: Set TabBar as rootViewController       │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 9. TabBar: viewDidAppear()                      │
│    Check: hasPendingDeepLink() → true ✅        │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 10. TabBar: completePendingDeepLink()           │
│     → Triggers callback AGAIN                   │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 11. App: TabBar ready → Navigate to profile ✅  │
│     🎉 Success!                                 │
└─────────────────────────────────────────────────┘
```

---

## ✅ Test Senaryoları

### Test 1: Deferred Deeplink + Onboarding (UIKit)

**Adımlar:**
1. Uygulamayı sil (clean install)
2. Deeplink'e tıkla (örn: `myapp://profile`)
3. App Store'dan indir
4. İlk kez aç (onboarding gösterilir)
5. Onboarding'i tamamla
6. TabBar görünür

**Beklenen Sonuç:**
- ✅ TabBar göründükten sonra otomatik olarak **profile** tab'ına yönlendirilmeli
- ✅ Console logları:
  ```
  [PaylisherDeferredDeepLink] Match found!
  [Navigation] ⚠️ TabBar not ready - storing as pending...
  [TabBar] Completing pending deeplink...
  [Navigation] ✅ Navigating to profile
  ```

### Test 2: Deferred Deeplink + Onboarding (SwiftUI)

**Adımlar:**
1. Uygulamayı sil
2. Deeplink'e tıkla
3. App Store'dan indir
4. İlk kez aç
5. Onboarding'i tamamla
6. ContentView görünür

**Beklenen Sonuç:**
- ✅ ContentView göründükten sonra otomatik olarak ilgili tab'a yönlendirilmeli
- ✅ `hasPendingDeepLink()` → `true` olmalı
- ✅ `completePendingDeepLink()` çağrıldıktan sonra navigation gerçekleşmeli

### Test 3: Normal Deeplink (Uygulama Zaten Yüklü)

**Adımlar:**
1. Uygulama zaten yüklü ve TabBar zaten var
2. Deeplink'e tıkla

**Beklenen Sonuç:**
- ✅ Direkt olarak ilgili sayfaya yönlendirilmeli
- ✅ Pending sistem kullanılmamalı (çünkü TabBar zaten hazır)
- ✅ `hasPendingDeepLink()` → `false` olmalı

### Test 4: Match Olmazsa

**Adımlar:**
1. Uygulamayı sil
2. Deeplink **olmadan** doğrudan App Store'dan indir
3. İlk kez aç

**Beklenen Sonuç:**
- ✅ Normal şekilde onboarding gösterilmeli
- ✅ Onboarding sonrası Home'a yönlendirilmeli
- ✅ `hasPendingDeepLink()` → `false` olmalı

---

## 📚 API Referansı

### `setPendingDeepLink(_ deepLink: PaylisherDeepLink)`

Deeplink'i pending olarak saklar. Navigation target hazır olmadığında kullanılır.

**Ne zaman kullanılır:**
- TabBar/root view henüz yüklenmediğinde
- Onboarding sürüyor ve henüz tamamlanmadığında
- Herhangi bir nedenle navigation yapılamıyorsa

**Örnek:**
```swift
if !isNavigationTargetReady {
    PaylisherDeepLinkManager.shared.setPendingDeepLink(deepLink)
}
```

---

### `hasPendingDeepLink() -> Bool`

Pending deeplink olup olmadığını kontrol eder.

**Ne zaman kullanılır:**
- Navigation target hazır olduğunda kontrol için
- Debug/logging amaçlı

**Örnek:**
```swift
if PaylisherDeepLinkManager.shared.hasPendingDeepLink() {
    // Pending deeplink var, işle
}
```

---

### `getPendingDestination() -> String?`

Pending deeplink'in destination'ını döndürür.

**Ne zaman kullanılır:**
- Pending deeplink hakkında bilgi almak için
- Log/debug amaçlı

**Örnek:**
```swift
if let destination = PaylisherDeepLinkManager.shared.getPendingDestination() {
    print("Pending destination: \(destination)")
}
```

---

### `completePendingDeepLink()`

Pending deeplink'i işler. `paylisherDidReceiveDeepLink()` callback'ini **tekrar tetikler**.

**Ne zaman kullanılır:**
- TabBar/root view hazır olduğunda
- Onboarding tamamlandıktan sonra

**⚠️ UYARI:** Bu metod callback'i tekrar tetikler. İkinci callback'de navigation target hazır olmalıdır.

**Örnek:**
```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if PaylisherDeepLinkManager.shared.hasPendingDeepLink() {
        PaylisherDeepLinkManager.shared.completePendingDeepLink()
    }
}
```

---

### `clearPendingDeepLink()`

Pending deeplink'i iptal eder (silme işlemi).

**Ne zaman kullanılır:**
- Kullanıcı navigation'ı iptal ettiyse
- Hatalı durumlarda cleanup için

**Örnek:**
```swift
// User cancelled onboarding
PaylisherDeepLinkManager.shared.clearPendingDeepLink()
```

---

## 🐛 Debug İpuçları

### 1. Pending Deeplink Yazıldı mı?

```swift
print("Has pending: \(PaylisherDeepLinkManager.shared.hasPendingDeepLink())")
print("Destination: \(PaylisherDeepLinkManager.shared.getPendingDestination() ?? "none")")
```

### 2. SDK Debug Logging'i Aç

```swift
config.deferredDeepLinkConfig?.debugLogging = true
PaylisherDeepLinkManager.shared.config.debugLogging = true
```

### 3. Console Logları - Başarılı Akış

```
[PaylisherDeferredDeepLink] Match found!
[DeepLinkHandler] Callback: profile
[Navigation] ⚠️ TabBar not ready - storing as pending...
[PaylisherDeferredDeepLink] ⚠️ Deeplink stored as pending
[TabBar] Completing pending deeplink...
[DeepLinkHandler] Callback: profile (SECOND TIME)
[Navigation] ✅ Navigating to profile
```

### 4. Console Logları - Başarısız Akış (Eski Bug)

```
[PaylisherDeferredDeepLink] Match found!
[DeepLinkHandler] Callback: profile
[Navigation] ⚠️ TabBar not ready
[TabBar] Has pending: false  ❌ Kayboldu!
```

---

## 💡 Best Practices

### ✅ DO

1. **Her zaman navigation target kontrolü yap**
   ```swift
   guard let tabBar = window?.rootViewController as? UITabBarController else {
       setPendingDeepLink(deepLink)
       return
   }
   ```

2. **Pending check'i en geç noktada yap**
   - UIKit: `TabBarController.viewDidAppear()`
   - SwiftUI: `ContentView.onAppear()`

3. **Debug logging'i development'ta aç**
   ```swift
   config.deferredDeepLinkConfig?.debugLogging = true
   ```

4. **Timeout süresini ayarla** (optional)
   ```swift
   PaylisherDeepLinkManager.shared.config.pendingDeepLinkTimeout = 60.0 // 60 saniye
   ```

### ❌ DON'T

1. **Callback'i birden fazla kez manuel çağırma**
   - `completePendingDeepLink()` zaten callback'i tetikler

2. **Pending check'i çok erken yapma**
   - TabBar/root view tam yüklenmeden çağırma

3. **Production'da debug logging açık bırakma**
   ```swift
   #if DEBUG
   config.deferredDeepLinkConfig?.debugLogging = true
   #endif
   ```

---

## 🚀 Özet

### SDK Tarafı (✅ Tamamlandı)

- ✅ `setPendingDeepLink()` public oldu
- ✅ Debug logları iyileştirildi
- ✅ Timeout mekanizması mevcut
- ✅ Framework-agnostic API

### Uygulama Tarafı (Entegrasyon Gerekli)

1. **Callback'de navigation target kontrolü yap**
2. **Hazır değilse `setPendingDeepLink()` çağır**
3. **Hazır olduğunda `completePendingDeepLink()` çağır**

**Sonuç:** Deferred deeplink artık onboarding senaryosunda kaybolmuyor! 🎉

---

**Son güncelleme:** 2026-01-15
**SDK versiyon:** 3.x+
**Uyumlu framework'ler:** UIKit, SwiftUI, tüm iOS framework'leri
