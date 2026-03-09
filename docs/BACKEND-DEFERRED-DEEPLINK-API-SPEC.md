# BACKEND API SPECIFICATION: DEFERRED DEEPLINK
# Paylisher SDK - Install Attribution System

---

## GENEL BAKIS

Bu dokuman, Paylisher iOS ve Android SDK'larinin deferred deeplink (install attribution)
ozelligi icin backend API gereksinimlerini tanimlar.

**Deferred Deeplink Nedir?**
Kullanicinin uygulama yuklu degilken bir deeplink'e tiklamasi, App Store'dan yuklemesi
ve ilk acilista otomatik olarak tikladigii sayfaya yonlendirilmesi sistemidir.

**Backend'in Rolu:**
1. Link tiklandiginda cihaz fingerprint + URL kaydetmek
2. Uygulama ilk acildiginda fingerprint ile match kontrolu yapmak
3. Match varsa deeplink URL'ini donmek

---

## SISTEM MIMARISI

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLICK PHASE (Link Tiklanir)                  │
└─────────────────────────────────────────────────────────────────┘
                           │
        Kullanici Link'e Tiklar (Email, Social Media, Ad)
        Link: https://link.yourapp.com/promo?campaign=summer_sale
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │   Link Server (Redirect Service)        │
        │   - User-Agent'tan cihaz bilgisi al     │
        │   - Device fingerprint olustur          │
        │   - IP, Screen size, Timezone, vs.      │
        └──────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │   BACKEND API CALL #1                    │
        │   POST /deferred-deeplink/click          │
        │   Body: {                                │
        │     fingerprint: "sha256_hash",          │
        │     deeplink_url: "yourapp://promo",     │
        │     campaign_key: "SUMMER_SALE",         │
        │     click_timestamp: "2025-01-08...",    │
        │     user_agent: "Mozilla/5.0...",        │
        │     ip_address: "192.168.1.1"            │
        │   }                                      │
        └──────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │   Database'e Kaydet                      │
        │   Table: deferred_deeplink_clicks        │
        │   - fingerprint (indexed)                │
        │   - deeplink_url                         │
        │   - campaign_key                         │
        │   - jid (journey_id)                     │
        │   - click_timestamp                      │
        │   - expires_at (click + 24h)             │
        │   - matched (false)                      │
        └──────────────────────────────────────────┘
                           │
                           ▼
        Kullanici App Store'a Yonlendirilir
        Uygulama Yukler

┌─────────────────────────────────────────────────────────────────┐
│               INSTALL PHASE (Ilk Acilis)                        │
└─────────────────────────────────────────────────────────────────┘
                           │
        Uygulama Ilk Kez Acilir
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │   SDK (iOS/Android)                      │
        │   - Ilk acilis tespit edildi            │
        │   - Device fingerprint olustur           │
        │   - IDFV/IDFA (iOS)                      │
        │   - Android ID/GAID (Android)            │
        │   - Device model, OS, Screen, etc.       │
        │   - SHA-256 hash                         │
        └──────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │   BACKEND API CALL #2                    │
        │   GET /deferred-deeplink?fingerprint=... │
        │   Headers:                               │
        │     Authorization: Bearer API_KEY        │
        │     X-SDK-Version: paylisher-ios/1.6.0   │
        └──────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │   Backend: Match Kontrolu                │
        │   1. Fingerprint ile kayit ara           │
        │   2. Expire check (24h gecmemis mi?)     │
        │   3. Daha once match olmamis mi?         │
        │   4. Match varsa:                        │
        │      - matched = true flag'le            │
        │      - Response don                      │
        └──────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────────┐
        │   Response (Match Found)                 │
        │   {                                      │
        │     status: "match",                     │
        │     url: "yourapp://promo",              │
        │     campaign_key: "SUMMER_SALE",         │
        │     jid: "journey_abc123",               │
        │     click_timestamp: "2025-01-08...",    │
        │     attribution_window: 86400            │
        │   }                                      │
        └──────────────────────────────────────────┘
                           │
                           ▼
        SDK: Kullaniciyi Otomatik Promo Sayfasina Yonlendirir
