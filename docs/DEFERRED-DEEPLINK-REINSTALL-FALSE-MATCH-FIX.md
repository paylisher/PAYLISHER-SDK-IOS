# Deferred Deeplink — Reinstall'da Mükerrer (False) Match Sorunu

## Kök Neden Analizi ve Backend Çözümü

> **Hedef kitle:** Campaign / Link backend ekibi (deferred-deeplink servisi)
> **İlgili endpoint:** `GET https://link-eu.paylisher.com/v1/deferred-deeplink?fingerprint=...`
> **İlgili SDK:** iOS 1.6.0+, Android 1.5.0+
> **Durum:** Production'da aktif bug — metrikleri (Deferred Deep Link Match) şişiriyor.

---

## 0. Bu Dokümanı Alan AI / Mühendis İçin (Handoff)

> Bu bölüm, dokümanı **soğuk** (önceki bağlam olmadan) alan bir AI veya mühendis içindir.

**Senin gördüğün vs görmediğin:**
- ✅ **Görüyorsun:** Backend / campaign-link servisinin kodu ve veritabanı şeması (bunlara erişimin olmalı).
- ❌ **Görmüyorsun:** SDK kodu (iOS/Android). SDK tarafının davranışı bu dokümanda §3'te özetlendi — fingerprint'in nasıl üretildiği ve reinstall'da neden yeniden sorgulandığı buradan anla, ayrıca SDK'ya bakmana gerek yok.
- ⚠️ **Bu dokümandaki teşhis, gözlemlenen davranıştan çıkarımdır** (yazarın backend koduna erişimi yoktu). Kesin kök nedeni **sen gerçek kodda doğrulayacaksın**.

**İzlemen gereken prosedür:**
1. **Doğrula:** §8 checklist'ini gerçek backend kodu üzerinde sırayla uygula. §4.4'teki 4 olası kök nedenden (filtre yok / consume çalışmıyor / atomik değil / mükerrer kayıt) hangisinin geçerli olduğunu tespit et.
2. **Eşle:** §5.1'deki single-use SQL'i **gerçek şemana** uyarla. Tablo/kolon adların farklıysa kavramı koru: *"match anında kaydı atomik olarak tüket; match sorgusu yalnızca tüketilmemiş + süresi dolmamış kayıt döndürsün."*
3. **Uygula:** Birincil fix = §5.1 (single-use). Savunma = §5.2 (TTL). Sırayla.
4. **Test et:** §9'daki kabul senaryolarını çalıştır. **Senaryo 2 (reinstall → `no_match`)** birincil regresyon kanıtıdır — bu geçmeden iş bitmiş sayılmaz.

**Veri deposu RDBMS değilse** (Mongo/Redis/Dynamo vb.) — kavramsal karşılıklar:
- **Single-use (atomik consume):** Mongo → `findOneAndUpdate({fingerprint, matched:false, expiresAt:{$gt:now}}, {$set:{matched:true, matchedAt:now}})` (atomik, tek çağrı). Redis → `SET ddl:matched:{fp} 1 NX` ile "ilk gelen tüketir" kilidi; ya da `GETDEL`. Dynamo → `UpdateItem` + `ConditionExpression: matched = false`.
- **TTL:** Mongo → `expiresAt` üzerine TTL index. Redis → `SET ... EX 1800`. Dynamo → TTL attribute.

**Bağımlılık:** Mümkünse `BACKEND-DEFERRED-DEEPLINK-API-SPEC.md` dosyasını da yanında iste (atıfların orijinali); ancak kritik şema/sorgu parçaları bu dokümanda inline mevcut, yoksa da ilerleyebilirsin.

**Dil:** Doküman Türkçe; gerekiyorsa İngilizceye çevirebilirsin, teknik kavramlar (single-use, atomic consume, TTL, attribution window) değişmez.

---

## 1. TL;DR (Özet)

**Belirti:** Bridge page'de "uygulamayı indir" butonuna **bir kez** basılıp fingerprint kaydedildikten sonra, **aynı cihazda** uygulamayı kaç kez silip yeniden kurarsak kuralım her seferinde `status: "match"` dönüyor ve `Deferred Deep Link Match` eventi basılıyor. Sanki her kurulum deeplink üzerinden gelmiş gibi sayılıyor.

