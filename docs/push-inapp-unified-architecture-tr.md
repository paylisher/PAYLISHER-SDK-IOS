# Push + In-App Mesajlaşma Platformu
## (Firebase'e Daha Az Bağımlı, Self-Service, Ölçeklenebilir Mimari)

## 1. Bu Doküman Ne İçin?
Bu doküman, `UsePublisher (panel)` + `Engage Service (backend)` kullanılarak:

- sadece In-App değil,
- **Push Notification + In-App Messaging birlikte**

çalışacak bir mesajlaşma platformunun nasıl kurulacağını açıklar.

Bu sürüm özellikle iki hedefi birlikte düşünür:

1. Ürün ekiplerinin panelden kolayca kampanya oluşturması (self-service)
2. Mesajların teknik olarak güvenilir ve hızlı şekilde çalışması

---

## 2. Konuyu Yalın Anlatım (Teknik Olmayan Özet)

### 2.1 Basitçe ne kuruyoruz?
Bir “mesaj merkezi” kuruyoruz. Bu merkez iki tür mesajı yönetiyor:

- Push: telefona sistem bildirimi olarak düşen mesaj
- In-App: uygulama açıkken görünen modal/banner/carousel mesaj

### 2.2 Kullanıcı tarafında ne olacak?
Pazarlama/ürün ekibi panelden kampanya oluşturacak:

- Kime gidecek? (segment, ülke, cihaz, app versiyon)
- Ne zaman gidecek? (event olunca, belirli saatte, belli ekranlarda)
- Hangi formatta gidecek? (push veya in-app)

### 2.3 Sistem ne yapacak?
Sistem gelen event'leri dinleyecek (ör. `purchase`, `add_to_cart`) ve anında karar verecek:

- Bu kullanıcı bu kampanyaya uygun mu?
- Bugün bu kullanıcıya zaten çok mesaj gitti mi?
- Uygunsa mesajı gönder / göster

### 2.4 Neden önemli?
Bu sayede Firebase In-App Messaging gibi dış bağımlılıklar azalır, kontrol sizde olur, SaaS/multi-tenant büyümeye uygun yapı kurulur.

---

## 3. Mevcut Durum (As-Is) Özeti

Kod incelemesiyle görülen ana durum:

- Engage backend, `Push` modeli ile Push + In-App birlikte yönetiyor.
- Panel tarafı (`UsePublisher`) zaten Push/In-App oluşturma ekranlarına sahip.
- Action-based tetikleme mevcut.
- Mesaj gönderiminde Firebase Admin (FCM) yoğun kullanılıyor.
- In-App şu anda çoğunlukla “silent push ile payload taşıma” yaklaşımında.
- Event ingestion ve event store Engage içinde native bir pipeline olarak tam ayrışmış değil; DataStudio sorgularına bağımlılık var.

---

## 4. Neden Revize Mimari Gerekli?

Mevcut yapı çalışsa da aşağıdaki noktalarda zorlanır:

- Event yoğunluğu arttıkça sorgu-tabanlı tetikleme maliyetli olur.
- Push ve In-App aynı iş kurgusunu farklı kod yollarında taşır; yönetim zorlaşır.
- Self-service panel ile backend kural motoru arasında daha güçlü bir standart sözleşme gerekir.
- Multi-tenant güvenlik/sınırlandırma kurallarını merkezi hale getirmek gerekir.

---

## 5. Hedef Mimari (To-Be): Unified Messaging Engine

### 5.1 Ana prensip
**Tek Campaign Engine + iki kanal (Push, In-App).**

Yani karar mekanizması ortaktır; sadece son “delivery” adımı kanala göre değişir.

### 5.2 Bileşenler

1. Event Ingestion Service  
SDK ve backend event'lerini toplar.

2. Campaign Service  
Campaign CRUD + publish/archive + versiyon yönetimi.

3. Trigger/Decision Engine  
Kuralı değerlendirir: event, screen, segment, zaman, frequency.

4. Delivery Orchestrator  
- Push için queue/outbox + provider gönderimi  
- In-App için cache + client fetch