```

---

## API ENDPOINT #1: CLICK TRACKING

### **Endpoint:**
```
POST /api/v1/deferred-deeplink/click
```

### **Purpose:**
Kullanici bir deeplink'e tikladiginda bu endpoint cagirilir. Backend cihaz
fingerprint'i ve deeplink bilgilerini kaydeder.

### **Request:**

**Headers:**
```
Content-Type: application/json
Authorization: Bearer {API_KEY}  (Opsiyonel - public link ise gerekmez)
X-Request-ID: {unique_request_id}
```

**Body:**
```json
{
  "fingerprint": "a1b2c3d4e5f6...sha256_hash",
  "deeplink_url": "yourapp://promo?campaign=summer_sale",
  "campaign_key": "SUMMER_SALE_2025",
  "jid": "journey_abc123",
  "click_timestamp": "2025-01-08T14:30:00.000Z",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)...",
  "ip_address": "203.0.113.42",
  "referer": "https://instagram.com/...",
  "attribution_window_seconds": 86400,
  "metadata": {
    "utm_source": "instagram",
    "utm_medium": "social",
    "utm_campaign": "summer_sale",
    "custom_param1": "value1"
  }
}
```

**Field Descriptions:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fingerprint` | String | Yes | SHA-256 hash of device info (64 chars) |
| `deeplink_url` | String | Yes | Full deeplink URL (max 2048 chars) |
| `campaign_key` | String | No | Campaign identifier |
| `jid` | String | No | Journey ID for attribution tracking |
| `click_timestamp` | String | Yes | ISO 8601 timestamp (UTC) |
| `user_agent` | String | Yes | Browser/device user agent |
| `ip_address` | String | Yes | IPv4 or IPv6 address |
| `referer` | String | No | Source URL (where click came from) |
| `attribution_window_seconds` | Integer | No | Window in seconds (default: 86400) |
| `metadata` | Object | No | Additional key-value pairs |

### **Response:**

**Success (201 Created):**
```json
{
  "status": "success",
  "click_id": "clk_1a2b3c4d5e6f",
  "fingerprint": "a1b2c3d4e5f6...",
  "expires_at": "2025-01-09T14:30:00.000Z",
  "message": "Deferred deeplink click recorded"
}
```

**Error (400 Bad Request):**
```json
{
  "status": "error",
  "error_code": "INVALID_FINGERPRINT",
  "message": "Fingerprint must be 64 character SHA-256 hash",
  "field": "fingerprint"
}
```

**Error Codes:**
- `INVALID_FINGERPRINT` - Fingerprint format hatali
- `INVALID_URL` - Deeplink URL gecersiz
- `MISSING_REQUIRED_FIELD` - Zorunlu alan eksik
- `EXPIRED_ATTRIBUTION_WINDOW` - Attribution window cok buyuk

### **Database Schema:**

**Table: `deferred_deeplink_clicks`**

```sql
CREATE TABLE deferred_deeplink_clicks (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    click_id VARCHAR(32) UNIQUE NOT NULL,
    fingerprint VARCHAR(64) NOT NULL,
    deeplink_url VARCHAR(2048) NOT NULL,
    campaign_key VARCHAR(255),
    jid VARCHAR(255),
    click_timestamp TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    attribution_window_seconds INT DEFAULT 86400,
    user_agent TEXT,
    ip_address VARCHAR(45),
    referer VARCHAR(2048),
    metadata JSON,
    matched BOOLEAN DEFAULT FALSE,
    matched_at TIMESTAMP NULL,
    install_fingerprint VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_fingerprint (fingerprint),
    INDEX idx_expires_at (expires_at),
    INDEX idx_matched (matched),
    INDEX idx_click_timestamp (click_timestamp)
);
```

**TTL Strategy:**
```sql
-- Expire edilen kayitlari temizle (cronjob - her gece)
DELETE FROM deferred_deeplink_clicks
WHERE expires_at < NOW() - INTERVAL 7 DAY;
```

---

## API ENDPOINT #2: MATCH CHECK

### **Endpoint:**
```
GET /api/v1/deferred-deeplink?fingerprint={fingerprint}
```

### **Purpose:**
SDK ilk acilista bu endpoint'i cagirir. Backend fingerprint'e gore match kontrolu yapar.