**Kök neden:** Fingerprint **cihaz-türevli ve sabittir** (model + ekran genişliği + timezone + dil). Aynı fiziksel cihaz her reinstall'da **birebir aynı fingerprint'i** üretir. SDK'nın "ilk açılış" koruması ise reinstall'da **sıfırlanır** (UserDefaults/SharedPreferences silinir), bu yüzden SDK her reinstall'da backend'e **yeniden sorgu atar**. Dolayısıyla mükerrer match'i engelleyebilecek **tek yer backend'dir** — kayıt ya **tüketilmeli (single-use)** ya da **süresi dolmalı (TTL)**.

**Asıl mesele:** Mevcut [`BACKEND-DEFERRED-DEEPLINK-API-SPEC.md`](BACKEND-DEFERRED-DEEPLINK-API-SPEC.md) bu davranışı (`matched` flag + `expires_at`) **zaten tarif ediyor**. Yani bu bir tasarım eksikliği değil, **implementasyon ile spec'in uyuşmaması** (implementation gap). Match sorgusu büyük ihtimalle `matched = FALSE` filtresini uygulamıyor veya match anında `matched = TRUE` yazılmıyor.

**Çözüm (özet):**
1. **(BİRİNCİL) Single-use consume** — Match bulunduğunda kayıt **atomik** olarak `matched = TRUE` işaretlenmeli; match sorgusu `matched = FALSE` filtrelemeli. Bu, reinstall'daki mükerrer match'i **kesin** çözer.
2. **(SAVUNMA) Kısa TTL** — Attribution window 24 saatten **15–30 dk'ya** çekilmeli (fingerprint eşleşmesi olasılıksaldır, güveni hızla düşer) + expired kayıtlar fiziksel olarak silinmeli.
3. **(OPSİYONEL) IP + fingerprint daraltma** — Çakışma (collision) riskini azaltmak için.

> ⚠️ **Kritik düzeltme:** "5-15 dk sonra silinsin **VEYA** tek kullanımlık olsun" — bunlar OR değil, **single-use şart, TTL tamamlayıcı**. Çünkü sadece TTL koyarsan, o pencere içinde (örn. ilk 15 dk) yapılan reinstall'lar **hâlâ** mükerrer match verir. Tek başına single-use ise bug'ı tamamen kapatır. TTL'in görevi, hiç tüketilmemiş "yetim" kayıtların ileride alakasız bir kuruluma eşleşmesini engellemektir.

---

## 2. Sorunun Belirtisi (Gözlemlenen Davranış)

```
1. Cihaz X → bridge page → "Uygulamayı İndir" butonu (1 KEZ)
   → Web fingerprint F üretilir → POST .../deferred-deeplink/click → DB'ye kayıt
2. Cihaz X → uygulamayı kurar → ilk açılış → fingerprint F → GET .../deferred-deeplink?fingerprint=F
   → status: "match"  ✅ (DOĞRU — gerçek deferred deeplink kurulumu)
3. Cihaz X → uygulamayı SİLER → TEKRAR kurar → ilk açılış → fingerprint F (yine aynı!)
   → status: "match"  ❌ (YANLIŞ — bu deeplink kurulumu değil, sadece reinstall)
4. Adım 3 → N kez tekrarlanır → her seferinde "match" → metrik N kez şişer  ❌❌❌
```

**Beklenen davranış:** Adım 2'de **bir kez** match; adım 3 ve sonrasında `no_match`.

---

## 3. Mevcut Akış (SDK ↔ Backend Sözleşmesi)

Hem iOS hem Android SDK aynı sözleşmeyi kullanıyor (doğrulandı):

### 3.1 Fingerprint nasıl üretiliyor (V1)

| Bileşen | iOS kaynağı | Android kaynağı |
|---|---|---|
| Device model | `UIDevice.current.model` (örn. "iPhone") | `Build.MODEL` |
| Ekran genişliği (px) | `min(width, height) * scale` | `min(widthPixels, heightPixels)` |
| Timezone | `TimeZone.current.identifier` | `TimeZone.getDefault().id` |
| Dil kodu | `Locale.current.languageCode` (örn. "tr") | `Locale.getDefault().language` |

