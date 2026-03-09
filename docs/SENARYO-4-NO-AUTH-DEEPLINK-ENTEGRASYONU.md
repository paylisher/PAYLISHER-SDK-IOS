# SENARYO 4: NO-AUTH DEEPLINK ENTEGRASYONU
# (Giris Gerektirmeyen Sayfalar icin Deeplink)

---

## GENEL BAKIS

Bu dokuman, **authentication (giris) gerektirmeyen** sayfalar icin deeplink
entegrasyonunu aciklar. Bu en basit ve en yaygin deeplink kullanim senaryosudur.

**Kullanim Senaryolari:**
- Urun detay sayfasi
- Kategori sayfasi
- Blog/Haber detayi
- Kampanya sayfasi
- Hakkimizda sayfasi
- Genel icerik sayfalari

**Ozellikler:**
- Auth gerektirm

ez - direkt navigate
- Hizli implementasyon
- Minimum kod
- Maksimum conversion

---

## 1. TEMEL SETUP

### 1.1. Info.plist Ayarlari

**URL Scheme:**

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

**Universal Links (Onerilen):**

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:link.uygulamaniz.com</string>
</array>
```

### 1.2. SDK Kurulumu

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

        // 2. Deeplink Konfigurasyonu (MINIMAL)
        let deepLinkConfig = PaylisherDeepLinkConfig()
        deepLinkConfig.customSchemes = ["uygulamaniz"]
        deepLinkConfig.universalLinkDomains = ["link.uygulamaniz.com"]

        config.deepLinkConfig = deepLinkConfig

        // 3. SDK'yi Baslat
        PaylisherSDK.shared.setup(config)

        // 4. Handler'i Kaydet
        PaylisherSDK.shared.setDeepLinkHandler(self)

        return true
    }
}
```

---

## 2. MINIMAL DEEPLINK HANDLER

### 2.1. En Basit Implementation

```swift
extension AppDelegate: PaylisherDeepLinkHandler {

    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        // Direkt navigate (auth gerektirmez)
        navigateToDestination(deepLink)
    }

    func navigateToDestination(_ deepLink: PaylisherDeepLink) {
        guard let navController = window?.rootViewController as? UINavigationController else {
            return
        }

        // Destination'a gore yonlendir
        switch deepLink.destination {

        case "product":
            // Urun detay: uygulamaniz://product?id=12345
            showProduct(deepLink, navController: navController)

        case "category":
            // Kategori: uygulamaniz://category?id=electronics
            showCategory(deepLink, navController: navController)

        case "promo":
            // Kampanya: uygulamaniz://promo?campaign=summer_sale
            showPromo(deepLink, navController: navController)

        case "blog":
            // Blog: uygulamaniz://blog?slug=new-feature-announcement
            showBlog(deepLink, navController: navController)

        default:
            // Bilinmeyen - ana sayfa
            navController.popToRootViewController(animated: true)
        }
    }
}
```

### 2.2. Navigation Helper Functions

```swift
extension AppDelegate {

    // Urun detay sayfasi
    func showProduct(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
        guard let productID = deepLink.parameters["id"] else {
            print("❌ Product ID eksik")
            return
        }

        let productVC = ProductDetailViewController()
        productVC.productID = productID

        // Query parametrelerini parse et
        if let variant = deepLink.parameters["variant"] {
            productVC.selectedVariant = variant
        }

        navController.pushViewController(productVC, animated: true)
    }

    // Kategori sayfasi
    func showCategory(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
        guard let categoryID = deepLink.parameters["id"] else {
            print("❌ Category ID eksik")
            return
        }

        let categoryVC = CategoryViewController()
        categoryVC.categoryID = categoryID

        // Opsiyonel: Sort/filter parametreleri
        categoryVC.sortBy = deepLink.parameters["sort"]
        categoryVC.filterBy = deepLink.parameters["filter"]

        navController.pushViewController(categoryVC, animated: true)
    }

    // Kampanya sayfasi
    func showPromo(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
        let promoVC = PromoViewController()

        // Campaign bilgileri
        promoVC.campaignID = deepLink.parameters["campaign"]
        promoVC.campaignKey = deepLink.campaignKeyName

        // Campaign data (SDK otomatik resolve eder)
        promoVC.campaignData = deepLink.campaignData

        navController.pushViewController(promoVC, animated: true)
    }

    // Blog detay sayfasi
    func showBlog(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
        guard let slug = deepLink.parameters["slug"] else {
            print("❌ Blog slug eksik")
            return
        }

        let blogVC = BlogDetailViewController()
        blogVC.articleSlug = slug

        navController.pushViewController(blogVC, animated: true)
    }
}
```

