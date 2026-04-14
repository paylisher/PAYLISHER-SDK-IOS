# 📌 SDK Identify Davranışı – Multi-Device Problem Analizi

## 🎯 Problem Tanımı

`identify(distinctId)` fonksiyonu kullanıcıyı bir People profiline bağlamak için kullanılmaktadır.

Mevcut sistem davranışı:

- Eğer People yoksa oluşturulur
- Varsa güncellenir
- Ancak aynı `distinctId` ile tekrar çağrıldığında **event her zaman tetiklenmez**

Bu durum SDK içinde bir cache/state mekanizmasının `identify` çağrılarını suppress ettiğini göstermektedir.

---

## 🚨 Kritik Senaryo (Detaylı Akış)

Bu senaryo problemin en kritik kısmıdır ve doğru anlaşılması gerekmektedir.

### 🧩 Temel Gerçekler

- Kullanıcılar **çok nadiren logout olur**
- `reset()` fonksiyonu sadece logout sırasında çalışır
- Çoğu durumda `reset()` **hiç tetiklenmez**
- Her cihaz kendi local cache/state bilgisini tutar
- Aynı kullanıcı birden fazla cihazdan aktif olabilir

---

## 🔄 Adım Adım Gerçek Kullanım Senaryosu

### 🟢 1. Adım – İlk Login (iOS - A Cihazı)

- Kullanıcı: `userId = 1234`
- Cihaz: iOS (A)

```text
identify(1234)
```

✅ Sonuç:

- People profili oluşturulur
- Device bilgisi iOS olarak set edilir
- Identify event tetiklenir

---

### 🟡 2. Adım – İkinci Login (Android - B Cihazı)

- Aynı kullanıcı: `1234`
- Farklı cihaz: Android (B)

```text
identify(1234)
```

✅ Sonuç:

- People güncellenir
- Device bilgisi Android olur
- Identify event tetiklenir

---

### 🔴 3. Adım – Kritik Kırılım (Tekrar iOS - A Cihazı)

- Kullanıcı tekrar iOS cihazına döner
- Uygulama background’dan açılır
- Logout yapılmamıştır
- `reset()` çalışmamıştır
- SDK eski state’i tutmaktadır

```text
identify(1234)
```

❌ Sonuç:

- Identify event tetiklenmez
- People güncellenmez
- Sistem kullanıcıyı zaten identify edilmiş kabul eder

---

## ⚠️ Problemin Etkisi

- Backend’de kullanıcı yanlış cihaz bilgisi ile görünür
- Gerçek aktif cihaz ile sistem verisi uyuşmaz
- Multi-device kullanım senaryosu bozulur
- Analitik ve aksiyon sistemleri yanlış çalışır

---

## 🧠 Problemin Özeti

Bu durum teknik olarak bir bug olmayabilir ancak:

> Mevcut SDK davranışı multi-device kullanım senaryosuna uygun değildir

SDK varsayımı:

> Aynı `distinctId` tekrar gelirse identify etmeye gerek yok

Bizim ihtiyacımız:

> Aynı kullanıcı farklı cihazlardan aktif olabilir ve her girişte state güncellenmelidir

---

## 🎯 Beklenen Davranış

Her `identify()` çağrısı:

- Event üretmelidir
- People update tetiklemelidir
- Özellikle device değişiminde kesinlikle çalışmalıdır

---

## 🔍 Analiz Beklentileri

### 1. Root Cause Analizi

- SDK neden identify çağrılarını suppress ediyor?
- Cache/state mekanizması nasıl çalışıyor?
  - distinctId bazlı mı?
  - session bazlı mı?
  - device bazlı mı?

---

### 2. Mevcut Tasarımın Amacı

- Duplicate event önleme
- Performans optimizasyonu
- Network yükünü azaltma

---

### 3. Bu Senaryo Neden Problematik?

- Multi-device kullanım
- Logout yapılmaması
- Uzun yaşayan session’lar

---

## 🛠️ Çözüm Alternatifleri

### 🔹 Seçenek 1: Force Identify

```js
identify(1234, { force: true })
```

### 🔹 Seçenek 2: Device Change Detection

- Device değiştiğinde identify zorunlu tetiklenir

### 🔹 Seçenek 3: Soft Reset

- Logout olmadan state sıfırlama

### 🔹 Seçenek 4: Session Bazlı Identify

- Her app açılışında identify çağrılır

### 🔹 Seçenek 5: Always Emit Identify Event

- Backend tarafında deduplication yapılır

---

## 🏗️ Mimari Beklenti

Önerilecek çözüm:

- Multi-device uyumlu olmalı
- Veri tutarlılığı sağlamalı
- Geriye dönük uyumlu olmalı
- Mevcut sistemi bozmamalı

---

## 🚀 Uygulama Beklentisi

- SDK değişikliği gerekip gerekmediği
- Backend ile çözülebilirlik
- Hybrid yaklaşım önerileri

---

## 🚫 Kısıtlar

- Mevcut sistem kırılmamalı
- Geriye dönük uyumluluk korunmalı
- Veri doğruluğu kritik

---

## 📌 Not

Bu problem yüzeysel değil, sistem tasarımı seviyesinde ele alınmalıdır. Çözüm önerileri trade-off’ları ile birlikte sunulmalıdır.


---

# 📌 SDK Identify Yanlış Kullanıcıya Event Yazma Problemi (Login Switch Case)

