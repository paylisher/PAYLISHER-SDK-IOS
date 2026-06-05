# Unified Messaging Platform Technical Spec (TR)
## Push + In-App Ortak Mimari, Uygulama Planı ve Operasyon Rehberi

Sürüm: `v1.0`  
Tarih: `2026-03-13`  
Durum: `Draft for Engineering Alignment`

## 1. Amaç ve Kapsam
Bu doküman, Push Notification ve In-App Messaging için tek bir campaign/trigger/targeting altyapısının teknik tasarımını verir. Amaç:

- Self-service campaign yönetimi
- Event/screen/segment/time tabanlı tetikleme
- Multi-tenant ve SaaS uyumlu ölçeklenebilir mimari
- Push + In-App için ortak karar motoru
- Mevcut sistemle geriye dönük uyumluluk ve kademeli migration

Bu doküman frontend, backend, mobile SDK ve AI destekli geliştirme akışının ortak referansıdır.

---

## 2. Hedef Kitle

- Backend geliştiriciler (Engage, event pipeline, delivery workers)
- Frontend geliştiriciler (UsePublisher campaign UI)
- Mobile SDK geliştiriciler (iOS/Android render + telemetry)
- DevOps/SRE (deploy, scaling, observability)
- QA (integration, e2e, non-functional tests)
- AI agents (code analysis, scaffolding, regression checks)

---

## 3. Problem Tanımı

Mevcut yapı Push ve In-App’i teknik olarak destekliyor ancak:

1. Event trigger değerlendirmesi dış sorgu bağımlılığı (DataStudio query-time evaluation) taşıyor.
2. Push ve In-App akışları tek domain altında olsa da delivery ve kural katmanı ayrılaşmış, maintainability düşüyor.
3. In-App tarafı çoğunlukla “silent push ile payload taşıma” yaklaşımında; native pull/hybrid in-app delivery eksik.
4. FE’de campaign deneyimi var ama segment estimate, validation pipeline, rollout/approval gibi enterprise özellikler sınırlı.
5. Multi-tenant sınırlandırma/güvenlik/denetim log gereksinimleri tek bir standart altında netleşmiş değil.

---

## 4. Non-Goals (Bu Fazda Yapılmayacaklar)

- Tamamen yeni bir panel tasarım sistemi yazmak
- Tek seferde tüm eski endpointleri kaldırmak
- Tek adımda tüm müşterileri yeni altyapıya geçirmek
- Push transport katmanını her platformda tamamen Firebase’siz yapmak (özellikle Android GMS cihazlarda FCM gerçekliği korunur)

---

## 5. Terminoloji

- Campaign: Kural + hedef + içerik + kanal + yaşam döngüsü
- Channel: `push` veya `inapp`
- Trigger: campaign’in aktifleşmesini başlatan koşul
- Decision: kullanıcıya mesaj göster/gönder kararı
- Delivery: karar sonrası kanal bazlı iletim
- Frequency Cap: kullanıcıya mesaj gösterim sınırı
- Suppression: mesajı bilerek baskılama (örn. cooldown)
- Tenant: `teamId + projectId + sourceId`

---

## 6. As-Is Mimari Özeti (Kod Bazlı)

Not: Bu bölüm mevcut uygulama davranışını teknik referans için özetler.

- Engage runtime mode: `lite` / `micro`
- Modüller: `client`, `batch`, `producer`, `dispatcher`
- Push + In-App ortak modeli: `Push` tablosu (`notificationType` ayrımı)
- Outbox + Kafka + consumer worker yapısı mevcut
- Event alias/screen alias CRUD mevcut
- Action-based trigger değerlendirmesi DataStudio query ile yapılıyor

Ana referans kodlar:

- `usePublisher.Engage/src/modules/push/push.service.ts`
- `usePublisher.Engage/src/Data.Studio.service.ts`
- `usePublisher.Engage/src/Fcm.Messaging.Service.ts`
- `usePublisher.Engage/prisma/schema.prisma`
- `usePublisher/source-api/repositories/push.repository.ts`
- `usePublisher/components/team/others/notification/EditPage.tsx`

---

## 7. To-Be Mimari: Unified Messaging Engine

## 7.1 Yüksek seviye bileşenler