---

## 3. URL HANDLING

### 3.1. SceneDelegate (iOS 13+)

**SceneDelegate.swift:**

```swift
import UIKit
import Paylisher

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // Custom URL Scheme
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        PaylisherSDK.shared.handleDeepLink(url)
    }

    // Universal Links
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        PaylisherSDK.shared.handleDeepLink(url)
    }
}
```

### 3.2. AppDelegate (iOS 12-)

```swift
// Custom URL Scheme
func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return PaylisherSDK.shared.handleDeepLink(url)
}

// Universal Links
func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return false }
    return PaylisherSDK.shared.handleDeepLink(url)
}
```

---

## 4. COMMON PATTERNS

### 4.1. Modal vs Push Navigation

```swift
func navigateToDestination(_ deepLink: PaylisherDeepLink) {
    guard let navController = window?.rootViewController as? UINavigationController else {
        return
    }

    switch deepLink.destination {

    case "product":
        // Push navigation (geri donulebilir)
        let productVC = ProductDetailViewController()
        productVC.productID = deepLink.parameters["id"]
        navController.pushViewController(productVC, animated: true)

    case "promo":
        // Modal presentation (fullscreen kampanya)
        let promoVC = PromoViewController()
        promoVC.campaignKey = deepLink.campaignKeyName
        promoVC.modalPresentationStyle = .fullScreen
        navController.present(promoVC, animated: true)

    case "search":
        // Tab bar navigation
        if let tabBarController = navController as? UITabBarController {
            tabBarController.selectedIndex = 1  // Search tab
        }

    default:
        navController.popToRootViewController(animated: true)
    }
}
```

### 4.2. Tab Bar Navigation

```swift
func navigateToTabBarDestination(_ deepLink: PaylisherDeepLink) {
    guard let tabBarController = window?.rootViewController as? UITabBarController else {
        return
    }

    switch deepLink.destination {

    case "home":
        tabBarController.selectedIndex = 0

    case "search":
        tabBarController.selectedIndex = 1

        // Search query varsa set et
        if let searchVC = tabBarController.selectedViewController as? SearchViewController,
           let query = deepLink.parameters["q"] {
            searchVC.searchTextField.text = query
            searchVC.performSearch(query: query)
        }

    case "favorites":
        tabBarController.selectedIndex = 2

    case "cart":
        tabBarController.selectedIndex = 3

    case "profile":
        tabBarController.selectedIndex = 4

    default:
        tabBarController.selectedIndex = 0
    }
}
```

### 4.3. Nested Navigation

```swift
func navigateToNestedDestination(_ deepLink: PaylisherDeepLink) {
    // Ornek: Ana Sayfa -> Kategori -> Urun
    // URL: uygulamaniz://category/electronics/product/12345

    guard let navController = window?.rootViewController as? UINavigationController else {
        return
    }

    // Onceki ekranlari temizle
    navController.popToRootViewController(animated: false)

    // 1. Kategori sayfasini ac
    if let categoryID = deepLink.parameters["category"] {
        let categoryVC = CategoryViewController()
        categoryVC.categoryID = categoryID
        navController.pushViewController(categoryVC, animated: false)
    }

    // 2. Urun detay sayfasini ac
    if let productID = deepLink.parameters["id"] {
        let productVC = ProductDetailViewController()
        productVC.productID = productID
        navController.pushViewController(productVC, animated: true)
    }
}
```