5. Analytics Collector  
sent/delivered/open/click/dismiss/conversion eventlerini toplar.

### 5.3 Kısa veri akışı

```text
SDK Event -> Event API -> Queue -> Trigger Engine
Trigger Engine -> Uygun campaign'leri bulur -> Frequency kontrolü
Sonuç:
  Push  -> Outbox/Queue -> Push Provider -> Cihaza bildirim
  InApp -> Delivery Cache -> SDK /messages çağrısı -> Uygulama içinde gösterim
```

---

## 6. Push ve In-App Birlikte Nasıl Çalışacak?

### 6.1 Ortak campaign modeli
Campaign objesi kanal-bağımsız tutulur, kanal özel alanlar `channelConfig` içinde olur.

Örnek:

```json
{
  "id": "cmp_123",
  "channel": "push",
  "trigger": { "type": "event", "eventName": "purchase" },
  "targeting": { "country": ["TR"], "appVersionMin": "2.0.0" },
  "frequency": { "perDay": 2, "perSession": 1, "lifetime": 5 },
  "content": { "title": "Teşekkürler", "body": "İndirim kuponunuz hazır" }
}
```

In-App için örnek:

```json
{
  "id": "cmp_456",
  "channel": "inapp",
  "trigger": { "type": "screen", "screenName": "checkout" },
  "targeting": { "segmentIds": ["seg_cart_abandoners"] },
  "frequency": { "perDay": 1, "perSession": 1 },
  "content": { "layoutType": "modal", "blocks": [] }
}
```

### 6.2 Ortak karar kuralları

- Campaign aktif mi?
- Şu an zaman penceresi içinde mi?
- Kullanıcı hedefe uyuyor mu?
- Frequency limiti aşılmış mı?
- Kanal ve cihaz uygun mu?

### 6.3 Son adım

- Push: sistem push gönderir.
- In-App: sistem “gösterilecek mesaj listesi” döner, SDK render eder.

---

## 7. Trigger Sistemi (Detay)

Desteklenecek trigger tipleri:

- Event bazlı (ör. `purchase`, `add_to_cart`)
- Screen bazlı (ör. `screen_view=checkout`)
- Segment bazlı (ör. “yüksek değerli kullanıcılar”)
- Zaman bazlı (ör. cuma 18:00)

Ek koşullar:

- Event property filter (`price > 100`)
- Kullanıcı property filter (`country = TR`)
- App version / device type

---

## 8. Targeting ve Frequency Kontrol

### 8.1 Targeting alanları

- `user_id`
- `segment`
- `country`
- `device_type`
- `app_version`
- `event condition`

### 8.2 Frequency kuralları

- Günde max X kez
- Session başına 1 kez
- User lifetime boyunca 1 kez
- Cooldown (ör. son 2 saat tekrar gösterme)

### 8.3 Suppression örnekleri

- Son 10 dakikada push aldıysa in-app gösterme
- Öncelik kuralı: aynı anda 3 kampanya çıkarsa en yüksek priority olanı göster

---

## 9. Delivery Mimarisi: Push ve In-App İçin Ayrım

## 9.1 Push delivery

- Outbox tablosu + queue + worker pattern
- Retry + exponential backoff + DLQ
- Provider abstraction (FCM/APNs/HMS)

## 9.2 In-App delivery

- Hybrid model önerilir:
  - Event sonrası client hızlı fetch yapar
  - App açılışında/per-screen fetch
- Bu sayede websocket zorunlu olmaz, mobilde daha basit olur.

## 9.3 Hangi model ne zaman?

- Push: asenkron, kuyruklu model
- In-App: düşük gecikmeli fetch model

---

## 10. Firebase Konusu: Net ve Gerçekçi Çerçeve

Bu kısım karıştığı için yalın anlatım:

- In-App campaign/trigger kararını tamamen kendi backendinizde tutabilirsiniz.  
- Android push transport tarafında pratikte FCM hâlâ gerekli olabilir (GMS cihaz ekosistemi).  
- Yani “Firebase bağımsızlığı”nı ikiye ayırın:
  1. **Orchestration bağımsızlığı**: campaign, targeting, trigger, analytics sizde
  2. **Transport bağımlılığı**: Android push taşıma katmanı FCM olabilir