### **Request:**

**Headers:**
```
Authorization: Bearer {API_KEY}
X-SDK-Version: paylisher-ios/1.6.0  (veya paylisher-android/1.5.0)
X-Device-Platform: iOS  (veya Android)
```

**Query Parameters:**
```
fingerprint=a1b2c3d4e5f6...sha256_hash  (Required)
```

**Example:**
```
GET /api/v1/deferred-deeplink?fingerprint=a1b2c3d4e5f6789abc...
```

### **Response:**

**Success - Match Found (200 OK):**
```json
{
  "status": "match",
  "url": "yourapp://promo?campaign=summer_sale",
  "campaignKey": "SUMMER_SALE_2025",
  "jid": "journey_abc123",
  "clickTimestamp": "2025-01-08T14:30:00.000Z",
  "attributionWindow": 86400,
  "metadata": {
    "utm_source": "instagram",
    "utm_medium": "social",
    "discount_percentage": 50,
    "campaign_type": "seasonal"
  }
}
```

**Success - No Match (200 OK):**
```json
{
  "status": "no_match",
  "message": "No deferred deeplink found for this device"
}
```

**Field Descriptions (Match Response):**

| Field | Type | Description |
|-------|------|-------------|
| `status` | String | "match" or "no_match" |
| `url` | String | Original deeplink URL |
| `campaignKey` | String | Campaign identifier (nullable) |
| `jid` | String | Journey ID (nullable) |
| `clickTimestamp` | String | ISO 8601 timestamp when clicked |
| `attributionWindow` | Integer | Window in seconds |
| `metadata` | Object | Additional campaign data (nullable) |

**Error Responses:**

**401 Unauthorized:**
```json
{
  "status": "error",
  "error_code": "INVALID_API_KEY",
  "message": "API key is invalid or missing"
}
```

**400 Bad Request:**
```json
{
  "status": "error",
  "error_code": "INVALID_FINGERPRINT",
  "message": "Fingerprint parameter is required and must be 64 chars"
}
```

**500 Internal Server Error:**
```json
{
  "status": "error",
  "error_code": "INTERNAL_ERROR",
  "message": "An unexpected error occurred"
}
```

### **Backend Logic (Match Kontrolu):**

```python
# Pseudocode

def check_deferred_deeplink(fingerprint, api_key):
    # 1. API key dogrula
    if not validate_api_key(api_key):
        return 401, {"status": "error", "error_code": "INVALID_API_KEY"}

    # 2. Fingerprint validate
    if not is_valid_fingerprint(fingerprint):
        return 400, {"status": "error", "error_code": "INVALID_FINGERPRINT"}

    # 3. Database'de ara (exact match + fuzzy match)
    click = db.query("""
        SELECT * FROM deferred_deeplink_clicks
        WHERE fingerprint = :fingerprint
        AND matched = FALSE
        AND expires_at > NOW()
        ORDER BY click_timestamp DESC
        LIMIT 1
    """, fingerprint=fingerprint)

    # 4. Match yoksa fuzzy match dene (opsiyonel)
    if not click:
        click = fuzzy_match_fingerprint(fingerprint)

    # 5. Match bulunamadi
    if not click:
        return 200, {"status": "no_match"}

    # 6. Match bulundu - flag'le
    db.execute("""
        UPDATE deferred_deeplink_clicks
        SET matched = TRUE,
            matched_at = NOW(),
            install_fingerprint = :fingerprint
        WHERE id = :click_id
    """, fingerprint=fingerprint, click_id=click.id)

    # 7. Response don
    return 200, {
        "status": "match",
        "url": click.deeplink_url,
        "campaignKey": click.campaign_key,
        "jid": click.jid,
        "clickTimestamp": click.click_timestamp.isoformat(),
        "attributionWindow": click.attribution_window_seconds,
        "metadata": click.metadata
    }
```

### **Fuzzy Matching (Opsiyonel):**

Exact match bulunamazsa similarlik skoruna gore match deneyebilirsiniz:

```python
def fuzzy_match_fingerprint(target_fingerprint):
    # Son 24 saatteki tum click'leri al
    recent_clicks = db.query("""
        SELECT * FROM deferred_deeplink_clicks
        WHERE matched = FALSE
        AND expires_at > NOW()
        AND click_timestamp > NOW() - INTERVAL 24 HOUR
    """)

    best_match = None
    best_score = 0.0

    for click in recent_clicks:
        # Hamming distance veya Levenshtein distance
        score = calculate_similarity(target_fingerprint, click.fingerprint)

        if score > 0.85 and score > best_score:  # %85+ similarity
            best_match = click
            best_score = score

    return best_match
```

---

## FINGERPRINT OLSUTURMA

### **Android Fingerprint:**

**Components:**
```
- Android ID (SSAID)
- Advertising ID (GAID) - opsiyonel
- Device manufacturer (Samsung, Google, etc.)
- Device model (SM-G998B, Pixel 6, etc.)
- OS version (Android 13, API 33)
- Screen resolution (1080x2400)
- Screen density (420dpi)
- Timezone (Europe/Istanbul)
- Locale (tr_TR)
```

**Format:**
```
Samsung|SM-G998B|33|13|1080x2400|420|Europe/Istanbul|tr_TR|android_id_value|gaid_value
↓ SHA-256
a1b2c3d4e5f6789abcdef123456789abcdef123456789abcdef123456789abcd
```

### **iOS Fingerprint:**

**Components:**
```
- IDFV (Identifier for Vendor)
- IDFA (Identifier for Advertisers) - opsiyonel, ATT izni gerekir
- Device model (iPhone14,2)
- Device name (iPhone)
- OS version (17.2.1)
- Screen resolution (390x844 points)
- Screen scale (3.0x)
- Timezone (Europe/Istanbul)
- Locale (tr_TR)
```

**Format:**
```
12345678-ABCD-1234-EFGH-123456789ABC|iPhone14,2|iPhone|17.2.1|390x844|3.0|Europe/Istanbul|tr_TR|idfa_value
↓ SHA-256
xyz123abc456def789ghi012jkl345mno678pqr901stu234vwx567yza890bcd123
```

### **Web Click Fingerprint (Link Tiklama):**

Web'den tiklandiginda tam fingerprint olusturulamaz, yaklasik bilgi:

```javascript
// JavaScript (Link server tarafinda)
const fingerprint = {
    user_agent: navigator.userAgent,
    screen_width: screen.width,
    screen_height: screen.height,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    language: navigator.language,
    platform: navigator.platform,
    pixel_ratio: window.devicePixelRatio
};

// Combine
const combined = Object.values(fingerprint).join('|');
const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(combined));
```

**Matching Strategy:**