---

## 5. PARAMETRE YONETIMI

### 5.1. Query Parameters

```swift
// URL: uygulamaniz://search?q=iPhone&sort=price&filter=instock

func showSearch(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
    let searchVC = SearchViewController()

    // Temel parametre
    searchVC.searchQuery = deepLink.parameters["q"] ?? ""

    // Sorting
    if let sortBy = deepLink.parameters["sort"] {
        searchVC.sortOption = SortOption(rawValue: sortBy) ?? .relevance
    }

    // Filtering
    if let filter = deepLink.parameters["filter"] {
        searchVC.applyFilter(filter)
    }

    navController.pushViewController(searchVC, animated: true)
}
```

### 5.2. Multiple Parameters

```swift
// URL: uygulamaniz://product?id=12345&color=red&size=L&qty=2

func showProduct(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
    guard let productID = deepLink.parameters["id"] else { return }

    let productVC = ProductDetailViewController()
    productVC.productID = productID

    // Tum varyantlari parse et
    let variants = deepLink.parameters.filter { key, _ in
        ["color", "size", "qty"].contains(key)
    }

    productVC.preSelectedVariants = variants

    navController.pushViewController(productVC, animated: true)
}
```

### 5.3. Array Parameters

```swift
// URL: uygulamaniz://compare?products=123,456,789

func showComparison(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
    guard let productsString = deepLink.parameters["products"] else { return }

    // Comma-separated list'i parse et
    let productIDs = productsString.split(separator: ",").map(String.init)

    let compareVC = ProductCompareViewController()
    compareVC.productIDs = productIDs

    navController.pushViewController(compareVC, animated: true)
}
```

---

## 6. CAMPAIGN INTEGRATION

### 6.1. Campaign Key Handling

SDK otomatik olarak campaign bilgilerini resolve eder:

```swift
func showPromo(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
    let promoVC = PromoViewController()

    // Campaign key (URL'den)
    promoVC.campaignKey = deepLink.campaignKeyName

    // Campaign data (Backend'den resolve edilir)
    if let campaignData = deepLink.campaignData {
        promoVC.campaignTitle = campaignData.title
        promoVC.campaignType = campaignData.type
        promoVC.expiresIn = campaignData.daysUntilExpire

        // Metadata'dan ozel alanlar
        if let discount = campaignData.metadata?["discount"] as? Int {
            promoVC.discountPercentage = discount
        }
    } else {
        // Campaign henuz resolve edilmedi - loading goster
        promoVC.showLoadingState()
    }

    navController.pushViewController(promoVC, animated: true)
}
```

### 6.2. Campaign URL Formats

```swift
// Format 1: Query parameter
uygulamaniz://promo?keyName=SUMMER_SALE_2025

// Format 2: Path
uygulamaniz://campaign/SUMMER_SALE_2025
uygulamaniz://c/SUMMER_SALE_2025

// Format 3: Direct (10+ karakter)
uygulamaniz://SUMMER_SALE_2025

// Hepsi ayni campaign'i acar
```

---

## 7. ANALYTICS & TRACKING

### 7.1. Otomatik Event'ler

SDK otomatik olarak event'leri yakalar:

```json
{
  "event": "Deep Link Opened",
  "destination": "product",
  "scheme": "uygulamaniz",
  "full_url": "uygulamaniz://product?id=12345",
  "parameters": {
    "id": "12345",
    "color": "red"
  },
  "campaign_key": "SUMMER_SALE",
  "jid": "journey_abc123"
}
```

### 7.2. Custom Tracking

```swift
func showProduct(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
    guard let productID = deepLink.parameters["id"] else { return }

    // Product sayfasini ac
    let productVC = ProductDetailViewController()
    productVC.productID = productID
    navController.pushViewController(productVC, animated: true)

    // Custom tracking event
    PaylisherSDK.shared.capture("Product Viewed From Deeplink", properties: [
        "product_id": productID,
        "source": deepLink.source ?? "direct",
        "referrer": deepLink.parameters["ref"] ?? "unknown",
        "has_campaign": deepLink.campaignKeyName != nil,
        "view_type": "deeplink"
    ])
}
```

