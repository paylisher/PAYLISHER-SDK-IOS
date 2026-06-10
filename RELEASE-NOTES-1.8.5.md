# Paylisher SDK — Sürüm Notları

## iOS `1.8.4 → 1.8.5`  ·  Android `1.1.2 → 1.1.3`

> Bu iki sürüm aynı geliştirme döngüsünün iki platformdaki karşılığıdır. Tarihler ve commit'ler birebir örtüşüyor (iOS 1.8.4 ≈ Android 1.1.2, 2026-05-18; iOS 1.8.5 ≈ Android 1.1.3, 2026-06-05).

| | iOS | Android |
|---|---|---|
| Önceki sürüm | `1.8.4` | `1.1.2` |
| Yeni sürüm | `1.8.5` | `1.1.3` |
| Dil | Swift | Kotlin |
| Yayın tarihi | 2026-06-05 | 2026-06-01/05 |

---

## 🎯 Özet

Bu sürümün ana teması **in-app mesajlarda platformlar arası görsel birebir uyum (pixel parity)** ve **çok dilli (lokalizasyon) destek**. Studio web önizlemesi, iOS ve Android artık aynı mesajı **aynı font, aynı satır yüksekliği, aynı görsel yerleşimi** ile gösteriyor; metinler kullanıcı diline/kampanya diline göre yerelleştiriliyor.

Öne çıkanlar:

1. **In-app çok dilli destek** — başlık, gövde ve artık **aksiyon (CTA) butonu** da yerelleştiriliyor; cihaz dili backend'e raporlanıyor (`$locale`).
2. **In-app Layout v2** — gömülü **Inter** fontu, satır yüksekliği uyumu (1.3×) ve CSS `object-fit` benzeri yeni **görsel yerleşim motoru** (`fit` / `align` / `padding`).
3. **Görsel iyileştirmeleri** — tutarlı yatay kenar boşluğu (yüzde tabanlı) ve görsellerin geç yüklenmesinden kaynaklanan "pop-in" titremesinin önlenmesi (önbellek + önyükleme).
4. **Platforma özgü iyileştirmeler** — iOS'ta SwiftUI otomatik ekran takibi ve XCFramework için GitHub Actions CI hattı; Android'de eksik `notificationOpen` olayının düzeltilmesi.

> ⚠️ Yayınlamadan önce mutlaka okuyun: aşağıdaki **"Dikkat Edilmesi Gerekenler"** bölümünde iOS sürüm numarası, Android'de bir tip değişikliği (breaking change) ve pop-in işinin platformlara göre farklı tag'lerde olması gibi kritik notlar var.

---

## 1. In-app Mesajlarda Çok Dilli Destek (Lokalizasyon)

İki aşamada geldi: `lang-v1` (cihaz dili raporlama) ve `lang-v2-inapp` (aksiyon butonu lokalizasyonu).

### Ne değişti?
- **Başlık ve gövde metinleri** zaten dil haritası (`{ "tr": "...", "en": "..." }`) olarak çözülüyordu; bu sürümde **aksiyon/CTA buton metni** de aynı şekilde dil haritasından yerelleştiriliyor.
- **Cihaz dili artık backend'e raporlanıyor.** Her iki platform da FCM token kaydında cihaz dilini gönderiyor; böylece backend, push/in-app kampanyalarını **kişinin diline göre** hedefleyebiliyor.

### iOS tarafı
- `CustomInAppPayload.swift` — yeni `Dictionary.localize(_ defaultLang:fallback:)` eklendi. Çözüm sırası: **(1) cihaz dili** (`Locale.preferredLanguages.first`, ana alt-etiket; örn. `tr-TR → tr`) → (2) kampanya varsayılan dili (`defaultLang`) → (3) ilk mevcut çeviri → (4) `fallback`.
- Modal, fullscreen, banner ve carousel'deki **tüm metin öğeleri** (kapat butonu dahil) bu kurala bağlandı.
- `PaylisherContext.swift` — `$locale` artık `Locale.current.languageCode` yerine `Locale.preferredLanguages.first` ana alt-etiketinden üretiliyor. (Eski yöntem uygulama-dili pazarlığı nedeniyle cihazlar arası aynı değere çökebiliyordu → push dil seçimi yanlış oluyordu.)
- `PaylisherSDK.swift` — `$locale` artık sadece olayda değil, **kişi (`$set`) özelliği** olarak da gönderiliyor. (Önceki durumda iOS kişilerinde `$locale` olmuyor, dolayısıyla tüm iOS cihazları kampanya varsayılan diline düşüyordu — Android zaten `$set` ediyordu.)

