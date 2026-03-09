# Paylisher iOS SDK - Deferred Deep Link Mimarisi

Bu döküman, Paylisher iOS SDK'daki deferred deep link (ertelenmiş derin bağlantı) sisteminin teknik mimarisini, kullanılan yöntemleri ve Apple'ın privacy framework'leri ile ilişkisini açıklar.

---

## İçindekiler

1. [Deferred Deep Link Nedir?](#deferred-deep-link-nedir)
2. [Sistem Mimarisi](#sistem-mimarisi)
3. [Fingerprint Yöntemleri](#fingerprint-yöntemleri)
4. [Apple Privacy Framework'leri](#apple-privacy-frameworkleri)
5. [Sık Sorulan Sorular](#sık-sorulan-sorular)
6. [Teknik Detaylar](#teknik-detaylar)

---

## Deferred Deep Link Nedir?

Deferred deep link, kullanıcının **uygulamayı yüklemeden önce** tıkladığı bir bağlantının, **uygulama yüklendikten sonra** doğru hedefe yönlendirilmesini sağlayan sistemdir.

### Kullanım Senaryosu

```
1. Kullanıcı bir kampanya linkine tıklar (örn: paylisher.link/kampanya123)
2. Uygulama yüklü olmadığı için App Store'a yönlendirilir
3. Kullanıcı uygulamayı yükler ve açar
4. SDK, kullanıcının daha önce tıkladığı linki tespit eder
5. Kullanıcı otomatik olarak kampanya sayfasına yönlendirilir
```

### Neden Önemli?

- **Pazarlama etkinliği:** Hangi kampanyanın uygulama yüklemesine yol açtığını ölçme
- **Kullanıcı deneyimi:** İlk açılışta doğru sayfaya yönlendirme
- **Attribution:** Reklam harcamalarının ROI'sini hesaplama

---

## Sistem Mimarisi

### Genel Akış

```
┌─────────────────────────────────────────────────────────────────────┐
│                         WEB TARAFI                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. Kullanıcı kampanya linkine tıklar                               │
│     https://paylisher.link/kampanya123                              │
│                                                                      │
│  2. Backend, tarayıcıdan cihaz bilgilerini toplar:                  │
│     • User-Agent (cihaz tipi, OS versiyonu)                         │
│     • Ekran çözünürlüğü                                             │
│     • Timezone                                                       │
│     • Dil                                                           │
│     • IP adresi                                                      │
│                                                                      │
│  3. Backend bu bilgilerden FINGERPRINT oluşturur ve saklar          │
│                                                                      │
│  4. Kullanıcı App Store'a yönlendirilir                             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       APP STORE                                      │
├─────────────────────────────────────────────────────────────────────┤
│  Kullanıcı uygulamayı indirir ve yükler                             │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      MOBİL UYGULAMA                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  5. Uygulama ilk kez açılır                                         │
│                                                                      │
│  6. SDK, cihazdan aynı bilgileri toplar ve FINGERPRINT oluşturur    │
│                                                                      │
│  7. SDK, fingerprint'i backend'e gönderir                           │
│                                                                      │
│  8. Backend, iki fingerprint'i karşılaştırır                        │
│                                                                      │
│  9. Eşleşme varsa → Kampanya bilgisi döner                          │
│                                                                      │
│  10. Kullanıcı kampanya sayfasına yönlendirilir                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Attribution Window (Eşleştirme Penceresi)

Fingerprint eşleştirmesi belirli bir zaman penceresi içinde yapılır:

| Pencere Tipi | Süre | Kullanım Alanı |
|--------------|------|----------------|
| Kısa | 1 saat | Test ortamı |
| Standart | 24 saat | Production (varsayılan) |
| Uzun | 7 gün | Uzun süreli kampanyalar |

---

## Fingerprint Yöntemleri

SDK'da iki farklı fingerprint yöntemi bulunmaktadır:

### 1. Fingerprint V1 (Aktif - Production'da Kullanılan)

**Dosya:** `PaylisherDeviceFingerprint.swift` → `generateDeferredFingerprintV1()`

Bu yöntem, **web tarayıcısı ve native uygulama arasında ortak olan** bilgileri kullanır.

#### Kullanılan Parametreler

| Parametre | Örnek Değer | Kaynak |
|-----------|-------------|--------|
| Device Model | `"iPhone"` | `UIDevice.current.model` |
| OS Version | `"17.2"` | `UIDevice.current.systemVersion` |
| Screen Resolution | `"390x844"` | Portrait normalized, points |
| Timezone | `"Europe/Istanbul"` | `TimeZone.current.identifier` |
| Language Code | `"tr"` | `Locale.current.languageCode` |

#### Hash Algoritması

```
SHA256(model|osVersion|screenResolution|timezone|languageCode)
```

Örnek:
```
Input:  "iPhone|17.2|390x844|Europe/Istanbul|tr"
Output: "a1b2c3d4e5f6..." (64 karakter hex)
```

#### Avantajları

- ATT (App Tracking Transparency) izni **gerektirmez**
- Kullanıcıya popup göstermez
- Web ve native arasında tutarlı çalışır
- Privacy-compliant

#### Dezavantajları

- Benzersizlik oranı düşük (~60-70%)
- Aynı cihaz modeli, OS, lokasyon ve dile sahip kullanıcılar aynı fingerprint'e sahip olabilir
- False positive riski var

---

### 2. Rich Fingerprint (Pasif - Şu An Kullanılmıyor)

**Dosya:** `PaylisherDeviceFingerprint.swift` → `generate(includeIDFA:)`

Bu yöntem, daha fazla ve daha benzersiz cihaz bilgisi içerir.

#### Kullanılan Parametreler

| Parametre | Örnek Değer | ATT Gerekli mi? |
|-----------|-------------|-----------------|
| IDFV | `"A1B2C3D4-E5F6-..."` | Hayır |
| IDFA | `"X9Y8Z7W6-..."` | **Evet** |
| Device Model | `"iPhone14,2"` | Hayır |
| Device Name | `"iPhone"` | Hayır |
| OS Version | `"17.2"` | Hayır |
| Screen Resolution | `"390x844"` | Hayır |
| Timezone | `"Europe/Istanbul"` | Hayır |
| Locale | `"tr_TR"` | Hayır |
| Screen Scale | `"3.0"` | Hayır |

#### Neden Kullanılmıyor?

**Temel Sebep:** Web tarayıcısında IDFV ve IDFA **mevcut değil**.

```
┌─────────────────────────────────────────────────────────────────┐
│                    WEB TARAYICISI                                │
│                                                                  │
│  Erişilebilir:           Erişilemez:                            │
│  ✓ User-Agent            ✗ IDFV                                 │
│  ✓ Screen size           ✗ IDFA                                 │
│  ✓ Timezone              ✗ Device hardware ID                   │
│  ✓ Language              ✗ App-specific identifiers             │
│  ✓ IP adresi                                                    │
└─────────────────────────────────────────────────────────────────┘
```

Deferred deep link senaryosunda:
1. Kullanıcı **web'de** linke tıklar → Backend sadece tarayıcı bilgilerini alabilir
2. Kullanıcı **native app'te** uygulamayı açar → SDK tüm bilgilere erişebilir

**Eşleştirme için her iki tarafta da aynı bilgilerin olması gerekir.**

IDFV/IDFA web'de olmadığı için, bu bilgileri içeren Rich Fingerprint web click'i ile eşleştirilemez.

#### Rich Fingerprint Ne Zaman Kullanılabilir?

- App-to-App tracking (kullanıcı zaten uygulamayı yüklemiş)
- Re-engagement kampanyaları
- Aynı vendor'ın farklı uygulamaları arası takip (IDFV paylaşılır)

---

### Karşılaştırma Tablosu

| Özellik | Fingerprint V1 | Rich Fingerprint |
|---------|----------------|------------------|
| **Kullanım Durumu** | ✅ Aktif | ❌ Pasif |
| **Deferred Deeplink İçin** | ✅ Uygun | ❌ Uygun Değil |
| **ATT İzni** | Gerektirmez | Gerektirir (IDFA için) |
| **Benzersizlik** | Düşük (~60-70%) | Yüksek (~95%+) |
| **Web Uyumluluğu** | ✅ Tam uyumlu | ❌ Uyumsuz |
| **Privacy** | Tam uyumlu | ATT popup gerekli |

---

## Apple Privacy Framework'leri

### ATT (App Tracking Transparency)

**Durum: SDK'da kod mevcut, ancak production'da aktif kullanılmıyor.**

#### ATT Nedir?

iOS 14.5+ ile gelen, uygulamaların kullanıcıyı izlemek için **açık izin almasını** zorunlu kılan framework.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│     "Paylisher" uygulamasının sizi diğer şirketlerin            │
│     uygulamalarında ve web sitelerinde izlemesine               │
│     izin veriyor musunuz?                                        │
│                                                                  │
│     [Uygulamanın İzlemesine İzin Ver]                           │
│                                                                  │
│     [Uygulamadan İzlememesini İste]                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### SDK'daki ATT Kodu

```swift
// PaylisherDeviceFingerprint.swift - Satır 215-223
private func getIDFA() async -> String? {
    if #available(iOS 14.5, *) {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        guard status == .authorized else {
            return nil
        }
    }
    // IDFA alma işlemi...
}
```

#### Neden Aktif Kullanılmıyor?

1. **Deferred deeplink için gerekli değil** - Fingerprint V1 ATT gerektirmiyor
2. **Düşük izin oranı** - Kullanıcıların ~80%'i izni reddediyor
3. **Kullanıcı deneyimi** - İlk açılışta popup göstermek UX'i bozar
4. **Web uyumsuzluğu** - IDFA web'de zaten erişilemez

---

### SKAdNetwork (SKAN)

**Durum: SDK'da mevcut DEĞİL.**

#### SKAN Nedir?

Apple'ın privacy-focused attribution framework'ü. Reklam kampanyalarının performansını **anonim ve aggregate** şekilde ölçmeye yarar.

#### Nasıl Çalışır?

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Reklam     │───▶│    Apple     │───▶│  Uygulama    │
│    Ağı       │    │  (Aracı)     │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
                           │
                           ▼
                    Anonim ve gecikmeli
                    conversion data
```

#### Neden SDK'da Yok?

1. **Farklı kullanım amacı** - SKAN, reklam ağları (Facebook, Google Ads) entegrasyonu için
2. **Kısıtlı veri** - Conversion value sadece 0-63 arası, 24-48 saat gecikmeli
3. **Karmaşık implementasyon** - Her reklam ağı için ayrı entegrasyon gerekli
4. **Paylisher odağı** - Kendi kampanya/journey sistemi için deferred deeplink yeterli

#### SKAN Eklenebilir mi?

Evet, ancak genellikle şu durumlarda gereklidir:
- Facebook/Meta Ads kullanıyorsanız
- Google Ads kullanıyorsanız
- Diğer büyük reklam ağlarıyla çalışıyorsanız

---

## Sık Sorulan Sorular

### S: Neden IDFA kullanmıyoruz?

**C:** Üç temel sebep var:

1. **Web'de mevcut değil** - Kullanıcı linke web'de tıkladığında IDFA'ya erişim yok
2. **ATT izni gerekli** - Çoğu kullanıcı (~80%) izni reddediyor
3. **Deferred deeplink için gereksiz** - Fingerprint V1 bu iş için yeterli

### S: Fingerprint V1'in doğruluğu neden düşük?

**C:** Sınırlı parametre kullanılıyor. Aynı iPhone modeli, aynı iOS versiyonu, aynı şehir ve aynı dil ayarına sahip binlerce kullanıcı aynı fingerprint'e sahip olabilir.

### S: Doğruluğu nasıl artırabiliriz?

**C:** Birkaç yöntem var:

| Yöntem | Doğruluk Artışı | Dezavantaj |
|--------|-----------------|------------|
| IP adresi ekleme | +10-15% | Mobil ağlarda IP sık değişir |
| Attribution window daraltma | Daha az false positive | Bazı kullanıcıları kaçırabilir |
| Ek cihaz parametreleri | +5-10% | Web uyumluluğu kontrol edilmeli |

### S: Rich Fingerprint ne zaman kullanılır?

**C:** Şu senaryolarda kullanılabilir:
- Zaten yüklü uygulamadan başka bir uygulamaya yönlendirme
- Re-engagement kampanyaları (uygulama zaten yüklü)
- Aynı developer'ın farklı uygulamaları arası takip

### S: SKAN entegrasyonu yapmalı mıyız?

**C:** Eğer şu koşullar geçerliyse evet:
- Facebook/Google Ads gibi büyük reklam ağları kullanıyorsanız
- iOS app install kampanyaları yürütüyorsanız
- Reklam ROI'sini ölçmek istiyorsanız

Paylisher'ın kendi kampanya sistemi için mevcut deferred deeplink yeterlidir.

---

## Teknik Detaylar

### Dosya Yapısı

```
Paylisher/
├── PaylisherDeferredDeepLinkManager.swift   # Ana yönetici sınıf
├── PaylisherDeferredDeepLinkConfig.swift    # Konfigürasyon
├── PaylisherDeferredDeepLinkAPI.swift       # Backend API iletişimi
├── PaylisherDeviceFingerprint.swift         # Fingerprint üretimi
└── PaylisherFirstLaunchDetector.swift       # İlk açılış tespiti
```

### API Endpoint

```
GET https://link.paylisher.com/v1/deferred-deeplink?fingerprint={fingerprint}

Headers:
  Authorization: Bearer {apiKey}
  X-SDK-Version: paylisher-ios/{version}

Response:
{
  "status": "match" | "no_match",
  "url": "https://...",
  "campaignKey": "...",
  "jid": "...",
  "clickTimestamp": "2024-01-15T10:30:00Z",
  "metadata": {}
}
```

### Konfigürasyon Örneği

```swift
let config = PaylisherConfig(apiKey: "your-api-key")

// Deferred deep link ayarları
config.deferredDeepLinkConfig.enabled = true
config.deferredDeepLinkConfig.attributionWindowMillis = 86_400_000 // 24 saat
config.deferredDeepLinkConfig.debugLogging = false
config.deferredDeepLinkConfig.autoHandleDeepLink = true
```

---

## Özet

| Özellik | Durum | Açıklama |
|---------|-------|----------|
| **Deferred Deep Link** | ✅ Aktif | Fingerprint V1 ile çalışıyor |
| **Fingerprint V1** | ✅ Aktif | Web-uyumlu, ATT gerektirmez |
| **Rich Fingerprint** | ⏸️ Pasif | Kod mevcut, production'da kullanılmıyor |
| **ATT Entegrasyonu** | ⏸️ Pasif | Kod mevcut, aktif çağrılmıyor |
| **SKAN Entegrasyonu** | ❌ Yok | Gerekirse eklenebilir |

---

*Son güncelleme: Ocak 2025*
*SDK Versiyonu: Paylisher iOS SDK*