### 7.3. Conversion Tracking

```swift
// Kullanici deeplink'ten gelip satin alim yapti
func userCompletedPurchase(orderID: String, total: Double) {
    // Journey ID var mi?
    if let jid = PaylisherJourneyContext.shared.getJourneyId(),
       let metadata = PaylisherJourneyContext.shared.getJourneyMetadata(),
       metadata["source"] as? String == "deeplink" {

        // Deeplink'ten gelen bir conversion
        PaylisherSDK.shared.capture("Purchase From Deeplink", properties: [
            "order_id": orderID,
            "total": total,
            "jid": jid,
            "time_since_deeplink_hours": metadata["age_hours"] ?? 0
        ])
    }
}
```

---

## 8. ERROR HANDLING

### 8.1. Missing Parameters

```swift
func showProduct(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
    // Required parameter kontrolu
    guard let productID = deepLink.parameters["id"] else {
        print("❌ Product ID bulunamadi")

        // Kullaniciya mesaj goster
        showAlert(
            title: "Hata",
            message: "Urun bilgisi bulunamadi"
        )

        // Ana sayfaya yonlendir
        navController.popToRootViewController(animated: true)

        // Analytics - hata tracking
        PaylisherSDK.shared.capture("Deeplink Parameter Missing", properties: [
            "destination": deepLink.destination,
            "missing_parameter": "id",
            "url": deepLink.url.absoluteString
        ])

        return
    }

    // Normal flow
    let productVC = ProductDetailViewController()
    productVC.productID = productID
    navController.pushViewController(productVC, animated: true)
}
```

### 8.2. Invalid Data

```swift
func showProduct(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
    guard let productID = deepLink.parameters["id"] else { return }

    // Product ID formatini validate et
    guard productID.count > 0 && productID.count < 20 else {
        print("❌ Gecersiz product ID: \(productID)")

        showAlert(
            title: "Hata",
            message: "Gecersiz urun kodu"
        )

        return
    }

    // Numeric mi kontrol et
    if let quantity = deepLink.parameters["qty"], Int(quantity) == nil {
        print("⚠️ Quantity sayisal degil, default kullaniliyor")
    }

    // Normal flow
    // ...
}
```

### 8.3. Network Errors

```swift
func showProduct(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
    guard let productID = deepLink.parameters["id"] else { return }

    let productVC = ProductDetailViewController()
    productVC.productID = productID

    // Loading state
    productVC.showLoadingState()

    // Product bilgilerini yukle
    ProductService.shared.fetchProduct(id: productID) { result in
        switch result {
        case .success(let product):
            productVC.product = product
            productVC.hideLoadingState()

        case .failure(let error):
            print("❌ Product yuklenemedi: \(error)")

            // Kullaniciya hata goster
            productVC.showErrorState(message: "Urun yuklenemedi")

            // Retry secenegi sun
            productVC.onRetryTapped = {
                self.showProduct(deepLink, navController: navController)
            }
        }
    }

    navController.pushViewController(productVC, animated: true)
}
```

---

## 9. PERFORMANCE OPTIMIZASYONU

### 9.1. Lazy Loading

```swift
func navigateToDestination(_ deepLink: PaylisherDeepLink) {
    // View controller'i lazy load et (heavy init varsa)
    DispatchQueue.main.async {
        let productVC = ProductDetailViewController()
        productVC.productID = deepLink.parameters["id"]

        self.window?.rootViewController?.present(productVC, animated: true)
    }
}
```

### 9.2. Prefetching

```swift
func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
    // Data'yi onceden yukle
    if deepLink.destination == "product",
       let productID = deepLink.parameters["id"] {

        // Background'da product bilgisini yukle
        ProductService.shared.prefetchProduct(id: productID)
    }

    // Normal navigation
    navigateToDestination(deepLink)
}
```