Exact match her zaman mumkun olmadigindan:
1. **Exact match** dene (fingerprint ayni)
2. **Fuzzy match** dene (benzerlik %85+)
3. **Time-based match** dene (ayni dakika icinde click + install)
4. **IP-based match** dene (ayni IP'den)

---

## ATTRIBUTION WINDOW

### **Definition:**

Attribution window, kullanicinin link'e tiklayip uygulamayi yukleyebilecegi maksimum suredir.

**Ornekler:**
- **1 saat:** Test icin
- **24 saat:** Standart (onerilir)
- **7 gun:** Uzun kampanyalar icin (email, retargeting)

### **Implementation:**

**Database:**
```sql
-- Click kaydedilirken expire hesapla
INSERT INTO deferred_deeplink_clicks (
    fingerprint,
    deeplink_url,
    click_timestamp,
    expires_at,
    attribution_window_seconds
) VALUES (
    'abc123...',
    'yourapp://promo',
    NOW(),
    NOW() + INTERVAL 24 HOUR,  -- Attribution window
    86400
);
```

**Match Check:**
```sql
-- Sadece expire olmamis kayitlar
SELECT * FROM deferred_deeplink_clicks
WHERE fingerprint = :fingerprint
AND matched = FALSE
AND expires_at > NOW()  -- Kritik!
ORDER BY click_timestamp DESC
LIMIT 1;
```

---

## RATE LIMITING

### **Click Endpoint:**

```
Rate Limit: 1000 requests/hour per IP
```

**Response Header:**
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1673183400
```

**429 Too Many Requests:**
```json
{
  "status": "error",
  "error_code": "RATE_LIMIT_EXCEEDED",
  "message": "Rate limit exceeded. Try again in 3600 seconds",
  "retry_after": 3600
}
```

### **Match Check Endpoint:**

```
Rate Limit: 100 requests/hour per API key
```

---

## SECURITY

### **1. API Key Authentication:**

```
Authorization: Bearer pk_live_abc123xyz789...
```

**Validation:**
- API key format: `pk_{env}_{random_32_chars}`
- Environment: `live`, `test`
- Check expiration, scope, permissions

### **2. Fingerprint Validation:**

```python
def is_valid_fingerprint(fingerprint):
    # Exactly 64 characters (SHA-256 hex)
    if len(fingerprint) != 64:
        return False

    # Hex characters only
    if not re.match(r'^[a-f0-9]{64}$', fingerprint):
        return False

    return True
```

### **3. URL Validation:**

```python
def is_valid_deeplink_url(url):
    # Max length
    if len(url) > 2048:
        return False

    # Valid scheme
    allowed_schemes = ['yourapp', 'https']
    parsed = urlparse(url)
    if parsed.scheme not in allowed_schemes:
        return False

    return True
```

### **4. DDoS Protection:**

- Rate limiting (per IP, per API key)
- CAPTCHA (high traffic)
- IP blacklist
- Anomaly detection

### **5. Data Privacy:**

- Fingerprint hash'leniyor (SHA-256)
- IP adresleri anonimize edilebilir
- GDPR compliance
- Data retention policy (7 gun sonra sil)

---

## MONITORING & ANALYTICS

### **Metrics:**

**Click Endpoint:**
- Total clicks per hour/day
- Clicks by campaign
- Clicks by source (Instagram, Email, etc.)
- Geographic distribution
- Device distribution (iOS vs Android)

**Match Endpoint:**
- Total match checks per hour/day
- Match rate (%matches / total checks)
- Average time-to-install
- Attribution window distribution
- Failed matches (reasons)

**Database:**
```sql
-- Analytics query ornekleri

-- Match rate
SELECT
    DATE(click_timestamp) as date,
    COUNT(*) as total_clicks,
    SUM(CASE WHEN matched THEN 1 ELSE 0 END) as matched_clicks,
    (SUM(CASE WHEN matched THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) as match_rate
FROM deferred_deeplink_clicks
WHERE click_timestamp > NOW() - INTERVAL 30 DAY
GROUP BY DATE(click_timestamp);

-- Ortalama time-to-install
SELECT
    AVG(TIMESTAMPDIFF(SECOND, click_timestamp, matched_at)) / 60 as avg_minutes
FROM deferred_deeplink_clicks
WHERE matched = TRUE;

-- En basarili kampanyalar
SELECT
    campaign_key,
    COUNT(*) as clicks,
    SUM(CASE WHEN matched THEN 1 ELSE 0 END) as installs,
    (SUM(CASE WHEN matched THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) as conversion_rate
FROM deferred_deeplink_clicks
WHERE click_timestamp > NOW() - INTERVAL 7 DAY
GROUP BY campaign_key
ORDER BY conversion_rate DESC;
```

---

## ERROR HANDLING

### **Click Endpoint Errors:**

| Code | Error | Handling |
|------|-------|----------|
| 400 | Invalid fingerprint | Return error, log |
| 400 | Invalid URL | Return error, log |
| 401 | Invalid API key | Return error |
| 429 | Rate limit | Return retry-after |
| 500 | Database error | Log, alert, return generic error |
| 503 | Service unavailable | Maintenance mode |

### **Match Endpoint Errors:**

| Code | Error | Handling |
|------|-------|----------|
| 400 | Missing fingerprint | Return error |
| 401 | Invalid API key | Return error |
| 404 | No match | Return "no_match" status (not error) |
| 429 | Rate limit | Return retry-after |
| 500 | Database error | Log, alert, return generic error |

---

## TESTING

### **Test Endpoint (Development Only):**

```
POST /api/v1/deferred-deeplink/test/click
```

**Purpose:** Test fingerprint + URL kaydetmek (production'da olmamali)

**Body:**
```json
{
  "fingerprint": "test_fingerprint_12345",
  "deeplink_url": "yourapp://test?campaign=test",
  "campaign_key": "TEST_CAMPAIGN"
}
```

### **Test Scenarios:**

**1. Exact Match:**
```bash
# Click kaydet
curl -X POST https://api.usepublisher.com/deferred-deeplink/click \
  -H "Content-Type: application/json" \
  -d '{
    "fingerprint": "abc123...",
    "deeplink_url": "yourapp://promo",
    "click_timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'

# Match check (ayni fingerprint)
curl -X GET "https://api.usepublisher.com/deferred-deeplink?fingerprint=abc123..." \
  -H "Authorization: Bearer API_KEY"

# Expected: {"status": "match", "url": "yourapp://promo", ...}
```

**2. No Match:**
```bash
curl -X GET "https://api.usepublisher.com/deferred-deeplink?fingerprint=notfound..." \
  -H "Authorization: Bearer API_KEY"

# Expected: {"status": "no_match"}
```

**3. Expired Attribution:**
```bash
# Click kaydet (24 saat once)
# Match check (simdi)
# Expected: {"status": "no_match"} (expired)
```

**4. Already Matched:**
```bash
# Click kaydet
# Match check (1. kez - basarili)
# Match check (2. kez - ayni fingerprint)
# Expected: {"status": "no_match"} (already matched)
```

---

## DEPLOYMENT CHECKLIST

### **Backend Requirements:**

- [ ] `/deferred-deeplink/click` endpoint implement edildi
- [ ] `/deferred-deeplink` (match check) endpoint implement edildi
- [ ] Database table olusturuldu
- [ ] Indexes eklendi (fingerprint, expires_at)
- [ ] TTL/cleanup cronjob kuruldu
- [ ] API key authentication yapildi
- [ ] Rate limiting eklendi
- [ ] Error handling implement edildi
- [ ] Monitoring/logging kuruldu
- [ ] Test endpoint'i eklendi (dev only)

### **Production Deployment:**

- [ ] Load testing yapildi
- [ ] Failover/redundancy hazir
- [ ] Backup stratejisi belirlendi
- [ ] Alert/notification kuruldu
- [ ] API documentation yazildi
- [ ] SDK ekipleri bilgilendirildi
- [ ] Test ortaminda test edildi
- [ ] Production'a deploy edildi
- [ ] Smoke test basarili

---

## APPENDIX: FULL API REFERENCE

### **Click Endpoint:**

```
POST /api/v1/deferred-deeplink/click

Headers:
  Content-Type: application/json
  Authorization: Bearer {API_KEY}

Body:
  {
    "fingerprint": string (64 chars, SHA-256),
    "deeplink_url": string (max 2048),
    "campaign_key": string (optional),
    "jid": string (optional),
    "click_timestamp": string (ISO 8601),
    "user_agent": string,
    "ip_address": string,
    "referer": string (optional),
    "attribution_window_seconds": integer (optional, default 86400),
    "metadata": object (optional)
  }

Response 201:
  {
    "status": "success",
    "click_id": string,
    "fingerprint": string,
    "expires_at": string (ISO 8601)
  }

Response 400/401/429/500: Error
```

### **Match Check Endpoint:**

```
GET /api/v1/deferred-deeplink?fingerprint={fingerprint}

Headers:
  Authorization: Bearer {API_KEY}
  X-SDK-Version: string
  X-Device-Platform: iOS | Android

Query Params:
  fingerprint: string (required, 64 chars)

Response 200 (Match):
  {
    "status": "match",
    "url": string,
    "campaignKey": string (nullable),
    "jid": string (nullable),
    "clickTimestamp": string (ISO 8601),
    "attributionWindow": integer,
    "metadata": object (nullable)
  }

Response 200 (No Match):
  {
    "status": "no_match"
  }

Response 400/401/429/500: Error
```

---

**Dokuman Versiyonu:** 1.0
**Son Guncelleme:** 08 Ocak 2025
**Hedef SDK:** iOS 1.6.0+, Android 1.5.0+
**Backend API Versiyonu:** v1