1. `Campaign Service`
2. `Event Ingestion Service`
3. `Trigger & Decision Engine`
4. `Delivery Orchestrator`
5. `Analytics & Telemetry Service`
6. `Segment Resolver`
7. `Frequency/Suppression Service`
8. `Template/Preview Service`

## 7.2 Yüksek seviye akış

```text
[Client SDK] --events--> [Event API] --> [Event Queue]
                                 |
                                 v
                      [Trigger/Decision Engine]
                      /           |            \
                     /            |             \
          [Campaign Index] [Segment Cache] [Frequency Store]
                    |
                    v
             [Eligible Messages]
               /             \
              /               \
      channel=push         channel=inapp
      -> Outbox/Queue      -> InApp Cache
      -> Provider Send      -> SDK Fetch
```

---

## 8. Domain Model (Önerilen)

## 8.1 Ana varlıklar

- `campaign`
- `campaign_version`
- `campaign_rule`
- `campaign_targeting`
- `campaign_frequency`
- `campaign_content`
- `delivery_attempt`
- `delivery_dead_letter`
- `event_ingestion_log`
- `user_frequency_counter`

## 8.2 Prisma taslak (özet)

```prisma
model Campaign {
  id             String   @id @default(uuid())
  tenantTeamId   String   @db.Uuid
  tenantProjectId String  @db.Uuid
  tenantSourceId String   @db.Uuid
  name           String
  channel        CampaignChannel // push | inapp
  status         CampaignStatus  // draft | live | paused | archived
  priority       Int      @default(100)
  version        Int      @default(1)
  createdBy      String
  updatedBy      String
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt

  @@index([tenantTeamId, tenantProjectId, tenantSourceId, status])
  @@index([channel, status])
}

enum CampaignChannel {
  push
  inapp
}

enum CampaignStatus {
  draft
  live
  paused
  archived
}
```

## 8.3 Geriye dönük uyumluluk

Kısa vadede:

- Eski `Push` tablosu yazılmaya devam eder.
- Yeni `Campaign*` tabloları paralel doldurulur (dual-write).
- Read path feature flag ile yeni modele kademeli alınır.

Orta vadede:

- Legacy `Push.notificationJson` taşıma alanı minimize edilir.
- Kanonik kaynak `Campaign*` olur.

---

## 9. Event Sözleşmesi

## 9.1 Event payload standardı

```json
{
  "eventId": "evt_01H...",
  "eventName": "purchase",
  "eventTime": "2026-03-13T10:21:30.123Z",
  "tenant": {
    "teamId": "uuid",
    "projectId": "uuid",
    "sourceId": "uuid"
  },
  "user": {
    "userId": "u_123",
    "deviceId": "d_987",
    "sessionId": "s_456",
    "platform": "android",
    "appVersion": "2.4.1",
    "country": "TR"
  },
  "properties": {
    "amount": 199.9,
    "currency": "TRY"
  }
}
```

## 9.2 Endpoint

`POST /v2/events/ingest`

Başarı cevabı:

```json
{
  "accepted": true,
  "eventId": "evt_01H...",
  "traceId": "trc_..."
}
```

## 9.3 Idempotency ve Tekilleştirme (De-duplication)

SDK logları/event'leri anlık atmak yerine biriktirip (batch/flush mekanizması ile - örn. 10 adet olunca) gönderdiği için ağ kopmalarında tekilleştirme daha da kritik hale gelir:

- Eğer SDK 10'lu batch paketi API'ye ilettiğinde, backend 10'unu da işleyip tam `200 OK` dönerken bağlantı koparsa, SDK o time-window'daki paketleri iletilmedi sanıp bir sonraki flush döngüsünde HTTP isteğini tekrarlayabilir (retry).
- Bu durumda aynı 10 event sisteme mükerrer girmiş olur. Event ingestion API'sinde, gelen her bir `eventId` için Redis'te kısa süreli (örn. 5-10 dk) bir TTL ile tekilleştirme (de-duplication) yapılmalıdır.
- Bu sayede flush paketleri mükerrer gelse dahi, o action/event karar motoru tarafından sadece ilk seferinde (bir kez) işlenir ve Trigger & Decision Engine'in kullanıcıya mükerrer mesaj (push veya in-app) atması önlenir.

---

## 10. Campaign API Contract

## 10.1 CRUD