### 9.3. Cache Management

```swift
// Campaign data'yi cache'le (SDK otomatik yapar ama override edebilirsiniz)
func showPromo(_ deepLink: PaylisherDeepLink, navController: UINavigationController) {
    let promoVC = PromoViewController()

    if let cachedCampaign = CampaignCache.shared.get(key: deepLink.campaignKeyName) {
        // Cache'den al (hizli)
        promoVC.campaignData = cachedCampaign
    } else if let campaignData = deepLink.campaignData {
        // SDK'dan al
        promoVC.campaignData = campaignData

        // Cache'e kaydet
        CampaignCache.shared.set(key: deepLink.campaignKeyName, value: campaignData)
    }

    navController.pushViewController(promoVC, animated: true)
}
```

---

## 10. TEST ETME

### 10.1. Simulator Test

**Terminal'den:**

```bash
# Urun detay
xcrun simctl openurl booted "uygulamaniz://product?id=12345"

# Kategori
xcrun simctl openurl booted "uygulamaniz://category?id=electronics"

# Kampanya
xcrun simctl openurl booted "uygulamaniz://promo?campaign=summer_sale"

# Arama
xcrun simctl openurl booted "uygulamaniz://search?q=iPhone"
```

### 10.2. Unit Testing

```swift
import XCTest
@testable import YourApp

class DeepLinkTests: XCTestCase {

    func testProductDeepLink() {
        // Test URL
        let url = URL(string: "uygulamaniz://product?id=12345")!

        // Parse
        let deepLink = PaylisherDeepLink.parse(url)

        // Assertions
        XCTAssertEqual(deepLink?.destination, "product")
        XCTAssertEqual(deepLink?.parameters["id"], "12345")
        XCTAssertEqual(deepLink?.scheme, "uygulamaniz")
    }

    func testCategoryDeepLink() {
        let url = URL(string: "uygulamaniz://category?id=electronics&sort=price")!
        let deepLink = PaylisherDeepLink.parse(url)

        XCTAssertEqual(deepLink?.destination, "category")
        XCTAssertEqual(deepLink?.parameters["id"], "electronics")
        XCTAssertEqual(deepLink?.parameters["sort"], "price")
    }

    func testCampaignDeepLink() {
        let url = URL(string: "uygulamaniz://campaign/SUMMER_SALE")!
        let deepLink = PaylisherDeepLink.parse(url)

        XCTAssertEqual(deepLink?.destination, "campaign")
        XCTAssertEqual(deepLink?.campaignKeyName, "SUMMER_SALE")
    }
}
```

### 10.3. UI Testing

```swift
import XCTest

class DeepLinkUITests: XCTestCase {

    func testProductDeepLinkNavigation() {
        let app = XCUIApplication()
        app.launch()

        // Deeplink acimiyla simule et
        app.open(url: URL(string: "uygulamaniz://product?id=12345")!)

        // Product detay sayfasi acildi mi?
        XCTAssertTrue(app.navigationBars["Product Detail"].exists)

        // Product ID dogru mu?
        XCTAssertTrue(app.staticTexts["12345"].exists)
    }
}
```

---

## 11. PRODUCTION CHECKLIST

### 11.1. Pre-Launch Checklist

- [ ] Info.plist ayarlari tamamlandi
- [ ] URL scheme eklendi
- [ ] Universal Links konfigurasyonu yapildi
- [ ] AASA dosyasi deploy edildi
- [ ] Deeplink handler implement edildi
- [ ] Tum destination'lar test edildi
- [ ] Error handling eklendi
- [ ] Analytics event'leri kontrol edildi
- [ ] Parameter validation yapiliyor
- [ ] Loading state'ler eklendi
- [ ] Fallback URL'ler belirlendi

### 11.2. QA Test Cases

