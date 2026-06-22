# Paylisher iOS — Deeplink Entegrasyon Rehberi

Bu rehber, Paylisher iOS SDK ile **deeplink (derin bağlantı)** entegrasyonunu sıfırdan, adım
adım anlatır. Amaç: bir kullanıcı bir kampanya/bildirim linkine tıkladığında uygulamanın
açılması ve **doğru ekrana** yönlenmesi.

> **Bu rehberi kim takip etmeli?** Uygulamayı geliştiren iOS ekibi. Her adımın başında "ne
> yapılacağı", ortasında "kod", sonunda "neden/dikkat" notu vardır. Sırayla ilerleyin.

---

## İçindekiler

1. [Nasıl çalışır? (zihinsel model)](#1-nasıl-çalışır-zihinsel-model)
2. [Başlamadan önce (ön koşullar ve kararlar)](#2-başlamadan-önce)
3. [Adım 1 — SDK'yı projeye ekle](#adım-1--sdkyı-projeye-ekle)
4. [Adım 2 — Custom URL scheme tanıt (Info.plist)](#adım-2--custom-url-scheme-tanıt-infoplist)
5. [Adım 3 — Universal Link tanıt (entitlements + AASA)](#adım-3--universal-link-tanıt-entitlements--aasa)
6. [Adım 4 — SDK'yı yapılandır ve başlat](#adım-4--sdkyı-yapılandır-ve-başlat)
7. [Adım 5 — Gelen linkleri SDK'ya ilet](#adım-5--gelen-linkleri-sdkya-ilet)
8. [Adım 6 — Handler closure'larını bağla](#adım-6--handler-closurelarını-bağla)
9. [Adım 7 — DeepLink Route sınıfını tasarla (kalp)](#adım-7--deeplink-route-sınıfını-tasarla)
10. [Adım 8 — Router'ı ekranlara bağla](#adım-8--routerı-ekranlara-bağla)
11. [Adım 9 — Deferred deeplink (ilk kurulum)](#adım-9--deferred-deeplink-ilk-kurulum)
12. [Adım 10 — Studio'da link oluştur](#adım-10--studioda-link-oluştur)
13. [Doğrulama ve test](#doğrulama-ve-test)
14. [Sık karşılaşılan sorunlar](#sık-karşılaşılan-sorunlar)
15. [Ek: PaylisherDeepLink nesnesi](#ek-paylisherdeeplink-nesnesi)
16. [Entegrasyon kontrol listesi](#entegrasyon-kontrol-listesi)

---

## 1. Nasıl çalışır? (zihinsel model)

Deeplink'in çalışması demek, **dört katmanın aynı kelimeler üzerinde anlaşması** demektir:

| Katman | Nerede tanımlanır | Görevi |
|---|---|---|
| **1. iOS kaydı** | `Info.plist` + `.entitlements` | Hangi URL'in uygulamayı **açacağına** karar verir |
| **2. SDK** | SDK kodu (hazır) | Gelen URL'i `pathSegments`'e **normalize eder** |
| **3. Route sınıfı** | Sizin `DeepLinkRouter`'ınız | `pathSegments` → **hangi ekran** |
| **4. Studio** | Linki oluştururken | Linkin **hedef yolu** Route sınıfıyla aynı olmalı |

Tek bir akışta görelim — kullanıcı `https://links.firma.com/products/a` linkine tıkladığında:

```
Link tıklanır
   │
   ▼
iOS linki uygulamaya verir            ← Katman 1 (Info.plist / entitlements + AASA)
   │
   ▼
AppDelegate → PaylisherSDK.shared.handleDeepLink / handleUserActivity
   │
   ▼
SDK URL'i parse eder → pathSegments = ["products","a"]   ← Katman 2 (SDK, hazır)
   │
   ▼
onDeepLink closure → DeepLinkRouter.handleReceived(...)
   │
   ▼
DeepLinkRouter.parseTarget → tab = .products, ürün id = "a"   ← Katman 3 (sizin kodunuz)
   │
   ▼
@Published durum değişir → SwiftUI "Ürün A" ekranını açar
```

> **En önemli kural:** Bir deeplink ya hiç açılmaz (Katman 1 eksik), ya açılır ama yanlış ekrana
> düşer (Katman 3 ↔ 4 uyuşmazlığı — Studio'daki yol ile Route sınıfındaki kelime farklı). Başka
> türlü "bozulma" neredeyse yoktur.

---

## 2. Başlamadan önce

### 2.1 Ön koşullar

- Uygulamanın **Bundle Identifier**'ı (örn. `com.firma.app`).
- **Apple Developer** hesabı (Universal Link için gerekli; sadece custom scheme kullanacaksanız
  şart değil).
- Paylisher Studio projesinden alınan **API Key** ve **host** adresi.

### 2.2 Başlamadan 3 karar verin

1. **Custom scheme** seçin: örn. `firmaapp` → `firmaapp://...` linkleri uygulamayı açar.
2. **Universal Link domain'i** seçin (önerilir): örn. `links.firma.com`.
3. **Yol sözlüğü** belirleyin — her ekrana bir kelime:

   | Ekran | Yol | Örnek link |
   |---|---|---|
   | Ana sayfa | `home` | `firmaapp://home` |
   | Ürün detayı | `products/<id>` | `firmaapp://products/a` |
   | Cüzdan (login ister) | `wallet` | `firmaapp://wallet` |
   | Profil | `profile` | `firmaapp://profile` |

   > Bu kelimeler **sizin belirlediğiniz** tanımlayıcılardır; Türkçe de olabilir (`urunler/a`).
   > Tek şart: Route sınıfı ile Studio'daki link hedefi **aynı kelimeyi** kullanmalı.

> **En hızlı kanıt için önce sadece custom scheme ile başlayın.** Universal Link ek sunucu
> kurulumu (AASA dosyası) ister. Scheme anında çalışır; Universal Link'i sonra eklersiniz.

---

## Adım 1 — SDK'yı projeye ekle

**Ne yapılır:** Xcode → *File ▸ Add Package Dependencies* → Paylisher iOS SDK repo URL'i girilir,
`Paylisher` kütüphanesi uygulama target'ına eklenir.

```
https://github.com/paylisher/PAYLISHER-SDK-IOS
```

**Not:** Sürümü sabit bir tag/branch'e sabitleyin. CocoaPods kullanıyorsanız `pod 'Paylisher'`
satırını `Podfile`'a ekleyip `pod install` çalıştırın.

---

## Adım 2 — Custom URL scheme tanıt (Info.plist)

**Ne yapılır:** Uygulamanın `Info.plist` dosyasına seçtiğiniz scheme'i ekleyin. Bu, iOS'a
"`firmaapp://` ile başlayan linkler benim uygulamamı açsın" demenin yoludur.

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.firma.app</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>firmaapp</string>
    </array>
  </dict>
</array>
```

**Neden:** Bu olmadan `firmaapp://...` linkleri uygulamayı **hiç açmaz**.

---

## Adım 3 — Universal Link tanıt (entitlements + AASA)

> Opsiyonel ama prodüksiyon için önerilir. Sadece custom scheme ile devam edecekseniz bu adımı
> atlayıp Adım 4'e geçebilirsiniz.

Universal Link, `https://links.firma.com/products/a` gibi **gerçek bir https linki**nin
uygulamayı açmasını sağlar (tarayıcı yerine). İki parçası vardır:

### 3.1 Uygulama tarafı — `.entitlements`

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:links.firma.com</string>
</array>
```

### 3.2 Sunucu tarafı — AASA dosyası

`https://links.firma.com/.well-known/apple-app-site-association` adresinde, içinde uygulamanızın
**`TEAMID.bundleId`**'si ve izinli yolların olduğu bir dosya yayınlanmalı:

```json
{
  "applinks": {
    "details": [
      {
        "appID": "ABCDE12345.com.firma.app",
        "paths": ["/products/*", "/wallet/*", "/profile/*", "/home/*"]
      }
    ]
  }
}
```

**Dikkat:**
- Domain Paylisher'a aitse, Paylisher ekibinden uygulamanızın `appID`'sini ve yollarını bu dosyaya
  **eklemelerini** isteyin (üzerine yazma — **merge**). Kendi domain'iniz ise dosyayı kendi
  sunucunuza koyun.
- AASA dosyası `Content-Type: application/json` ile ve **yönlendirmesiz** sunulmalı.
- iOS bu dosyayı **kurulum anında** çeker. Değişiklikten sonra uygulamayı **silip yeniden kurun**.

---

## Adım 4 — SDK'yı yapılandır ve başlat

**Ne yapılır:** Uygulama açılışında (`AppDelegate`) SDK'yı yapılandırın. Deeplink ayarları
`setup()` çağrısından **önce** verilmeli. `setup()` deeplink yöneticisini **otomatik** başlatır —
ayrıca bir `initialize()` çağrısına gerek yoktur.

```swift
import Paylisher

private func setupPaylisher() {
    // 1) Temel config
    let config = PaylisherConfig(
        apiKey: "<PROJE_API_KEY>",            // Paylisher Studio'dan
        host:   "https://<paylisher-host>"    // Paylisher Studio'dan
    )
    config.debug = true   // entegrasyon sırasında logları görmek için

    // 2) Deeplink config (setup ÖNCESİ)
    let deepLinkConfig = PaylisherDeepLinkConfig()
    deepLinkConfig.customSchemes            = ["firmaapp"]
    deepLinkConfig.universalLinkDomains     = ["links.firma.com"]
    deepLinkConfig.authRequiredDestinations = ["wallet"]   // login isteyen ekran(lar)
    deepLinkConfig.debugLogging             = true
    config.deepLinkConfig = deepLinkConfig

    // 3) Deferred deeplink config (ilk kurulum attribution — opsiyonel)
    config.deferredDeepLinkConfig = PaylisherDeferredDeepLinkConfig()
        .withEnabled(true)
        .withAPIHost("https://<paylisher-host>/v1/deferred-deeplink")
        .withAttributionWindow(2 * 60 * 60 * 1000)   // 2 saat (ms)
        .withAutoHandle(true)

    // 4) Başlat (deeplink yöneticisi burada otomatik kurulur)
    PaylisherSDK.shared.setup(config)

    // 5) Handler closure'ları (Adım 6)
    PaylisherSDK.shared.onDeepLink { deepLink, requiresAuth in
        DeepLinkRouter.shared.handleReceived(deepLink, requiresAuth: requiresAuth)
    }
    PaylisherSDK.shared.onDeepLinkRequiresAuth { deepLink, completion in
        DeepLinkRouter.shared.handleAuthRequired(deepLink, completion: completion)
    }
    PaylisherSDK.shared.onDeepLinkFailed { url, error in
        DeepLinkRouter.shared.handleFailure(url, error: error)
    }

    // 6) İlk açılışta deferred kontrolü (Adım 9)
    DeepLinkRouter.shared.runDeferredCheck()
}
```

**Notlar:**
- `authRequiredDestinations`: bu listedeki yol adlarına gelen deeplink'ler, kullanıcı login
  olmadan açılmaz (bkz. Adım 7.4). Listede yoksa link doğrudan açılır.
- `customSchemes` / `universalLinkDomains` alanları bilgilendirme amaçlıdır; URL'in uygulamaya
  ulaşmasını belirleyen asıl şey **Adım 2 ve 3**'tür (Info.plist + entitlements). Yine de okunabilirlik
  için doldurun.

---

## Adım 5 — Gelen linkleri SDK'ya ilet

**Ne yapılır:** iOS bir deeplink'i uygulamaya teslim ettiğinde, onu SDK'ya iletmeniz gerekir. İki
yol vardır — projeniz UIKit `AppDelegate` mı SwiftUI `App` mı kullanıyor, ona göre.

### 5.1 UIKit / AppDelegate

```swift
// Custom scheme: firmaapp://...   (cold + warm açılışta tek giriş noktası)
func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    return PaylisherSDK.shared.handleDeepLink(url)
}

// Universal Link: https://links.firma.com/...
func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    return PaylisherSDK.shared.handleUserActivity(userActivity)
}
```

### 5.2 SwiftUI (iOS 14+)

Ana View'a tek satırlık modifier yeterlidir; `onOpenURL` + `onContinueUserActivity`'yi sizin yerinize bağlar:

```swift
WindowGroup {
    ContentView()
        .paylisherDeepLinks()
}
```

> **Dikkat (UIKit):** `launchOptions[.url]`'i ayrıca işlemeyin. iOS, cold launch'ta da `open:`
> metodunu çağırır; ikisini birden işlerseniz aynı deeplink **iki kez** işlenir.

---

## Adım 6 — Handler closure'larını bağla

**Ne yapılır:** SDK, bir deeplink'i parse ettikten sonra size üç closure üzerinden haber verir.
Bir protokol implement etmenize gerek yoktur — sadece closure verin (Adım 4'te yapıldı):

| Closure | Ne zaman çağrılır | Ne yapmalı |
|---|---|---|
| `onDeepLink` | Link alınıp parse edildiğinde | Route sınıfına ilet → yönlendir |
| `onDeepLinkRequiresAuth` | Hedef login istiyorsa | Login akışını başlat, sonucu `completion`'a bildir |
| `onDeepLinkFailed` | Link parse edilemezse | (Opsiyonel) logla |

Bu closure'lar gelen veriyi **Route sınıfına** (Adım 7) yönlendirir.

---

## Adım 7 — DeepLink Route sınıfını tasarla

Bu, entegrasyonun **kalbidir**. `DeepLinkRouter`, hem SDK'dan gelen deeplink'leri karşılayan hem de
uygulamanın **merkezi navigasyon durumunu** tutan tek bir sınıftır.

### 7.1 Tasarım ilkeleri (neden böyle?)

1. **Merkezi, gözlemlenebilir durum (`ObservableObject`).** Navigasyon hedefi (`selectedTab`, iç
   içe yollar) `@Published` olarak tutulur; ekranlar bunu dinler. Böylece **cold-start** çalışır:
   uygulama login ekranındayken gelen deeplink durumu yazar, ana ekran açıldığında otomatik uygulanır.
2. **Yolu SDK'nın `pathSegments`'inden okuruz.** SDK, custom scheme ve Universal Link için **aynı**
   diziyi verir:
   - `firmaapp://products/a` → `["products","a"]`
   - `https://links.firma.com/products/a` → `["products","a"]`

   İkisi de aynı olduğu için Route sınıfı tek yerde, ham URL'i tekrar ayrıştırmadan karar verir.
3. **Yol → ekran eşlemesi = ekran "etiketleme".** Her ekrana bir kelime verirsiniz; `parseTarget`
   bu kelimeyi sekme/ekran durumuna çevirir. Yeni bir ekran "etiketlemek" = `parseTarget`'a bir
   `case` eklemek + Studio'da aynı kelimeyi kullanmak.

### 7.2 `parseTarget` — yol → ekran eşlemesi

İşin özü budur. Gelen `pathSegments`'in **ilk** kelimesine göre hedef sekme/ekran belirlenir;
sonraki segmentler id gibi parametrelerdir.

```swift
static func parseTarget(_ deepLink: PaylisherDeepLink) -> NavTarget? {
    let segs = deepLink.pathSegments     // örn. ["products","a"]
    switch segs.first?.lowercased() {
    case nil, "home":
        return NavTarget(tab: .home)
    case "products", "product":
        // ikinci segment ürün id'si; yoksa ?id= parametresinden al
        if let id = segs.dropFirst().first ?? deepLink.parameters["id"] {
            return NavTarget(tab: .products, productsPath: [.detail(id)])
        }
        return NavTarget(tab: .products)
    case "wallet":
        return NavTarget(tab: .wallet)
    case "profile":
        return NavTarget(tab: .profile)
    default:
        return NavTarget(tab: .home)     // tanınmayan yol → güvenli varsayılan
    }
}
```

> **Bu kelimeleri (`home`, `products`, `wallet`, `profile`) kendi ekranlarınıza göre değiştirin.**
> Önemli olan: Studio'da oluşturduğunuz linkin hedef yolu, buradaki `case`'lerle birebir aynı olmalı.

### 7.3 Auth-gate — login isteyen ekranlar

`authRequiredDestinations` listesindeki bir ekrana deeplink geldiğinde, SDK önce
`onDeepLinkRequiresAuth`'ı çağırır. Akış:

- Kullanıcı **zaten login'liyse** → `completion(true)` ile anında geçilir.
- **Login değilse** (örn. uygulamayı kapatıp linke tıklamış) → `completion` saklanır, uygulama
  kendi login ekranını gösterir; login başarılı olunca saklanan `completion(true)` tetiklenir ve
  SDK deeplink'i tamamlayıp hedef ekrana yönlendirir.

Bu, klasik "korumalı ekrana deeplink → önce login → sonra o ekrana git" davranışını verir.

### 7.4 Tam Route sınıfı (prodüksiyon)

Aşağıdaki sınıf, doğrudan kopyalanıp ekran adları/yolları kendinize göre uyarlanacak şekilde
hazırlanmıştır. (Debug log, test kampanya anahtarı gibi manuel-test parçaları **dahil değildir**.)

```swift
import Foundation
import SwiftUI
import Paylisher

// Uygulamadaki ana ekranlar/sekmeler — kendi ekranlarınızla değiştirin
enum AppTab {
    case home, products, wallet, profile
}

// Ürünler sekmesinin iç içe yolu (liste → detay). Daha derin seviye gerekiyorsa genişletin.
enum ProductRoute: Hashable {
    case detail(String)   // ürün id
}

// Bir deeplink'in çözümlendiği hedef
struct NavTarget {
    let tab: AppTab
    var productsPath: [ProductRoute] = []
}

final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    private init() {}

    // --- Navigasyon durumu (UI bunu dinler) ---
    @Published var selectedTab: AppTab = .home
    @Published var productsPath: [ProductRoute] = []

    // --- Uygulama login durumu (auth-gate için) ---
    @Published var isAuthenticated: Bool = false
    private var pendingAuthCompletion: ((Bool) -> Void)?

    // MARK: - SDK closure'larının yönlendirdiği metodlar

    func handleReceived(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        // requiresAuth=true ise henüz yönlenme; SDK auth tamamlanınca bu metodu
        // requiresAuth=false ile tekrar çağırır.
        if !requiresAuth { navigate(deepLink) }
    }

    func handleAuthRequired(_ deepLink: PaylisherDeepLink, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            if self.isAuthenticated {
                completion(true)                         // zaten login → direkt geç
            } else {
                self.pendingAuthCompletion = completion  // login yok → login'i bekle
            }
        }
    }

    func handleFailure(_ url: URL, error: Error?) {
        // Opsiyonel: parse edilemeyen linkleri kendi log altyapınıza yazabilirsiniz.
    }

    // MARK: - Navigasyon

    func navigate(_ deepLink: PaylisherDeepLink) {
        guard let target = Self.parseTarget(deepLink) else { return }
        DispatchQueue.main.async {
            self.selectedTab = target.tab
            if target.tab == .products { self.productsPath = target.productsPath }
        }
    }

    // Yol → ekran eşlemesi (ekran "etiketleme")
    static func parseTarget(_ deepLink: PaylisherDeepLink) -> NavTarget? {
        let segs = deepLink.pathSegments     // örn. ["products","a"]
        switch segs.first?.lowercased() {
        case nil, "home":
            return NavTarget(tab: .home)
        case "products", "product":
            if let id = segs.dropFirst().first ?? deepLink.parameters["id"] {
                return NavTarget(tab: .products, productsPath: [.detail(id)])
            }
            return NavTarget(tab: .products)
        case "wallet":
            return NavTarget(tab: .wallet)
        case "profile":
            return NavTarget(tab: .profile)
        default:
            return NavTarget(tab: .home)
        }
    }

    // İç içe ekranda geri (manuel stack)
    func popProduct() { if !productsPath.isEmpty { productsPath.removeLast() } }

    // MARK: - Auth (uygulama login'i)

    /// Login/logout'ta çağrılır. Login olunca, login'i bekleyen (cold-start) bir auth-gate
    /// deeplink'i varsa onu tamamlar → SDK hedef ekrana yönlendirir.
    func setAuthenticated(_ value: Bool) {
        isAuthenticated = value
        if value, let completion = pendingAuthCompletion {
            pendingAuthCompletion = nil
            completion(true)
        }
    }

    // MARK: - Deferred deeplink (ilk kurulum)

    func runDeferredCheck() {
        PaylisherSDK.shared.checkDeferredDeepLink(
            onSuccess: { [weak self] deepLink in self?.navigate(deepLink) },
            onNoMatch: { /* organik kurulum — yapılacak bir şey yok */ },
            onError:   { _ in /* opsiyonel: logla */ }
        )
    }
}
```

> **İç içe ekranlar (manuel stack) hakkında:** iç içe navigasyonu (liste → detay → içerik)
> `productsPath` gibi bir dizi olarak tutmak, deeplink ile gelen derin hedeflerde (cold-start dahil)
> en sağlam yöntemdir. `parseTarget` tam yolu döndürür, UI da o yolu render eder. Tek seviyeli
> ekranlarınız varsa `productsPath`'e hiç ihtiyacınız olmaz.

---

## Adım 8 — Router'ı ekranlara bağla

**Ne yapılır:** Ana ekran, Route sınıfının `@Published` durumunu dinler. Sekme seçimi `selectedTab`'e
bağlanır; login/logout olunca `setAuthenticated` çağrılır.

```swift
struct RootTabView: View {
    @ObservedObject var router = DeepLinkRouter.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView().tag(AppTab.home)
            ProductsView().tag(AppTab.products)     // productsPath'i bu ekran kullanır
            WalletView().tag(AppTab.wallet)
            ProfileView().tag(AppTab.profile)
        }
    }
}
```

Login başarılı olduğunda ve çıkış yapıldığında durum güncellenir:

```swift
// Login başarılı:
DeepLinkRouter.shared.setAuthenticated(true)

// Çıkış (logout):
DeepLinkRouter.shared.setAuthenticated(false)
```

**Neden:** Deeplink, uygulama login ekranındayken bile gelebilir. Hedef `selectedTab`/`productsPath`
durumuna yazıldığı için, kullanıcı login olup ana ekrana geçtiğinde doğru ekran otomatik açılır.

---

## Adım 9 — Deferred deeplink (ilk kurulum)

**Ne işe yarar:** Uygulama **henüz kurulu değilken** tıklanan link, kullanıcıyı App Store'a
götürür. Kurulumdan sonraki ilk açılışta SDK, o tıklamayla eşleşme arar ve bulursa kullanıcıyı
doğru ekrana yönlendirir.

Adım 4'te config verildi ve açılışta `runDeferredCheck()` çağrıldı. Kontrol mantığı Route sınıfında:

```swift
func runDeferredCheck() {
    PaylisherSDK.shared.checkDeferredDeepLink(
        onSuccess: { [weak self] deepLink in self?.navigate(deepLink) },  // eşleşme → yönlendir
        onNoMatch: { },                                                   // organik kurulum
        onError:   { _ in }
    )
}
```

**Not:** Deferred eşleşme **ilk kurulumda bir kez** anlamlıdır. `withAttributionWindow` ile tıklama
ile kurulum arası kabul edilen süreyi belirlersiniz (örnekte 2 saat).

---

## Adım 10 — Studio'da link oluştur

**Ne yapılır:** Paylisher Studio'da kampanya/link oluştururken, linkin **hedef yolu** Route
sınıfındaki kelimelerle **birebir aynı** olmalı.

- Scheme hedefi: `firmaapp://products/a`
- veya Universal Link hedefi: `https://links.firma.com/products/a`

Studio kısa link / bridge üretiyorsa, o bridge'in **bu** hedefe çözmesi gerekir. Çözülen hedefin
yolu Route sınıfında tanımlı değilse, kullanıcı ana sayfaya düşer.

> **Bridge sayfası nedir?** Kısa linkler (`.../<key>/bridge`) bir **web** sayfasıdır; tarayıcıda
> açılır ve uygulama kuruluysa uygulamanın **kayıtlı olduğu** gerçek hedefi (scheme veya Universal
> Link) tetikler, kurulu değilse App Store'a yönlendirir. Yani uygulamanız bridge URL'ini değil,
> bridge'in teslim ettiği **son hedefi** görür.

---

## Doğrulama ve test

`debugLogging = true` açıkken, Xcode konsolunda her gelen link için şu satırı arayın:

```
[PaylisherDeepLink] Handling URL: <gelen-url>
```

| Belirti | Olası neden | Çözüm |
|---|---|---|
| Bu satır **hiç çıkmıyor** | iOS linki uygulamaya vermiyor | Adım 2 (scheme) / Adım 3 (entitlements + AASA) eksik |
| Satır çıkıyor **ama ana sayfaya düşüyor** | Yol ile `parseTarget` uyuşmuyor | Studio hedefini ya da `parseTarget` `case`'ini eşitleyin |
| Universal Link uygulamayı açmıyor, Safari açılıyor | AASA yok/yanlış | Dosyayı düzeltin, uygulamayı **silip yeniden kurun** |

**Test senaryoları:**
1. **Warm start:** uygulama açıkken linke tıkla → doğru ekran.
2. **Cold start:** uygulamayı kapat, linke tıkla → uygulama açılır + doğru ekran.
3. **Auth-gate:** çıkış yap, korumalı ekrana (`wallet`) linkle gir → login ekranı → login sonrası
   o ekrana yönlenmeli.
4. **Deferred:** uygulamayı sil, linke tıkla, App Store'dan kur, aç → doğru ekran.

> Custom scheme'i simülatörde test ederken `xcrun simctl openurl booted "firmaapp://products/a"`
> kullanabilirsiniz (simülatörde "Open in App?" onayı çıkabilir; gerçek cross-app tıklamada çıkmaz).

---

## Sık karşılaşılan sorunlar

- **"Açılıyor ama yönlenmiyor."** Studio'daki yol (`/urunler/a`) ile `parseTarget`'ın beklediği
  (`/products/a`) farklı. Konsoldaki "Handling URL"e bakın, segment'i `parseTarget`'a ekleyin.
- **"Universal Link Safari'de açılıyor."** AASA dosyası yok ya da `appID` yanlış. Cihazı silip
  yeniden kurun (iOS AASA'yı kurulumda çeker).
- **Aynı link iki kez işleniyor.** UIKit'te `launchOptions[.url]`'i ayrıca işlemeyin; sadece
  `open:` / `continue:` yeterli.
- **Auth-gate'te login sonrası yönlenmiyor.** Login başarılı olunca `setAuthenticated(true)`
  çağrıldığından emin olun.

---

## Ek: PaylisherDeepLink nesnesi

`onDeepLink` / `navigate` içinde elinize gelen `deepLink` nesnesinin işinize yarayan alanları:

| Alan | Tip | Açıklama |
|---|---|---|
| `pathSegments` | `[String]` | Normalize yol parçaları — **routing için bunu kullanın** (`["products","a"]`) |
| `parameters` | `[String: String]` | Tüm sorgu parametreleri (`?id=a&utm_source=...`) |
| `url` | `URL` | Ham gelen URL (log için) |
| `scheme` | `String` | `firmaapp` veya `https` |
| `destination` | `String` | Ham hedef (eski API; `pathSegments` tercih edilir) |
| `campaignKeyName` | `String?` | Kısa link/kampanya anahtarı (varsa) |
| `campaignData` | `obj?` | Backend'den çözülen kampanya verisi (kısa linklerde, varsa) |
| `jid` | `String?` | Journey/attribution kimliği (varsa) |

---

## Entegrasyon kontrol listesi

- [ ] SDK projeye eklendi (SPM/CocoaPods)
- [ ] `Info.plist` → `CFBundleURLSchemes` içine custom scheme eklendi
- [ ] (Prod) `.entitlements` → `associated-domains` içine domain eklendi
- [ ] (Prod) Domain'in `.well-known/apple-app-site-association` dosyasında `TEAMID.bundleId` + yollar var
- [ ] `config.deepLinkConfig` **setup'tan önce** verildi; `authRequiredDestinations` dolduruldu
- [ ] `PaylisherSDK.shared.setup(config)` çağrıldı
- [ ] AppDelegate `open:` + `continue:` (veya SwiftUI `.paylisherDeepLinks()`) SDK'ya iletiyor
- [ ] `onDeepLink` / `onDeepLinkRequiresAuth` / `onDeepLinkFailed` bağlandı
- [ ] `DeepLinkRouter` oluşturuldu; `parseTarget` ekranlarınıza göre dolduruldu
- [ ] Ana ekran `selectedTab`'e bağlandı; login/logout `setAuthenticated` çağırıyor
- [ ] (Opsiyonel) Deferred config verildi; açılışta `runDeferredCheck()` çağrıldı
- [ ] Studio'daki link hedefi `parseTarget`'taki kelimelerle aynı
- [ ] Warm / cold / auth-gate / deferred senaryoları test edildi