- `POST /v2/campaigns`
- `GET /v2/campaigns`
- `GET /v2/campaigns/:id`
- `PUT /v2/campaigns/:id`
- `DELETE /v2/campaigns/:id` (soft delete önerilir)

## 10.2 Lifecycle

- `POST /v2/campaigns/:id/publish`
- `POST /v2/campaigns/:id/pause`
- `POST /v2/campaigns/:id/archive`
- `POST /v2/campaigns/:id/clone`

## 10.3 Validation & Dry Run

- `POST /v2/campaigns/:id/validate`
- `POST /v2/campaigns/:id/simulate`

`simulate` response:

```json
{
  "campaignId": "cmp_123",
  "estimatedAudience": 124532,
  "ruleDiagnostics": [
    {"rule": "country in [TR,US]", "passRate": 0.62},
    {"rule": "appVersion >= 2.0.0", "passRate": 0.81}
  ],
  "riskFlags": [
    "high_frequency",
    "large_inapp_payload"
  ]
}
```

---

## 11. Trigger DSL (Rule Engine Input)

## 11.1 Trigger JSON

```json
{
  "trigger": {
    "type": "event",
    "eventName": "add_to_cart",
    "window": {"lookbackMinutes": 15},
    "propertyFilters": [
      {"key": "category", "op": "eq", "value": "electronics"},
      {"key": "price", "op": "gte", "value": 100}
    ]
  }
}
```

## 11.2 Desteklenen operatorler

- `eq`, `neq`
- `gt`, `gte`, `lt`, `lte`
- `in`, `not_in`
- `exists`, `not_exists`
- `contains`, `starts_with`, `ends_with`

## 11.3 Değerlendirme kuralları

- Tüm filterlar `AND` default
- `orGroups` ile `OR` blokları opsiyonel
- Null handling explicit olmalı (`exists`)

---

## 12. Targeting Modeli

```json
{
  "targeting": {
    "userIds": [],
    "segmentIds": ["seg_high_value"],
    "country": ["TR", "DE"],
    "platform": ["android", "ios"],
    "deviceType": ["phone"],
    "appVersion": {"op": "gte", "value": "2.3.0"},
    "customUserProps": [
      {"key": "is_premium", "op": "eq", "value": true}
    ]
  }
}
```

Önemli: Segment çözümleme cache-first olmalı (Redis + TTL).