### Android tarafı
- `PaylisherAndroid.kt` / `FcmMessageHandler.kt` — FCM token kaydında `userProperties` içine `"locale" = Locale.getDefault().language` eklendi (üç token yolu da güncellendi).
- `NotificationData.kt` — `InAppNative.actionText` tipi `String?` → **`Map<String, String>?`** oldu (başlık/gövde ile aynı `{ dil: metin }` formatı).
- `InAppMessageHelper.kt` — native banner kartında aksiyon butonu artık `actionText.localize(defaultLang)` ile yerelleştiriliyor.
- Android'de render anında dil seçimi `defaultLang` (payload'dan, backend kaynaklı) üzerinden yapılıyor; cihaz dili backend'e raporlanıp hedefleme için kullanılıyor.

---

## 2. In-app Layout v2 — Platformlar Arası Birebir Uyum

Amaç (kodda da belirtilmiş): **Studio web önizlemesi, iOS ve Android'in aynı mesajı piksel düzeyinde aynı göstermesi.**

### a) Gömülü Inter Fontu
- Her iki SDK'ya da **Inter** fontunun 4 varyantı (`Regular / Bold / Italic / BoldItalic`) gömüldü ve bir **font kayıt katmanı** eklendi:
  - iOS: `PaylisherFontRegistry.swift` (CoreText ile çalışma anında kayıt, thread-safe, font yoksa sisteme güvenli geri düşüş).
  - Android: `PaylisherFontRegistry.kt` (`Typeface.createFromAsset` + önbellek, asset yoksa sistem fontuna geri düşüş).
- Yazı tipi davranışı: `fontFamily` = `default`/boş ise **Inter** kullanılıyor; `monospace` ise sistem mono; **özel bir aile belirtildiyse** eski davranış korunuyor (host uygulamanın fontu çalışmaya devam eder).
- Çözülen somut hata: aynı metnin ("PAYLİSHER'I İNCELE" gibi) her platformda farklı kelimeden satır kırması — artık Inter ile her yerde aynı kelimede kırılıyor.

### b) Satır Yüksekliği Uyumu
- iOS ve Android'de tüm in-app metinleri artık **`1.3 × fontSize`** satır yüksekliğiyle çiziliyor (web önizlemesindeki `line-height: 1.3` ile aynı).
  - iOS: `NSAttributedString` + paragraf stili + glifleri ortalamak için `baselineOffset`.
  - Android: her görünümde `applyPreviewLineHeight(view, 1.3f)` yardımcı fonksiyonu. (Önceden Android ~1.0× kullanıyordu, paragraflar %30 daha sıkışık ve dikeyde kaymış görünüyordu.)

### c) Yeni Görsel Yerleşim Motoru (CSS `object-fit` karşılığı)
- Yeni görünüm sınıfları eklendi: iOS `PaylisherImageFitView`, Android `PaylisherFitImageView`.
- Desteklenen yeni payload alanları (her iki platform):
  - `imageFit` → `cover` / `contain` / `fill`
  - `imageAlignX` → `left` / `center` / `right`
  - `imageAlignY` → `top` / `center` / `bottom`
  - `imagePadding` → iç boşluk yüzdesi (0–45)
- Geriye dönük uyumlu: alanlar boşsa eski "kenardan kenara cover" davranışı korunuyor.
- iOS ek olarak köşe yuvarlama hatalarını düzeltti (büyük cover görsellerde köşelerin üçgenleşmesi; üst renk şeridinin yalnızca üst köşelerinin yuvarlanması).
- Android'de ek yerleşim uyumu: modal/fullscreen metin bloklarına 4dp dikey boşluk, fullscreen'e `breakStrategy`/`hyphenation` ayarları (OEM'ler arası farklı satır kırılmasını engellemek için).

---

## 3. Görsel İyileştirmeleri

### Yatay kenar boşluğu (iOS)
- In-app görsellerin yatay kenar boşluğu artık **tüm yerleşim türlerinde (banner/modal/fullscreen)** kapsayıcı genişliğinin yüzdesi olarak hesaplanıyor (`bannerPctH`). Önceden modal ve fullscreen ham nokta (pt) değeri kullanıyordu ve önizlemeye göre az boşluklu görünüyordu.

### "Pop-in" titremesinin önlenmesi (görsel önbellek + önyükleme)
- Görsellerin render anında indirilip geç görünmesi ("önce boş, sonra ani sıçrama") sorunu giderildi.
- **Android (`1.1.3` içinde):**
  - `PaylisherImageCache.kt` — paylaşımlı OkHttp disk önbelleği (64 MB) + bellekte `LruCache`.
  - `PaylisherImagePrefetcher.kt` — dialog gösterilmeden önce payload'daki tüm görselleri (en fazla 2 sn'lik sınırla) önden ısıtır.
  - Sonuç: in-app mesaj görselleriyle birlikte, boş bir titreme olmadan açılıyor.
