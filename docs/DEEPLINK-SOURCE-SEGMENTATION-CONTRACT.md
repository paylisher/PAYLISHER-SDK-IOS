# Deeplink Kaynak Segmentasyonu — SDK ↔ Backend Sözleşmesi

> **Durum:** iOS + Android SDK tarafı **tamamlandı ve compile-verified** (bu commit). Backend
> (campaign-service + analytics endpoint'leri) tarafı **bekliyor** — bu doküman backend ekibinin
> paralel ilerlemesi için gereken sözleşmeyi tanımlar.
>
> **Kapsam:** Bu doküman SDK'nın kaynak (source) verisini **nasıl ürettiğini** ve backend'in bunu
> uçtan-uca çalıştırmak için **ne yapması gerektiğini** tanımlar. Ürün/Studio tarafındaki tam mimari
> analiz ve UserPath tasarımı için bkz. `usePublisher/docs/deeplink-source-segmentation.md`
> (kapsamlı tasarım dokümanı; "Mimari A (person-join)" vs "Mimari B (campaign_source)" kararı orada).
>
> İlgili kaynak dosyalar:
> - iOS: `Paylisher/Paylisher/PaylisherDeepLinkManager.swift` (`PaylisherDeeplinkSource`,
>   `PaylisherDeepLink`), `Paylisher/Paylisher/PaylisherSDK.swift`
> - Android: `paylisher-android/.../PaylisherDeepLink.kt` (`PaylisherDeeplinkSource`),
>   `paylisher/.../Paylisher.kt`, `paylisher-android/.../PaylisherDeepLinkManager.kt`

---

## 0. Bu commit'te ne değişti (SDK)

İki SDK de artık trafik kaynağını **kanonik bir token**'a normalize edip event'lere basıyor:

| Alan | iOS | Android | Açıklama |
|---|---|---|---|
| `campaign_source` (session-scoped super property) | ✅ | ✅ (yeni) | Deeplink session'ındaki **her** event'e basılır (kanonik token). Studio path'i doğrudan bununla bölebilir → jid→kişi join'i gerekmez. |
| `campaign_source` ("Deep Link Opened" event'inde) | ✅ | ✅ | Her zaman mevcut (en kötü `direct`). |
| `utm_medium` | ✅ | ✅ | `utm_medium` / `medium` paramından. |
| `referrer` | ✅ | ✅ | `referrer` / `ref` **URL paramından** (HTTP header değil). |
| `platform_hint` | ✅ (`sourceApplication`) | ✅ (Intent referrer) | Düşük öncelikli sinyal; varsa. |
| `source` (ham) | ✅ (zaten vardı) | ✅ (zaten vardı) | `utm_source` / `source` ham değeri — teşhis için korunur. |
| `jid` | ✅ (zaten vardı) | ✅ (zaten vardı) | Journey ID; değişmedi. |

> **Önceki durum:** iOS `campaign_source`'u **ham** `?source` değeriyle basıyordu (önceki commit);
> Android'de hiç yoktu. Şimdi **ikisi de kanonik token basıyor** ve Android paritede.

---

## 1. Kanonik Kaynak Taksonomisi (değişmez sözleşme)

`campaign_source` **tam olarak şu 7 token**'dan biridir. Bu küme iOS SDK, Android SDK ve Paylisher
Studio (`getSourceGroup`) arasında **birebir aynıdır** — her katman aynı token setini ürettiği/tükettiği
için Studio kaynağa göre path bölmeyi istemci-bazlı eşleme olmadan yapabilir.

```
instagram   facebook   twitter   tiktok   qr   direct   unknown
```

- `twitter` — X dahil (`x`, `x.com`, `t.co` → `twitter`). Studio UI'da "X" gösterir, token `twitter`.
- `direct` — UTM yok **ve** referrer/hint yok (organik direkt; SMS/e-posta/tarayıcı). Spec tanımı.
- `unknown` — bir kaynak sinyali **var** ama tanınmıyor.

### 1.1 Tespit önceliği (SDK `PaylisherDeeplinkSource.canonical`)

```
1. utm_source / ?source        (rawSource)     ← en güvenilir
2. ?referrer                   (URL paramı)
3. platform_hint               (sourceApplication / Intent referrer)  ← düşük öncelik
→ sinyal VAR ama tanınmıyor   → unknown
→ hiçbir sinyal YOK           → direct
```

### 1.2 Eşleme kuralları (`PaylisherDeeplinkSource.classify`)

İki SDK'da **aynı** mantık (değişiklik yaparken ikisini de güncelle):

- **Marka kelimeleri** (substring, hem isim hem domain hem bundle-id/package için güvenli):
  `instagram`, `facebook`/`messenger`/`katana`/`orca`, `tiktok`/`musically`/`zhiliaoapp`,
  `twitter`/`tweetie`. Ek kısa kodlar: `ig`, `fb`, `tt`, `meta`.
- **Host-anchored kısa domain'ler** (yanlış-pozitiften kaçınmak için `discount.com` gibi):
  `x` / `x.com` / `t.co` → `twitter`; `fb.com` / `fb.me` → `facebook`.
- **QR**: `qr`, `qrcode`, `qr_code`, `qr-code`.
- **Direct kanallar** (kampanya platformu değil): `safari`, `chrome`, `firefox`, `mail`,
  `mobilemail`, `sms`, `mobilesms`, `messaging`, `whatsapp`, `telegram`, `gmail`, `browser`,
  `website`, `web`, `direct`.

> **Önemli:** SDK gelen `?source=` değerini **defansif olarak** kanonikleştirir; yani backend
> `?source=l.instagram.com` veya `?source=ig` gönderse bile SDK `instagram` basar. Yine de backend'in
> doğrudan kanonik token göndermesi en temizidir (§3.1).

---

## 2. SDK Genel API (host entegrasyonu)

### 2.1 iOS

```swift
// AppDelegate: openURL options'ı ilet → sourceApplication platform_hint olarak yakalanır
func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
    return PaylisherSDK.shared.handleDeepLink(url, options: options)   // ← yeni overload
}

// Kanonikleştirmeye doğrudan erişim (gerekirse):
let token = PaylisherDeeplinkSource.canonical(rawSource: "ig", referrer: nil, platformHint: nil) // "instagram"
```

`handleDeepLink(_:)` (options'sız), `handleURLContexts(_:)`, `handleUserActivity(_:)` aynen çalışır;
yalnızca `platform_hint` `nil` olur. **`sourceApplication` modern iOS'ta Universal Link / Scene
akışlarında çoğunlukla boştur** → birincil yöntem değildir, sadece bonus sinyal.

### 2.2 Android

```kotlin
// handleIntent zaten Intent referrer'ını platform_hint olarak türetir (otomatik):
PaylisherDeepLinkManager.getInstance().handleIntent(intent)

// veya doğrudan URL ile (opsiyonel platformHint):
PaylisherDeepLinkManager.getInstance().handleUrl(urlString, platformHint)

// Kanonikleştirme:
val token = PaylisherDeeplinkSource.canonical("ig", null, null) // "instagram"
```

### 2.3 Session-scoping (kritik)

`campaign_source`, `campaign_key`/`deeplink_key` ile **aynı yaşam döngüsüne** sahiptir:
- Yalnızca deeplink'in **geldiği session**'a basılır (in-memory + session-id eşleşmesi).
- Persist **edilmez** → organik relaunch / yeni session **taşımaz**.
- Yalnızca **campaign key taşıyan** deeplink'lerde devreye girer (`autoRegisterCampaignKeys`).

---

## 3. Backend Yapılacaklar

### 3.1 campaign-service — `?source=` enjeksiyonu (Mimari B'yi aktive eder)

Kaynak tespiti **zaten** click anında yapılıyor (`referer`/`fbclid` → `referrerSource`). Mimari B
için tek gereken: bu değeri **redirect/deeplink URL'ine** kanonik token olarak basmak.

```
# Bugün (kaynak URL'de yok):
paylishertest://products/a?keyName=X7kdi5Yq9lTVOv46uHYtV&jid=abc123

# Mimari B için (campaign-service ekler):
paylishertest://products/a?keyName=X7kdi5Yq9lTVOv46uHYtV&jid=abc123&source=instagram
                                                                      └─ §1 kanonik token
```

- `source` değeri **§1'deki 7 token'dan biri** olmalı (`referrerSource`'u oraya map'leyerek).
- Tanınmayan/eksik kaynak için `source` **boş bırakılabilir** → SDK `direct`/`unknown` üretir.
- İsteğe bağlı: `utm_medium`, `referrer` de eklenebilir (raporlama zenginliği).
- **Geriye dönük çalışmaz** — yalnızca bu enjeksiyondan sonra oluşan tıklamalarda `campaign_source`
  dolu gelir. Eski veri için Mimari A (person-join) kullanılmalı (bkz. kapsamlı doküman §0.4).

### 3.2 Analytics endpoint'leri

Endpoint şemaları kapsamlı dokümanda (`usePublisher/docs/deeplink-source-segmentation.md` §2c) ve
orijinal spec'te tanımlı:
- `GET .../analytics/source-paths`
- `GET .../journey/{jid}`
- `GET .../analytics/compare`

**Mimari B (campaign_source mevcutken) iç akış basitleşir:** event store'da doğrudan
`properties.campaign_source = <token>` ile filtrele → jid→distinct_id join'ine **gerek kalmaz**.
Mimari A'da (geçmiş veri) gruplama **`distinct_id` (kişi)** üzerinden yapılmalı, `jid` üzerinden
**değil** (jid yalnızca ilk session'a basılır → path'i keser). Detay: kapsamlı doküman §0.3 / §2c.

### 3.3 SDK'nın garanti ettiği event property'leri (backend bunlara güvenebilir)

"Deep Link Opened" event'i ve (campaign key varsa) session'daki tüm event'ler:

| Property | Tip | Garanti |
|---|---|---|
| `campaign_source` | string | "Deep Link Opened"da **her zaman** (≥`direct`); session event'lerinde campaign key varsa |
| `campaign_key` / `deeplink_key` | string | campaign key taşıyan deeplink'lerde |
| `jid` | string | URL'de `?jid=` varsa veya campaign resolve'dan |
| `source` | string | ham `utm_source`/`source` varsa |
| `utm_medium`, `referrer`, `platform_hint` | string | ilgili sinyal varsa |

---

## 4. Studio entegrasyon noktası (özet)

- **Mimari A (şimdi, geçmiş veri):** `getSourceGroup(click.referrerSource)` ile kaynak → `jid` →
  `distinct_id` → zengin path. Değişiklik gerekmez; çalışan prototip mevcut.
- **Mimari B (campaign-service `?source=` bastıktan sonra):** event'leri doğrudan
  `properties.campaign_source` ile böl. SDK kanonik token bastığı için `getSourceGroup`'un beklediği
  giriş setiyle **birebir uyumlu** → ekstra eşleme gerekmez. Bu branch, §3.1 backend değişikliğine
  **bağımlı** (o yüzden şimdi yazılırsa atıl kalır).

---

## 5. Kısıtlar & KVKK/GDPR

- `sourceApplication` (iOS) / Intent referrer (Android) **zayıf sinyaldir** — birincil yöntem değil,
  yalnızca `platform_hint`. Birincil yöntem: campaign-service `?source=` (§3.1).
- Instagram/Facebook referer'ı sık maskeler → bu yüzden `?source=` (UTM) birincil olmalı.
- `campaign_source` token'ları ve `jid` kişisel veri **değildir**; `distinct_id` zaten kullanılan
  pseudonim kimliktir → bu mimari yeni PII getirmez. UTM'lerde kullanıcıya-özgü tanımlayıcı olmamalı.