```
Ham string:  "iPhone|1170|Europe/Istanbul|tr"
             → SHA-256 → 64 karakter lowercase hex
```

> **NOT (commit `bce9d68`):** OS versiyonu fingerprint'ten **çıkarıldı**. iOS 26+ Safari, User-Agent OS token'ını dondurduğu için web tarafı gerçek `systemVersion`'ı okuyamıyordu → eşleşmeler hep başarısızdı. Artık fingerprint = `deviceModel|screenWidth|timezone|languageCode` (web + Android ile hizalı).

### 3.2 Match sorgusu

```http
GET https://link-eu.paylisher.com/v1/deferred-deeplink?fingerprint={64-hex}
Authorization: Bearer {apiKey}
X-SDK-Version: paylisher-ios/1.6.0   (veya paylisher-android/...)
```

Yanıt:
```json
{ "status": "match", "url": "...", "campaignKey": "...", "jid": "...",
  "clickTimestamp": "...", "attributionWindow": 86400, "metadata": {...} }
```
veya `{ "status": "no_match" }`. SDK karar mantığı: `status == "match"` → eventi bas.

### 3.3 SDK'nın "ilk açılış" koruması

iOS `PaylisherFirstLaunchDetector` / Android `PaylisherFirstLaunchDetector`:

```swift
// UserDefaults key: "paylisher_first_launch_has_launched"
func isFirstLaunch() -> Bool {
    let hasLaunched = userDefaults.bool(forKey: keyHasLaunched)
    if !hasLaunched {
        userDefaults.set(true, forKey: keyHasLaunched)   // bir daha asla true dönmez
        return true
    }
    return false
}
```

Bu koruma yalnızca **aynı kurulum içinde** mükerrer sorguyu engeller. **Reinstall'da bu flag silinir** → `isFirstLaunch()` yeniden `true` döner → SDK yeniden sorgu atar. **İşte sorun burada başlıyor.**

---

## 4. Kök Neden Analizi (Detaylı)

### 4.1 Fingerprint sabit ve cihaz-türevlidir; install'a özel değildir

V1 fingerprint yalnızca **donanım/ayar** sinyallerinden türüyor: `model | ekran genişliği | timezone | dil`. Bu değerlerin hiçbiri uygulamayı silip kurmakla değişmez. Dolayısıyla:

> **Aynı fiziksel cihaz → her zaman aynı fingerprint → sonsuza kadar.**

Bu **kasıtlı** bir tasarımdır: web tarafı (bridge page) IDFV/IDFA/Android-ID gibi install-spesifik kimliklere erişemediği için, web ile native'in **ortak** üretebileceği tek şey bu kaba (coarse) cihaz parmak izidir. Yani fingerprint'i "install başına benzersiz" yapmak **mümkün değil** — çözüm fingerprint'te değil, backend'in onu nasıl yönettiğinde.

### 4.2 SDK first-launch koruması reinstall'da sıfırlanır

`isFirstLaunch()` bayrağı UserDefaults (iOS) / SharedPreferences (Android) içinde tutulur. Uygulama silindiğinde bu depolama da silinir. Sonraki kurulumda bayrak yine "set edilmemiş" olur → SDK her reinstall'ı **gerçek bir ilk açılış** sanar ve backend'e sorgu atar. SDK katmanında bunu engellemenin güvenilir bir yolu yoktur (Keychain bile kullanıcı tarafından temizlenebilir ve cross-platform garanti edilemez).

### 4.3 Sonuç: Mükerrer match'i yalnızca backend engelleyebilir

İki gerçeği birleştirelim:
- Fingerprint reinstall'da **değişmez** (4.1).
- SDK reinstall'da **yeniden sorgu atar** (4.2).

⟹ Backend, aynı fingerprint için ikinci/üçüncü/... sorguları **ya tüketerek (single-use) ya da süre doldurarak (TTL)** elemek zorundadır. **Bu, mimarinin tek doğru noktasıdır.**

### 4.4 Bu bir tasarım eksikliği değil — implementasyon açığı