- **iOS:** Aynı "pop-in" iyileştirmesi `1.8.5` tag'inden **hemen sonra** (commit `356cfed`, aktif branch / `1.8.6` hattı) eklendi — bu nedenle `1.8.5` tag'inde **bulunmuyor**. (Bkz. Dikkat Edilmesi Gerekenler.)

---

## 4. Platforma Özgü Değişiklikler

### iOS'a özel
- **SwiftUI otomatik ekran takibi** (`UIViewController.swift`) — `UIHostingController` için ekran adı artık mantıklı şekilde türetiliyor: önce `.navigationTitle()`, yoksa View struct adı ayrıştırılıyor (`HomeView → Home`); temiz bir ad çıkarılamazsa olay gönderilmiyor (çöp `$screen` adlarının önüne geçildi).
- **A/B & çok dilli özellik normalizasyonu** (`NotificationManager.swift`) — iç içe geçmiş sözlük/dizi özellikleri (örn. çok dilli `abVariantLabel`/`title`) artık JSON string'e çevriliyor; böylece iOS'tan giden A/B özellikleri DataStudio'da Android ile aynı formatta görünüyor.
- **XCFramework CI hattı** (altyapı) — XCFramework derleme işi yerel Mac'ten GitHub Actions'a taşındı:
  - `build-xcframework.yml` (Aşama 1: derle + artifact yükle)
  - `release-xcframework.yml` (Aşama 2: sürümle, derle, checksum, `Package.swift` güncelle, tag at, GitHub Release oluştur)
  - `build_xcframework.sh` CI'a uygun hale getirildi (`pipefail`, dağıtım derlemesi, imzasız static framework). `CI_XCFRAMEWORK_HANDOFF.md` devir dökümanı eklendi.

### Android'e özel
- **`notificationOpen` metrik düzeltmesi** (`PaylisherActivityLifecycleCallbackIntegration.kt`) — backend payload'ında üst düzey `notification` alanı olduğunda FCM bildirimi kendisi gösterip `onMessageReceived`'ı atlıyordu ve **bildirime tıklama olayı hiç gönderilmiyordu**. Artık `onActivityCreated` içinde launch intent'ten okunup `notificationOpen` olayı tetikleniyor. `gcm.message_id` ile **idempotent** (SharedPreferences tabanlı dedupe), yani çift sayım yok.

---

## ⚠️ Dikkat Edilmesi Gerekenler

### 1. iOS sürüm numarası eksik güncellendi (önemli)
`1.8.5` yayınında sürüm yalnızca **kısmen** yükseltildi:
- ✅ `Package.swift` (SPM `binaryTarget`) → `1.8.5` (URL + checksum güncel).
- ❌ `Paylisher/Paylisher/PaylisherVersion.swift` → hâlâ `"1.8.4"`.
- ❌ `Paylisher.podspec` → hâlâ `'1.8.4'`.
- ❌ `PaylisherSDK.sdkVersion()` → hâlâ `"1.8.3"` (eski).

**Kök neden:** `scripts/bump-version.sh` `Paylisher/PaylisherVersion.swift` yolunu hedefliyor, ama dosya `Paylisher/Paylisher/PaylisherVersion.swift` konumunda. Bu yüzden CI'ın sürümleme adımı Swift sabitini ve podspec'i güncellemedi.

**Etkisi:** SPM kullananlar için sürüm `1.8.5`; ama CocoaPods kullananlar ve çalışma anında raporlanan `$sdk_version`/`$sdk_package_version` telemetrisi hâlâ `1.8.4`/`1.8.3` gösteriyor.

### 2. Android'de breaking change — `actionText` tipi değişti
`InAppNative.actionText` artık `String?` değil **`Map<String, String>?`**. `InAppNative`'i doğrudan oluşturan herhangi bir kod güncellenmelidir.

### 3. Android'de `bgImage*` alanları henüz aktif değil
Arka plan görseli için `bgImageFit`, `bgImageAlignX`, `bgImageAlignY`, `bgImagePadding` alanları modele eklendi ama **henüz hiçbir renderer tarafından kullanılmıyor** (ileriye dönük hazırlık). Per-blok görsel alanları (`imageFit` vb.) ise aktif.