| Test Case | Expected Result |
|-----------|----------------|
| Product deeplink | Urun detay sayfasi acilir |
| Category deeplink | Kategori sayfasi acilir |
| Promo deeplink | Kampanya sayfasi acilir |
| Search deeplink | Arama sonuclari gosterilir |
| Invalid ID | Hata mesaji + ana sayfa |
| Missing parameter | Hata mesaji + fallback |
| Network error | Loading + retry secenegi |
| App kapali | App acilir + navigate |
| App background | Foreground + navigate |

---

## 12. COMMON DESTINATION ORNEKLERI

### 12.1. E-Ticaret

```swift
switch deepLink.destination {
case "product":     // Urun detay
case "category":    // Kategori listesi
case "search":      // Arama sonuclari
case "promo":       // Kampanya sayfasi
case "brand":       // Marka sayfasi
case "collection":  // Koleksiyon
case "sale":        // Indirimler
case "new":         // Yeni urunler
default: break
}
```

### 12.2. Medya/Haber

```swift
switch deepLink.destination {
case "article":     // Haber detay
case "video":       // Video oynatici
case "category":    // Haber kategorisi
case "tag":         // Tag sayfasi
case "author":      // Yazar sayfasi
case "live":        // Canli yayin
default: break
}
```

### 12.3. Sosyal Medya

```swift
switch deepLink.destination {
case "profile":     // Kullanici profili
case "post":        // Gonderi detay
case "hashtag":     // Hashtag sayfasi
case "story":       // Story viewer
case "chat":        // Mesajlasma
case "notification":// Bildirimler
default: break
}
```

---

## 13. BEST PRACTICES

### 13.1. URL Design

**Iyi:**
```
uygulamaniz://product?id=12345
uygulamaniz://category?id=electronics
uygulamaniz://search?q=iPhone
```

**Kotu:**
```
uygulamaniz://showProductWithID12345  // Karmasik
uygulamaniz://p/12345                 // Acik degil
uygulamaniz://x?y=z                   // Anlasilmaz
```

### 13.2. Error Messages

**Iyi:**
```swift
showAlert(
    title: "Urun Bulunamadi",
    message: "Aradiginiz urun artik mevcut degil"
)
```

**Kotu:**
```swift
showAlert(
    title: "Error",
    message: "404 Not Found"
)
```

### 13.3. Navigation Flow

**Iyi:**
```swift
// Clear navigation stack
navController.popToRootViewController(animated: false)
// Navigate to destination
navController.pushViewController(productVC, animated: true)
```

**Kotu:**
```swift
// Stack karmasiklasiyor
navController.pushViewController(homeVC, animated: false)
navController.pushViewController(categoryVC, animated: false)
navController.pushViewController(productVC, animated: true)
```

---

## 14. SIKCA SORULAN SORULAR

### S: No-auth deeplink en hizli implement yontemi nedir?

**C:** Minimum kod:

```swift
extension AppDelegate: PaylisherDeepLinkHandler {
    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        guard let productID = deepLink.parameters["id"] else { return }

        let productVC = ProductDetailViewController()
        productVC.productID = productID

        window?.rootViewController?.present(productVC, animated: true)
    }
}
```

### S: Universal Link vs Custom Scheme hangisini kullanmaliyim?

**C:** Her ikisini de kullanin. Universal Link uygulama yuklu degilse web'e
fallback yapar. Custom scheme da yedek olarak calisir.

### S: Deeplink her zaman calisir mi?

**C:** Evet, uygulama kapali/background/foreground farketmeksizin calisir.

### S: Campaign resolution zorunlu mu?

**C:** Hayir. Campaign key yoksa normal deeplink olarak calisir.

---

## 15. DESTEK

Sorun yasiyorsaniz:

1. Debug logging acin: `deepLinkConfig.debugLogging = true`
2. Log'lari inceleyin
3. Test URL'lerinizi kontrol edin
4. Destek: support@paylisher.com

---

**Dokuman Versiyonu:** 1.0
**Son Guncelleme:** 08 Ocak 2025
**SDK Versiyonu:** 1.6.0+