Mevcut [`BACKEND-DEFERRED-DEEPLINK-API-SPEC.md`](BACKEND-DEFERRED-DEEPLINK-API-SPEC.md) doğru davranışı **zaten** tanımlıyor:

- **Şema** (satır 231-233): `matched BOOLEAN DEFAULT FALSE`, `matched_at TIMESTAMP NULL`, `install_fingerprint`.
- **Match sorgusu** (satır 366-373): `... WHERE fingerprint = :fingerprint AND matched = FALSE AND expires_at > NOW() ...`
- **Match sonrası** (satır 384-390): `UPDATE ... SET matched = TRUE, matched_at = NOW() ...`
- **Test Senaryosu #4 "Already Matched"** (satır 780-786): 2. sorgu için **beklenen sonuç `no_match`**.

Production'da reinstall'ın her seferinde match vermesi, bu mantığın **çalışmadığını** kanıtlıyor. En olası nedenler (backend kodu bu repoda olmadığı için gözlemden çıkarım — backend ekibi kendi kodunda doğrulamalı):

| # | Olası kök neden | Nasıl doğrulanır |
|---|---|---|
| **1** | Match sorgusunda `AND matched = FALSE` **filtresi yok** | Sorgu loglarına/koda bak: filtre var mı? |
| **2** | Match bulunduğunda `UPDATE ... SET matched = TRUE` **çalışmıyor** (kod yok, transaction rollback, ya da yazma read-replica'ya gitmiyor) | Match sonrası DB'de ilgili satırın `matched` değeri gerçekten `TRUE` oluyor mu? |
| **3** | Attribution window 24 saat (default) ve testler bu pencere içinde yapılıyor; **#1 veya #2 ile birleşince** pencere boyunca her reinstall eşleşiyor | `expires_at` değeri ve test zaman aralığı |
| **4** | Bridge page `click` endpoint'ini her sayfa görüntülemede/birden çok kez çağırıyor → fingerprint başına **çok sayıda kayıt** birikiyor, her reinstall birini tüketiyor | `SELECT count(*) ... WHERE fingerprint = F` — 1'den fazla satır var mı? |

> **En güçlü şüpheli #1/#2'dir:** Kullanıcı butona **tek kez** bastığını belirtiyor. Eğer single-use gerçekten çalışsaydı, 24 saatlik pencere içinde bile **ikinci** reinstall `no_match` alırdı. "Her seferinde match" davranışı, `matched` flag mantığının uygulanmadığının doğrudan kanıtıdır.

---

## 5. Çözüm

### 5.1 (A) Single-use / Tek Kullanımlık Consume — **BİRİNCİL FİX**

**Kural:** Bir click kaydı yalnızca **bir kez** match'e dönüşebilir. Match anında kayıt atomik olarak tüketilir.

#### ❌ Yanlış (race condition'lı) — spec'teki mevcut pseudocode

```sql
-- 1) Önce oku
SELECT * FROM deferred_deeplink_clicks
WHERE fingerprint = :fp AND matched = FALSE AND expires_at > NOW()
ORDER BY click_timestamp DESC LIMIT 1;
-- 2) Sonra ayrı bir sorguyla işaretle
UPDATE deferred_deeplink_clicks SET matched = TRUE WHERE id = :id;
```

SELECT ile UPDATE arasında **TOCTOU** boşluğu var: aynı fingerprint'le iki eşzamanlı istek (SDK retry, ya da aynı profili paylaşan iki cihaz) aynı satırı okuyup ikisi de "match" alabilir → **çift sayım**.

#### ✅ Doğru — atomik / kilitli consume

**MySQL (spec şeması MySQL'e işaret ediyor — `INTERVAL`, `ON UPDATE CURRENT_TIMESTAMP`):**

```sql
START TRANSACTION;

-- Satırı kilitle (FOR UPDATE), başka transaction aynı satıra giremesin
SELECT id, deeplink_url, campaign_key, jid, click_timestamp,
       attribution_window_seconds, metadata
INTO   @id, @url, @ck, @jid, @cts, @aw, @meta
FROM   deferred_deeplink_clicks
WHERE  fingerprint = :fp
  AND  matched = FALSE
  AND  expires_at > NOW()
ORDER BY click_timestamp DESC
LIMIT  1
FOR UPDATE;                          -- 🔒 satır kilidi

-- Sadece kilitli satırı tüket
UPDATE deferred_deeplink_clicks
SET    matched = TRUE,
       matched_at = NOW(),
       install_fingerprint = :fp
WHERE  id = @id;

COMMIT;
-- @id NULL ise → no_match; değilse → match (@url, @ck, @jid ... ile yanıt dön)
```

**PostgreSQL (tek atomik ifade, en temiz):**

```sql
UPDATE deferred_deeplink_clicks AS c
SET    matched = TRUE, matched_at = NOW(), install_fingerprint = :fp
WHERE  c.id = (
         SELECT id FROM deferred_deeplink_clicks
         WHERE fingerprint = :fp AND matched = FALSE AND expires_at > NOW()
         ORDER BY click_timestamp DESC
         LIMIT 1
         FOR UPDATE SKIP LOCKED        -- 🔒 eşzamanlılık güvenli
       )
RETURNING c.deeplink_url, c.campaign_key, c.jid, c.click_timestamp,
          c.attribution_window_seconds, c.metadata;
-- 0 satır döndü → no_match; 1 satır döndü → match
```

Bu, **bug'ı kesin kapatan** değişikliktir: ilk install match alır ve kaydı tüketir; sonraki tüm reinstall'lar tüketilmemiş kayıt bulamaz → `no_match`.

### 5.2 (B) Kısa TTL + Fiziksel Temizleme — **SAVUNMA KATMANI**

Single-use, "click yapıldı ama hiç tüketilmedi" senaryosunda tek başına yetmez (bkz. §6). TTL bu yetim kayıtların ömrünü sınırlar.

**Değişiklikler:**

1. **Window'u kısalt.** Fingerprint eşleşmesi olasılıksaldır; güven dakikalar içinde düşer. Varsayılanı 24 saatten **30 dk'ya** çek (kampanya bazında konfigüre edilebilir kalsın).

   ```sql
   -- Click kaydında:
   expires_at = NOW() + INTERVAL 30 MINUTE   -- attribution_window_seconds = 1800
   ```

2. **Match sorgusu zaten `expires_at > NOW()` filtreli** (§5.1) — koru.

3. **Expired kayıtları fiziksel olarak sil** (yetim/eşleşmemiş kayıtlar birikmesin):

   ```sql
   -- Cron (örn. her 10 dk) veya event-scheduler:
   DELETE FROM deferred_deeplink_clicks
   WHERE expires_at < NOW() - INTERVAL 1 HOUR;   -- expire + kısa grace
   ```

   > Alternatif: MongoDB kullanılıyorsa `expires_at` üzerine **TTL index**; Redis kullanılıyorsa `SET fp:... EX 1800` ile otomatik expiry — uygulama kodu gerekmez.

#### Window süresi seçimi — trade-off

| Window | Artı | Eksi |
|---|---|---|
| **5 dk** | Çakışma/yetim riski en düşük | Yavaş indirme/dikkati dağılan kullanıcı **kaçırılır** (download + ilk açılış 5 dk'yı aşabilir) → gerçek attribution kaybı |
| **15–30 dk** ✅ | Tipik "tıkla → indir → aç" hunisi rahat sığar; çakışma penceresi dar | Dengeli — **önerilen** |
| **2–24 saat** | Gecikmeli kurulumları yakalar | Çakışma + yetim-eşleşme riski yüksek; reinstall penceresi uzun |

**Öneri:** Varsayılan **30 dk**, kampanya bazında ayarlanabilir. Hızlı huniniz varsa 15 dk daha da güvenli. **Ama unutma:** window uzunluğu reinstall bug'ını **çözmez** (onu single-use çözer); window yalnızca **tüketilmemiş** bir kaydın ne kadar süre eşleşebilir kaldığını belirler.

### 5.3 (C) IP + Fingerprint Daraltma — **OPSİYONEL (çakışma azaltır)**

V1 fingerprint kabadır (§6). Click ve install'ı **IP** (ya da `/24` subnet) ile de eşleştirmek, farklı kullanıcıların yanlışlıkla eşleşmesini azaltır:

```sql
WHERE fingerprint = :fp
  AND matched = FALSE
  AND expires_at > NOW()
  AND ip_address = :install_ip        -- ya da: AND ip_subnet24 = :install_subnet24
```

> **Uyarı / trade-off:** IP, tıklama (WiFi) ile açılış (hücresel) arasında değişebilir. Hard filtre yaparsan **gerçek** eşleşmeleri kaçırabilirsin. Bu yüzden IP'yi **güven artırıcı ikincil sinyal** olarak kullan (örn. fuzzy match'te skoru yükselten faktör), zorunlu eşitlik şartı olarak değil. Click endpoint zaten `ip_address` topluyor (spec satır 178) — altyapı hazır.

---

## 6. Single-use'un Önemli Yan Etkisi: Kaba Fingerprint Çakışması

Single-use'u açtıktan sonra backend ekibinin bilmesi gereken bir gerçek:

V1 fingerprint `model | ekran genişliği | timezone | dil`'den oluşur — **install'a değil, cihaz sınıfına** özgüdür. **Aynı model iPhone + aynı timezone + aynı dil**'e sahip iki **farklı kullanıcı** birebir **aynı fingerprint'i** üretir. Bu yüzden:

- **Single-use OLMADAN (mevcut durum):** 1 click → o profile sahip **tüm** install'lara sonsuza dek match. Aşırı sayım. (Senin bug'ın.)
- **Single-use İLE:** 1 click → **tam olarak 1** install'a match (penceredeki ilk gelen). İki farklı cihaz aynı profile sahipse ve ikisi de pencere içinde kurarsa, match **ilk kurana** gider (teknik olarak yanlış cihaz olabilir) — ama toplam **kardinalite doğru** (1 click = 1 match). Bu, mevcut sonsuz-sayımdan **kat kat iyidir**.

**Çakışmayı daha da azaltmak için:** kısa TTL (§5.2) + IP daraltma (§5.3). Bu ikisi pencereyi ve adres uzayını daralttığı için "yanlış cihaza atfetme" olasılığını pratikte ihmal edilebilir seviyeye indirir.

> **Sonuç:** Single-use her şeyi mükemmel yapmaz ama **doğru olanı** yapar: 1 tıklama = en fazla 1 attribution. Geri kalan iyileştirmeler (TTL, IP) çakışma olasılığını törpüler.

---

## 7. Idempotency / Retry Güvenliği (Opsiyonel İncelik)

SDK 10 sn timeout ile sorgu atıyor ve gözle görülür retry mantığı yok; first-launch bayrağı sorgudan **önce** set edildiği için pratikte **at-most-once** sorgu garantisi var. Yine de ağ retry'ına karşı sağlamlık istersen:

- **Grace/idempotency penceresi:** Bir kayıt tüketildikten sonra **kısa bir süre** (örn. 60 sn) **aynı** `install_fingerprint`'ten gelen tekrar sorguya, yeni kayıt tüketmeden **aynı** match yanıtını dön. Böylece "200 döndü ama SDK yanıtı işleyemeden öldü → retry" senaryosunda çift tüketim/çift event olmaz.

```sql
-- Consume etmeden önce: son 60 sn içinde bu fingerprint'e zaten match verilmiş mi?
SELECT deeplink_url, campaign_key, jid, ...
FROM   deferred_deeplink_clicks
WHERE  install_fingerprint = :fp
  AND  matched = TRUE
  AND  matched_at > NOW() - INTERVAL 60 SECOND
ORDER BY matched_at DESC LIMIT 1;
-- Varsa: aynı yanıtı dön (idempotent). Yoksa: §5.1 consume akışına gir.
```

Bu adım **opsiyoneldir**; birincil fix değil, sağlamlaştırmadır.

---

## 8. Backend Doğrulama Checklist'i

Backend kodu bu SDK reposunda olmadığı için aşağıdakiler gözlemlenen davranıştan teşhistir. Ekip kendi servisinde şunları doğrulamalı:

- [ ] Match sorgusunda `AND matched = FALSE` filtresi **var mı?**
- [ ] Match bulununca `UPDATE ... SET matched = TRUE, matched_at = NOW()` **gerçekten çalışıyor mu?** (Match sonrası DB satırını elle kontrol et.)
- [ ] SELECT ile UPDATE **atomik mi?** (Transaction + `FOR UPDATE` / `RETURNING`.) Yoksa race var.
- [ ] `expires_at` doğru hesaplanıyor mu ve sorgu `expires_at > NOW()` ile filtreliyor mu?
- [ ] Bir fingerprint için DB'de **kaç satır** birikiyor? (`SELECT count(*) ... WHERE fingerprint = F`) — bridge page `click`'i mükerrer çağırıyor olabilir.
- [ ] Match yazması **read-replica gecikmesinden** etkilenmiyor mu? (Match sorgusu primary'den mi okuyor?)
- [ ] Attribution window default değeri kaç? (Öneri: 1800 sn / 30 dk.)
- [ ] Expired kayıtlar için **temizleme job'ı** çalışıyor mu?

---

## 9. Test Senaryoları (Kabul Kriterleri)

| # | Senaryo | Beklenen |
|---|---|---|
| 1 | Click(F) → install(F) ilk sorgu | `match` ✅ |
| 2 | Senaryo 1'in ardından **reinstall(F)** → ikinci sorgu | **`no_match`** ✅ (şu an `match` dönüyor — bug) |
| 3 | Click(F) → 31 dk bekle → install(F) (window 30 dk ise) | `no_match` (expired) |
| 4 | Click(F) → install(F) `match` → **yeni** Click(F) → reinstall(F) | `match` ✅ (yeni, tüketilmemiş kayıt — meşru yeniden attribution bozulmamalı) |
| 5 | İki eşzamanlı sorgu(F) (race) | Yalnızca **biri** `match`, diğeri `no_match` (çift tüketim yok) |
| 6 | (Idempotency açıksa) `match` sonrası 60 sn içinde aynı F retry | Aynı `match` yanıtı, yeni kayıt tüketilmez |

Senaryo **2** birincil regresyon testidir — bug'ın çözüldüğünü bu kanıtlar. Senaryo **4** ise düzeltmenin meşru yeniden-attribution'ı bozmadığını garanti eder.

---

## 10. Metriklere Etkisi

- **Önce:** `Deferred Deep Link Match` eventi, reinstall sayısı kadar şişiyor → install attribution ve dönüşüm oranları yapay olarak yüksek.
- **Sonra:** Her gerçek tıklama en fazla **1** match üretir → metrikler gerçek davranışı yansıtır. (Geçmiş veriyi düzeltmek isterseniz: aynı `install_fingerprint` + aynı `campaign_key` için ilk `matched_at` dışındaki match event'lerini analiz tarafında deduplike edebilirsiniz.)

---

## 11. Özet: Ne Değişecek?

| Katman | Değişiklik | Öncelik |
|---|---|---|
| Match sorgusu | `matched = FALSE` filtresi + atomik `matched = TRUE` consume (`FOR UPDATE`/`RETURNING`) | 🔴 **Şart** |
| Attribution window | Default 24 saat → **30 dk** (konfigüre edilebilir) | 🟠 Önerilen |
| Temizleme | Expired kayıtları silen cron/TTL-index | 🟠 Önerilen |
| IP daraltma | `ip_address` ikincil güven sinyali | 🟢 Opsiyonel |
| Idempotency | 60 sn grace penceresi | 🟢 Opsiyonel |

**Tek cümlelik özet:** Fingerprint sabit ve SDK reinstall'da yeniden sorguladığı için, mükerrer match'i yalnızca backend'in **kaydı tek kullanımlık tüketmesi** engelleyebilir; spec bunu zaten söylüyor, eksik olan tek şey implementasyonun bunu gerçekten uygulaması.

---

**Doküman versiyonu:** 1.0
**Tarih:** 2026-06-19
**İlgili:** [`BACKEND-DEFERRED-DEEPLINK-API-SPEC.md`](BACKEND-DEFERRED-DEEPLINK-API-SPEC.md), commit `bce9d68` (OS version exclusion)