## 🎯 Problem Tanımı

Aynı cihaz üzerinde kullanıcı değişimi (login switch) yapıldığında, event’lerin eski kullanıcı (`distinctId`) üzerine yazılmaya devam ettiği gözlemlenmektedir.

Bu durum veri bütünlüğünü doğrudan bozan **kritik bir problemdir**.

---

## 🚨 Kritik Senaryo (NET ve DETAYLI AKIŞ)

Bu senaryonun doğru anlaşılması çok kritik. Problem burada oluşuyor:

### 🧩 Temel Gerçekler

- SDK cihaz üzerinde **current distinctId state’i** tutar
- Bu state genellikle **persistent storage (cache)** içinde saklanır
- Uygulama kapansa bile bu bilgi kaybolmaz
- `reset()` çağrılmadıkça bu state temizlenmez
- Login akışında çoğu zaman `reset()` çağrılmaz

---

## 🔄 Adım Adım Gerçek Senaryo

### 🟢 1. Adım – İlk Kullanıcı Login

- Kullanıcı: `123`

```text
identify(123)
```

✅ Sonuç:
- current distinctId = 123
- Event’ler doğru şekilde 123 kullanıcısına yazılır

---

### 🟡 2. Adım – Uygulama Kapanır / Restart Olur

- Uygulama kill edilir
- Tekrar açılır

⚠️ Kritik nokta:
- SDK cache’ten **distinctId = 123** bilgisini tekrar yükler
- Yani kullanıcı state’i hala 123’tür

---

### 🔴 3. Adım – Farklı Kullanıcı ile Login

- Yeni kullanıcı: `12`

```text
identify(12)
```

❌ GERÇEKLEŞEN:
- SDK internal state’i override etmez
- current distinctId = 123 olarak kalır
- Yeni event’ler → 123’e yazılır

---

## ⚠️ Problemin Net Özeti

- Kullanıcı değişiyor (123 → 12)
- Ama SDK bunu **state seviyesinde kabul etmiyor**
- Event pipeline eski kullanıcı ile devam ediyor

---

## ✅ Beklenen Davranış

```text
identify(12)
```

- current distinctId → 12 olmalı
- Tüm yeni event’ler → 12’ye yazılmalı
- Eski kullanıcı ile hiçbir bağ kalmamalı

---

## ❌ Gerçekleşen Davranış

- current distinctId → 123 olarak kalıyor
- Event’ler → 123’e yazılmaya devam ediyor

---

## 🧪 Debug Gözlemleri (AI için kritik)

- Event payload’larında distinctId = 123 gelmeye devam ediyor
- identify(12) çağrısı yapılmasına rağmen state değişmiyor
- Event queue eski kullanıcıya bağlı olabilir
- SDK init sırasında cached distinctId tekrar yükleniyor olabilir
- Identify çağrısı event pipeline’dan sonra uygulanıyor olabilir

---

## 🧠 Olası Root Cause

- `identify()` mevcut distinctId override etmiyor olabilir
- Internal state yalnızca ilk set’te belirleniyor olabilir
- Event queue flush edilmeden kullanıcı değişiyor olabilir
- Persistent storage doğru güncellenmiyor olabilir
- Identify çağrısı pipeline’da geç kalıyor olabilir

---

## 🔍 Senden Beklentim

### 1. Root Cause Analizi

- SDK neden yeni distinctId ile override etmiyor?
- Identify state hangi aşamada set ediliyor?
- Event queue ile identify sıralaması nasıl?

---

### 2. Geliştirme Yapmadan Çözüm (Workaround)

Aşağıdaki seçenekleri değerlendir:

#### 🔹 Opsiyon 1: Login Öncesi Reset
```text
reset()
identify(newUserId)
```

#### 🔹 Opsiyon 2: Flush + Identify
- Önce event queue flush edilir
- Sonra identify çağrılır

#### 🔹 Opsiyon 3: App Start Identify
- Her app açılışında identify zorunlu

#### 🔹 Opsiyon 4: Backend Kontrolü
- Gelen event’te user mismatch tespit edilirse engellenir

---

### 3. Kalıcı Çözüm (Geliştirme Gerekiyorsa)

#### 🔹 Seçenek 1: Identify Always Override
- Yeni identify → state’i zorla günceller

#### 🔹 Seçenek 2: DistinctId Change Detection
- Eğer farklıysa otomatik reset + identify

#### 🔹 Seçenek 3: Atomic Identify
- Identify tüm pipeline’dan önce uygulanır

#### 🔹 Seçenek 4: Event Queue Isolation
- Event queue user bazlı ayrılır

---

## 🏗️ Mimari Beklenti

- Kullanıcı değişimi deterministic olmalı
- Event hiçbir koşulda yanlış kullanıcıya yazılmamalı
- State yönetimi güvenilir olmalı

---

## 🚀 Uygulama Planı

- Önce hızlı workaround
- Ardından kalıcı SDK çözümü
- Geriye dönük uyumluluk korunmalı

---

## 🚫 Kısıtlar

- Mevcut sistem kırılmamalı
- Veri kaybı olmamalı
- Yanlış kullanıcıya event yazımı kesinlikle engellenmeli

---

## 📌 Not

Bu problem veri doğruluğu açısından **kritik seviyededir**. Çözüm önerileri güçlü garanti sağlamalı ve edge-case’leri kapsamalıdır.