### 4. "Pop-in" iyileştirmesi platformlar arası farklı tag'lerde
- Android `1.1.3` → pop-in önbellek/önyükleme **dahil**.
- iOS `1.8.5` tag'i → pop-in **dahil değil**; iş tag'den hemen sonra (aktif branch, `1.8.6` hattı) eklendi.

### 5. In-app dil seçimi mekanizması platformlara göre farklı
- iOS render anında **cihaz dilini** önceliyor (`localize()` içinde cihaz dili → `defaultLang` → ...).
- Android render anında **payload'daki `defaultLang`'i** kullanıyor (backend kaynaklı); cihaz dili yalnızca backend'e raporlanıyor.
- Backend her iki platforma da kişinin `$locale`'ine göre aynı dili (uygun `defaultLang`) gönderiyorsa sonuç aynı olur; aksi halde aynı cihazda iki platform farklı dil gösterebilir. **Doğrulanması önerilir.**

---

## 📋 Değişen Dosya Özeti

### iOS (`1.8.4 → 1.8.5`) — 19 dosya, ~+1150 / −204
| Dosya | Değişiklik |
|---|---|
| `Notifications/StyleViewController.swift` | Layout v2 çekirdeği: `PaylisherImageFitView`, satır yüksekliği, fontlar, görsel boşlukları, köşe düzeltmeleri |
| `Notifications/PaylisherFontRegistry.swift` | **YENİ** — gömülü Inter kaydı |
| `Notifications/CustomInAppPayload.swift` | `localize()` + `imageFit`/`bgImage*` alanları |
| `Notifications/NotificationManager.swift` | `localize()` + A/B özellik normalizasyonu |
| `Paylisher/PaylisherSDK.swift` | `$locale` kişi (`$set`) özelliği olarak |
| `Paylisher/PaylisherContext.swift` | `$locale` = cihazın tercih edilen dili |
| `Paylisher/UIViewController.swift` | SwiftUI ekran adı ayrıştırma |
| `Notifications/CarouselInAppViewController.swift` | `localize()` + Inter font |
| `Notifications/PaylisherInAppModalViewController.swift` | Native modalda Inter font |
| `.github/workflows/*.yml`, `scripts/build_xcframework.sh`, `CI_XCFRAMEWORK_HANDOFF.md` | XCFramework CI hattı (altyapı) |
| `Resources/Fonts/Inter-*.ttf` | **YENİ** — 4 font dosyası |
| `Package.swift` | `binaryTarget` → 1.8.5 |

### Android (`1.1.2 → 1.1.3`) — 20 dosya, +721 / −157
| Dosya | Değişiklik |
|---|---|
| `helpers/PaylisherImageCache.kt` | **YENİ** — OkHttp disk + LRU bitmap önbelleği |
| `helpers/PaylisherFitImageView.kt` | **YENİ** — object-fit/position/inset görünümü |
| `helpers/PaylisherFontRegistry.kt` | **YENİ** — gömülü Inter yükleyici |
| `helpers/PaylisherImagePrefetcher.kt` | **YENİ** — gösterimden önce görsel önyükleme |
| `assets/fonts/Inter-*.ttf` | **YENİ** — 4 font dosyası |
| `iam/InAppMessagingFullscreen.kt` | `resolveTypeface`, satır yüksekliği, fit-image, önbellek, satır kırma uyumu |
| `iam/InAppMessagingModal.kt` | Inter, satır yüksekliği, 4dp boşluk, fit-image, önbellek |
| `iam/InAppMessagingBanner.kt` | Inter, satır yüksekliği, fit-image, önbellek |
| `notification/NotificationData.kt` | `image*`/`bgImage*` alanları; `actionText: Map<String,String>?` |
| `internal/PaylisherActivityLifecycleCallbackIntegration.kt` | Koşulsuz `notificationOpen` izleme kancası |
| `notification/InAppTaskWorker.kt` | Gösterimden önce görselleri önyükle |
| `notification/InAppMessageHelper.kt` | Native kart Inter fontları + yerelleştirilmiş aksiyon butonu |
| `notification/FcmMessageHandler.kt`, `PaylisherAndroid.kt` | FCM kaydında `locale` |
| `build.gradle.kts` (×2) | Sürüm `1.1.3` |

---

*Hazırlanma tarihi: 2026-06-09 · Kapsam: iOS `1.8.4..1.8.5` (tag) ve Android `cb9b121..147857f` commit aralıkları diff analizi.*