Bu yaklaşım gerçekçi ve üretime uygundur.

---

## 11. Panel (UsePublisher) İçin Ürün Akışı

Panelde kullanıcı akışı:

1. Campaign oluştur
2. Kanal seç (`push` / `inapp`)
3. Trigger seç
4. Targeting ve frequency ayarla
5. İçerik hazırla (template/editor)
6. Preview/Test
7. Publish

İyileştirme önerileri:

- Channel-aware wizard (aynı ekran, kanal seçimine göre alanlar değişsin)
- “Eligible user estimate” (yaklaşık erişim sayısı)
- Publish öncesi doğrulama checklist
- Versiyonlama ve rollback

---

## 12. SDK Entegrasyonu (Mobil)

SDK görevleri:

1. Event gönderme
2. In-App mesaj çekme
3. Push action eventlerini raporlama
4. Impression/click/dismiss eventlerini gönderme

Önerilen endpointler:

- `POST /events`
- `GET /messages/inapp`
- `POST /messages/events` (impression/click/dismiss/open/conversion)

---

## 13. Veri Modeli (Öneri)

Önerilen ana tablolar:

- `campaign`
- `campaign_version`
- `campaign_trigger_rule`
- `campaign_target_rule`
- `campaign_frequency_rule`
- `delivery_log`
- `user_frequency_counter`
- `dead_letter`

Mevcut `Push` tablosu ile iki yol:

1. Kısa vadede mevcut yapıyı genişletme
2. Orta vadede normalize campaign tablolarına geçiş

---

## 14. Performans ve Ölçeklenebilirlik

Hedef metrikler:

- Trigger değerlendirme p95: < 50ms
- In-App fetch p95: < 120ms
- Event ingest p95: < 30ms

Teknik öneriler:

- Redis: aktif campaign index + frequency counter + segment cache
- Queue: event ve push dispatch ayrımı
- Worker horizontal scaling
- DLQ ve retry dashboard

---

## 15. Güvenlik

Zorunlu kontroller:

- Tenant izolasyonu (`teamId/projectId/sourceId`)
- Role-based access (publish/archive admin)
- Audit log (kim neyi ne zaman publish etti)
- Rate limit ve replay koruması
- Secret yönetimi (repo içinde private key tutulmamalı)

---

## 16. Fazlı Entegrasyon Planı

## Phase 1 — Event Ingestion

- Event API + şema standardı
- Queue ve temel ingestion worker
- Tenant/auth/idempotency

## Phase 2 — Campaign Management

- Unified campaign CRUD
- Draft/Live/Archived lifecycle
- Panelde kanal seçimli campaign builder

## Phase 3 — Trigger & Decision Engine

- Rule evaluator
- Targeting + frequency + suppression
- Redis index/counter

## Phase 4 — Delivery

- Push: outbox + queue + provider adapter
- In-App: hybrid fetch + cache
- Retry + DLQ + monitoring

## Phase 5 — SDK & UI Hardening

- SDK telemetry tamamlanması
- Preview/Test/Approval ekranları
- Operasyon dashboardları

---

## 17. Risks ve Karar Noktaları

1. Event store kimin sorumluluğunda olacak? (DataStudio vs internal)
2. Android push transport tamamen Firebase’siz isteniyor mu?
3. Push ve In-App için tek campaign mi, ayrı campaign mi?
4. Segment hesaplama online mı, snapshot mı?
5. Multi-tenant quota/limit stratejisi nasıl olacak?

---

## 18. Sonuç

Bu mimariyle:

- Push + In-App tek merkezden yönetilir,
- ürün ekipleri self-service olur,
- event bazlı gerçek zamanlı tetikleme mümkün olur,
- Firebase bağımlılığı karar motoru seviyesinde büyük ölçüde kaldırılır,
- sistem SaaS ve multi-tenant büyümeye uygun hale gelir.

