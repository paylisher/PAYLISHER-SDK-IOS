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