Ayrıca "Son 30 günde 5'ten fazla sipariş verenler" gibi kompleks segment kuralları anlık event akışında (on-the-fly) hesaplanmamalıdır. Bu tür ağır segmentler periyodik batch job'lar ile arka planda hesaplanıp Redis'e (ilgili kullanıcıların key'lerine) statik etiketler olarak yazılmalıdır. Böylece karar motoru gecikmesi (latency) her zaman hedeflenen <50ms altında tutulabilir.

---

## 13. Frequency + Suppression Modeli

```json
{
  "frequency": {
    "perDay": 3,
    "perSession": 1,
    "lifetime": 8,
    "cooldownMinutes": 120
  },
  "suppression": {
    "muteAfterPushMinutes": 10,
    "avoidChannels": ["inapp_if_push_sent_recently"]
  }
}
```

Önerilen saklama:

- Redis counter + periodic compact write to DB
- Key pattern:
  - `freq:{tenant}:{user}:{campaign}:day:{yyyyMMdd}`
  - `freq:{tenant}:{user}:{campaign}:session:{sessionId}`

---

## 14. Decision Algorithm (Pseudocode)

```text
onEvent(event):
  candidates = campaignIndex.lookup(event.tenant, event.triggerKey)
  for c in candidates:
    if c.status != live: continue
    if !scheduleWindowCheck(c, event.time): continue
    if !targetingCheck(c, event.user): continue
    if !triggerPropertyCheck(c, event.properties): continue
    if !frequencyCheck(c, event.user, event.session): continue
    if suppressionHit(c, event.user): continue

    decision = buildDecision(c, event.user)
    route(decision)  // push or inapp
    recordDecision(decision)
```

---

## 15. Delivery Tasarımı

## 15.1 Push delivery

Pipeline:

1. Decision -> PushOutbox
2. PushOutbox producer -> PushQueue topic
3. Dispatcher consumers -> Provider adapters
4. Ack/retry/DLQ

Başlıklar:

- At-least-once semantics
- Idempotency key (`campaignId:userId:runWindow`)
- Exponential backoff + jitter
- DLQ admin tooling

## 15.2 In-App delivery

Önerilen model: `hybrid pull`

- Event sonrası SDK kısa gecikmeyle fetch yapar
- App open / screen change / foreground geçişlerinde fetch
- Backend eligible in-app list döner

Endpoint:

`GET /v2/messages/inapp?userId=...&sessionId=...&platform=...`

Response:

```json
{
  "messages": [
    {
      "messageId": "msg_1",
      "campaignId": "cmp_456",
      "layoutType": "modal",
      "payload": {},
      "ttlSeconds": 600,
      "priority": 50
    }
  ],
  "traceId": "trc_..."
}
```

Önemli Limitasyon: Uzun süre uygulamaya girmeyen kullanıcılarda birikmiş kampanyaların RAM ve Network dar boğazlarına (spike) yol açmaması için `GET /v2/messages/inapp` yanıtında maksimum dönülecek bekleyen (pending) in-app mesaj sayısına katı bir sınır (örn. max 5 mesaj) konulmalıdır.

---

## 16. Provider Abstraction (Push)

Arayüz:

```ts
interface PushProvider {
  send(input: PushSendInput): Promise<PushSendResult>;
  validateToken(token: string): Promise<TokenValidationResult>;
}
```

Implementasyonlar:

- `FcmProvider`
- `ApnsProvider` (opsiyonel direct)
- `HmsProvider` (opsiyonel)

Not: Android GMS cihazlar için FCM fiilen zorunlu olabilir; bağımsızlık kampanya/karar katmanında hedeflenir.

---

## 17. Frontend (UsePublisher) Teknik Tasarım

## 17.1 UI modülleri

1. Campaign Builder
2. Trigger Editor
3. Targeting Editor
4. Frequency/Suppression Editor
5. Channel Content Editor (`push`/`inapp`)
6. Preview + Validation
7. Publish Workflow

## 17.2 Form state tasarımı

- Draft state local + autosave
- Server canonical draft ID
- Version conflict handling (`etag`/`updatedAt`)

## 17.3 Validation katmanları

- FE anlık validation (UX)
- BE validation (source of truth)
- Publish gate checks:
  - required fields
  - payload size
  - schedule validity
  - target size threshold warnings

## 17.4 FE API entegrasyon akışı

```text
create draft -> edit sections -> validate -> simulate -> publish
```

## 17.5 FE acceptance kriterleri

- Campaign edit sayfası 95p’de < 2s açılmalı
- Simulate sonucu 95p’de < 4s
- Publish sonrası status `live` görünürlüğü < 2s

---

## 18. Backend Servis Bölünmesi

Önerilen modül/servisler:

- `CampaignModule`
- `EventIngestionModule`
- `DecisionEngineModule`
- `PushDeliveryModule`
- `InAppDeliveryModule`
- `TelemetryModule`
- `AdminOpsModule`

Opsiyonel process ayrımı:

- API process
- Evaluation workers
- Push dispatch workers
- Telemetry ingestion workers

---

## 19. Queue/Topic Tasarımı

Önerilen topicler:

- `messaging.events.raw`
- `messaging.events.normalized`
- `messaging.decisions`
- `messaging.push.dispatch`
- `messaging.push.status`
- `messaging.telemetry`

Message envelope standardı:

```json
{
  "eventType": "decision.created",
  "eventVersion": 1,
  "traceId": "trc_...",
  "tenant": {"teamId":"...","projectId":"...","sourceId":"..."},
  "occurredAt": "2026-03-13T10:00:00Z",
  "payload": {}
}
```

## 19.1 Partitioning Stratejisi (Ordering Garantisi)

Kullanıcının yaptığı işlemlerin sırası (event order) decision engine için çok önemlidir (Örn: Önce sepete ekledi, sonra satın aldı). Bu sıralamanın bozulmaması ve olası "Race Condition" hatalarını önlemek adına:

- `messaging.events.raw` ve türevi topic'lere mesaj gönderilirken Kafka Partition Key olarak istisnasız `tenantId + userId` (veya doğrudan `userId`) kullanılmalıdır.
- Böylece bir kullanıcının tüm event'leri her zaman aynı Kafka partition'ına düşer ve aynı consumer/worker tarafından zaman damgası (timestamp) sırasına göre işlenir.

---

## 20. Caching Stratejisi

Cache katmanları:

1. Active campaign index cache
2. Segment membership cache
3. Frequency counter cache
4. In-app pending message cache

TTL önerileri:

- Campaign index: 30-120 sn
- Segment membership: 5-20 dk (segment tipine göre)
- In-app pending: 1-10 dk

Invalidation:

- publish/pause/archive sonrası event-driven invalidation

## 20.1 Redis Fallback (Hata Toleransı)

Sistemdeki `Segment Cache`, `Frequency Store` ve `Campaign Index` gibi kritik noktalar Redis mimarisi üzerine kurgulanmıştır. Olası bir Redis erişim kesintisinde (SPOF riski):

- Karar motorunun (Decision Engine) kilitlenmesini önlemek için, okunabilir verilerde DB tabanlı "safe mode" (salt okunur) fallback mekanizmasına geçilebilmeli,
- O anki event'lerin kaybolmaması adına geçici olarak Kafka üzerinde bir DLQ / Retry topic'ine yazılıp (backpressure), Redis ayağa kalktığında oradan işleme devam edilmelidir.

---

## 21. Observability ve SLO

## 21.1 Golden signals

- Throughput: events/sec, decisions/sec, sends/sec
- Latency: ingest p95, decision p95, inapp fetch p95, push send p95
- Error rate: 4xx/5xx, send failures, DLQ growth
- Saturation: queue lag, worker CPU/memory

## 21.2 SLO örnekleri

- Event ingest availability: `%99.9`
- Decision latency p95: `< 50ms`
- In-app fetch latency p95: `< 120ms`
- Push dispatch success rate: `> 98.5%` (provider errors hariç raporlanmalı)

## 21.3 Dashboard panelleri

- Tenant bazlı başarı/fail oranları
- Campaign bazlı conversion funnel
- DLQ heatmap
- Trigger rule pass/fail dağılımı

---

## 22. Güvenlik ve Uyumluluk

## 22.1 Kimlik doğrulama

- API: JWT + tenant claims zorunlu
- Internal service: mTLS veya signed service token

## 22.2 Yetkilendirme

- RBAC:
  - `campaign.read`
  - `campaign.write`
  - `campaign.publish`
  - `ops.dlq.manage`

## 22.3 Veri güvenliği

- Token masking logs
- PII minimization
- Data retention policy
- Secret rotation (service accounts dahil)

## 22.4 Threat model kısa listesi

- Replay attack (event ingest)
- Unauthorized publish
- Cross-tenant data leak
- Payload injection / XSS (in-app HTML benzeri içerikler)

---

## 23. Test Stratejisi

## 23.1 Backend

- Unit: rule evaluators, frequency checks, provider adapters
- Integration: API + DB + queue
- Contract: FE/SDK endpoint schema tests
- Load: event burst + queue lag tests
- Chaos: provider timeout/failure senaryoları

## 23.2 Frontend

- Unit: form validation, state reducer
- Integration: draft/save/validate/publish flow
- E2E: campaign create -> publish -> analytics verify

## 23.3 Mobile SDK

- In-app render snapshots
- Push action handling
- Offline/online transition
- Telemetry retry

---

## 24. Migration Plan (Detay)

## Phase A — Foundation

- New campaign schema eklenir
- Event ingestion v2 açılır
- Decision engine skeleton devreye alınır

## Phase B — Dual Run

- Legacy + new parallel karar üretimi (shadow mode)
- Sonuçlar karşılaştırılır (parity metrics)
- Feature flag ile tenant bazlı açılır

## Phase C — Controlled Rollout

- Önce In-App tenant subset
- Sonra Push non-critical campaignler
- Son olarak full traffic

## Phase D — Legacy Sunset

- Eski read path kapatılır
- Legacy fields deprecate edilir
- Operasyon runbook final hale getirilir

Rollback:

- Her fazda flag bazlı geri dönüş
- Data migration idempotent scriptler

---

## 25. FE/BE İş Paketleri (Ortak Plan)

## 25.1 Backend Work Items

1. Campaign v2 schema + migration
2. Event ingest v2 endpoint
3. Decision engine core
4. Frequency store (Redis + DB fallback)
5. Push delivery adapter refactor
6. In-app fetch endpoint + cache
7. Telemetry pipeline
8. Ops tooling + dashboards

## 25.2 Frontend Work Items

1. Unified campaign create/edit ekranı
2. Trigger/targeting DSL UI
3. Validation/simulation ekranı
4. Publish workflow + approvals
5. Campaign analytics görünümü

## 25.3 SDK Work Items

1. Event ingest v2 client
2. In-app fetch + render pipeline
3. Delivery telemetry API integration
4. Frequency-aware local suppression (opsiyonel)

---

## 26. AI Agent Collaboration Protocol

Bu bölüm AI ajanların güvenli ve tutarlı çalışması içindir.

## 26.1 Girdi paketi (AI'ye verilecek)

- Bu teknik doküman
- Kod baz path listesi
- Açık API sözleşmeleri
- Son sprint kararları
- Feature flag matrix

## 26.2 AI görev türleri

- Refactor önerisi
- API scaffolding
- Migration script review
- Test case üretimi
- Regression risk analizi

## 26.3 AI çıktı formatı standardı

- Değişiklik özeti
- Etkilenen dosyalar
- Olası riskler
- Geri dönüş planı
- Doğrulama adımları

## 26.4 Guardrails

- Cross-tenant data riskini özel kontrol et
- Security-sensitive dosyalarda insan onayı olmadan merge önerme
- Destructive git komutları yasak

---

## 27. Release Checklist

- [ ] API schema freeze
- [ ] FE publish flow QA
- [ ] SDK compatibility matrix tamam
- [ ] SLO dashboard canlı
- [ ] On-call runbook güncel
- [ ] Rollback flags test edildi
- [ ] Security review tamamlandı

---

## 28. Operasyon Runbook (Özet)

Incident türleri:

1. Queue lag yükseldi
2. Push provider hata oranı arttı
3. In-app fetch latency yükseldi
4. Cross-tenant auth hatası

Temel müdahale:

- Feature flag ile yeni decision path’i düşür
- Worker autoscale arttır
- Sorunlu provider route’unu fallback’e al
- DLQ replay’i kontrollü çalıştır

---

## 29. Açık Sorular

1. Segment source of truth nerede olacak? (DataStudio/internal hybrid)
2. Push transport katmanında provider stratejisi tenant bazlı mı global mi?
3. Approval workflow zorunlu mu? Hangi tenantlarda?
4. Campaign lifecycle audit retention süresi ne olmalı?
5. In-app template governance merkezi mi tenant bazlı mı?

---

## 30. Ekler

## 30.1 Örnek campaign create request

```json
{
  "name": "Checkout Exit Promo",
  "channel": "inapp",
  "status": "draft",
  "priority": 80,
  "trigger": {
    "type": "event",
    "eventName": "screen_view",
    "propertyFilters": [
      {"key": "screen", "op": "eq", "value": "checkout"}
    ]
  },
  "targeting": {
    "country": ["TR"],
    "platform": ["android", "ios"]
  },
  "frequency": {
    "perDay": 1,
    "perSession": 1,
    "cooldownMinutes": 180
  },
  "content": {
    "layoutType": "modal",
    "payload": {
      "title": {"tr": "%10 indirim fırsatı"},
      "body": {"tr": "Satın alımı şimdi tamamla"}
    }
  }
}
```

## 30.2 Örnek telemetry event

```json
{
  "eventType": "message.impression",
  "tenant": {"teamId":"...","projectId":"...","sourceId":"..."},
  "user": {"userId":"u_123","sessionId":"s_456"},
  "message": {"campaignId":"cmp_456","messageId":"msg_1","channel":"inapp"},
  "occurredAt": "2026-03-13T10:30:00Z"
}
```

---

## 31. Enterprise Hizmet Stratejisi (Büyük Müşteri Odaklı)

Bu bölüm, platformun kurumsal müşterilere nasıl ürünleştirileceğini ve hangi teknik/operasyonel modelle sunulacağını tanımlar.

## 31.1 Control Plane vs Delivery Plane

Önerilen model:

- **Control Plane (tamamen sizde)**:
  - Campaign yönetimi
  - Trigger/targeting/frequency kararları
  - Segment çözümleme
  - Telemetry ve analytics
  - Approval, audit, rollout

- **Delivery Plane (platform gateway)**:
  - iOS remote push için APNs
  - Android GMS için FCM (ve gerekirse OEM providerlar)

Bu ayrım sayesinde ürün zekası tamamen sizin platformda kalır, ancak OS düzeyi push teslim güvenilirliği korunur.

## 31.2 Multi-Tenant Servisleme Modeli

Kurumsal müşteriler için önerilen tenancy yaklaşımı:

1. `Pooled` (standart müşteriler)
2. `Bridge` (kurumsal müşteriler için tercih edilen varsayılan)
3. `Silo` (regülasyon veya özel sözleşme gerektiren müşteriler)

`Bridge` modelinde:

- Control plane shared olabilir
- Event/telemetry storage tenant-segmented tutulur
- Hassas tenantlar için worker ve cache namespace izolasyonu artırılır

## 31.3 Kurumsal Paketleme (Commercial + Technical)

Önerilen hizmet paketleri:

1. `Enterprise Base`
   - Multi-tenant isolate policy
   - Standard SLA
   - Audit logs
2. `Enterprise Plus`
   - Daha sıkı RTO/RPO hedefleri
   - Dedicated support window
   - Advanced approval workflows
3. `Enterprise Regulated`
   - Region pinning / data residency
   - Gelişmiş denetim raporları
   - Daha katı anahtar/erişim politikaları

## 31.4 Sözleşmesel ve Uyumluluk Çıktıları

Büyük müşteriye satış öncesi hazır olması gereken paket:

- DPA (Data Processing Addendum)
- SCC (uluslararası veri transferi gerekiyorsa)
- Security whitepaper
- Penetration test summary
- Incident response policy
- Data retention/deletion policy
- Access control & audit model açıklaması

## 31.5 90 Günlük Kurulum Planı (İlk Büyük Müşteriler)

### Gün 0-30

- Event ingestion v2 production-ready
- Campaign v2 schema + API
- Tenant claim doğrulama ve audit trail
- Temel SLO dashboardları

### Gün 31-60

- Trigger/decision engine hardening
- Frequency/suppression servisleri
- In-App hybrid delivery canlıya hazırlık
- Simulation/validation endpointlerinin devreye alınması

### Gün 61-90

- Push provider abstraction finalize
- DLQ ve replay operasyonu
- Pilot enterprise tenant rollout
- Playbook ve on-call süreçlerinin tamamlanması

## 31.6 Maliyet Modeli ve Unit Economics

Maliyet analizinde iki ayrı eksen izlenmelidir:

1. `Control Plane` maliyeti
   - Event ingestion
   - Rule evaluation
   - Cache + query + analytics
2. `Delivery Plane` maliyeti
   - Push gateway bağlantıları
   - Retry/DLQ operasyonu
   - Provider yanıt/başarısızlık işleme

Önerilen KPI seti:

- Cost per 1M ingested events
- Cost per 1M decisions
- Cost per 1M push attempts
- Cost per 1M in-app fetch
- Error-adjusted cost (DLQ etkisi dahil)

Bu KPI seti tenant bazlı tutulmalı ve kurumsal fiyatlamaya girdi olmalıdır.

## 31.7 Firebase Bağımlılığı Karar Matrisi

Karar matrisi:

1. In-App orchestration: Firebase gereksiz, tamamen internal olabilir
2. Android GMS push transport: FCM pratikte gerekli
3. iOS push transport: APNs gerekli

Sonuç:

- Firebase’i “ürün zekası katmanı”ndan çıkarabilirsiniz
- Android push teslim katmanında FCM adapter kalabilir

## 31.8 Enterprise Onboarding Go/No-Go Checklist

Müşteri canlı geçişinden önce:

- [ ] Tenant izolasyon testleri geçti
- [ ] Publish/approval/audit log doğrulandı
- [ ] Decision latency SLO sağlandı
- [ ] Push başarısızlık + retry + DLQ akışı doğrulandı
- [ ] Incident runbook tatbikatı yapıldı
- [ ] Güvenlik paket dokümanları müşteriyle paylaşıldı

---

## 32. Sonuç

Bu spesifikasyon ile ekipler:

- Push + In-App’i tek ürün dili ve tek teknik modelde yönetebilir,
- migration riskini fazlı ilerleyerek düşürebilir,
- performans/güvenlik/operasyon beklentilerini baştan ölçülebilir hale getirebilir,
- AI destekli geliştirmeyi kontrollü ve denetlenebilir biçimde ölçekleyebilir.
