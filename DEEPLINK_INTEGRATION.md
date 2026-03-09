# Paylisher SDK - Deeplink & Campaign Integration Guide

> **Complete guide for integrating Paylisher's powerful deeplink and campaign tracking features into your iOS app**

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Campaign Backend Architecture](#campaign-backend-architecture)
- [Integration Steps](#integration-steps)
- [URL Formats](#url-formats)
- [Event Tracking](#event-tracking)
- [Advanced Features](#advanced-features)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

Paylisher SDK provides **zero-configuration deeplink handling** with automatic campaign resolution and journey tracking. When a user opens a deeplink:

1. ✅ SDK extracts campaign information from URL
2. ✅ Fetches complete campaign data from backend
3. ✅ Tracks user journey automatically
4. ✅ Sends detailed analytics events
5. ✅ Handles authentication requirements
6. ✅ Navigates to destination

**You don't need to manually parse URLs or make backend calls - SDK handles everything!**

---

## ✨ Features

### Automatic Campaign Resolution
- Extract campaign key from any URL format
- Fetch campaign details from Paylisher backend
- Include full campaign data in analytics events

### Journey Tracking
- Automatic journey ID (jid) extraction
- Track user attribution across sessions
- Link all events to campaign source

### Smart URL Parsing
- Query parameters: `?keyName=XXX`, `?key=XXX`, `?k=XXX`
- Path-based: `/campaign/XXX`, `/c/XXX`
- Direct: `paylisher://XXX`

### Comprehensive Analytics
- `Deep Link Opened` - When deeplink received
- `deeplink_received` - Raw URL details
- `deeplink_resolved` - Campaign data loaded
- `deeplink_resolve_failed` - Resolution errors
- `deeplink_navigation` - Destination tracking

---

## 🚀 Quick Start

### 1. Basic Setup (AppDelegate)

```swift
import Paylisher

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 1️⃣ Initialize Paylisher SDK
        let config = PaylisherConfig(
            apiKey: "phc_YOUR_API_KEY",
            host: "https://analytics.paylisher.com"
        )
        PaylisherSDK.shared.setup(config)

        // 2️⃣ Configure deeplink auth requirements (optional)
        PaylisherSDK.shared.configureDeepLinks(authRequired: [
            "wallet",      // Requires login
            "transfer",    // Requires login
            "profile"      // Requires login
            // Other destinations don't require auth
        ])

        // 3️⃣ Enable debug logging (development only)
        PaylisherDeepLinkManager.shared.config.debugLogging = true

        // 4️⃣ Set deeplink handler
        PaylisherSDK.shared.setDeepLinkHandler(self)

        return true
    }

    // 5️⃣ Handle URL schemes (iOS 12 and below)
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return PaylisherSDK.shared.handleDeepLink(url)
    }

    // 6️⃣ Handle Universal Links
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return PaylisherSDK.shared.handleUserActivity(userActivity)
    }
}
```

### 2. Implement Deeplink Handler

```swift
extension AppDelegate: PaylisherDeepLinkHandler {

    /// Called when deeplink is received
    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        print("📱 Deeplink received: \(deepLink.destination)")

        // ✅ SDK already:
        // - Extracted campaign key
        // - Fetched campaign data from backend
        // - Set journey ID (jid)
        // - Sent "Deep Link Opened" event with full campaign data

        if let jid = deepLink.jid {
            print("✅ Campaign deeplink - jid: \(jid)")
        }

        if let campaignData = deepLink.campaignData {
            print("✅ Campaign: \(campaignData.title ?? "Unknown")")
            print("✅ Type: \(campaignData.type ?? "Unknown")")
        }

        if requiresAuth {
            print("⚠️ Auth required - show login screen")
            // After login succeeds, call:
            // PaylisherSDK.shared.completePendingDeepLink()
        } else {
            // Navigate directly
            navigateToDestination(deepLink.destination)
        }
    }

    /// Called when auth is required (optional)
    func paylisherDeepLinkRequiresAuth(_ deepLink: PaylisherDeepLink,
                                      completion: @escaping (Bool) -> Void) {
        print("🔐 Auth required for: \(deepLink.destination)")

        // Show login screen
        showLoginScreen { success in
            completion(success)
        }
    }

    /// Called on parsing failure (optional)
    func paylisherDeepLinkDidFail(_ url: URL, error: Error?) {
        print("❌ Deeplink failed: \(url)")
    }

    // Helper: Navigate to destination
    private func navigateToDestination(_ destination: String) {
        // Your navigation logic here
        print("🚀 Navigating to: \(destination)")
    }
}
```

### 3. SwiftUI Integration (Optional)

```swift
import SwiftUI
import Paylisher
import Combine

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var activeDestination: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(AppDelegate.deepLinkPublisher) { destination in
                    activeDestination = destination
                }
                .sheet(item: $activeDestination) { dest in
                    // Show destination view
                    DestinationView(destination: dest)
                }
        }
    }
}

// In AppDelegate
extension AppDelegate {
    static let deepLinkPublisher = PassthroughSubject<String, Never>()

    private func navigateToDestination(_ destination: String) {
        DispatchQueue.main.async {
            AppDelegate.deepLinkPublisher.send(destination)
        }
    }
}
```

---

## 🏗️ Campaign Backend Architecture

### How Campaign Resolution Works

```
┌─────────────────────────────────────────────────────────────┐
│                    DEEPLINK FLOW                            │
└─────────────────────────────────────────────────────────────┘

1. User Clicks Link
   └─> paylisher://campaign/X7kdi5Yq9lTVOv46uHYtV
       │
       ▼
2. iOS Opens App
   └─> application(_:open:options:) called
       │
       ▼
3. SDK Parses URL
   └─> Extracts: campaign key = "X7kdi5Yq9lTVOv46uHYtV"
   └─> Extracts: jid (if present)
   └─> Extracts: destination, params
       │
       ▼
4. SDK Resolves Campaign (Async)
   └─> GET https://api.usepublisher.com/campaign/X7kdi5Yq9lTVOv46uHYtV
       │
       ▼
5. Backend Returns Campaign Data
   └─> {
         "title": "Black Friday Sale",
         "type": "promotion",
         "webUrl": "https://shop.com/sale",
         "iosUrl": "myapp://products/sale",
         "jid": "journey_abc123",
         "metaData": {
           "discount": "50%",
           "expireAt": "2025-12-31T23:59:59Z"
         }
       }
       │
       ▼
6. SDK Tracks Events
   └─> Event: "deeplink_received" (immediate)
   └─> Event: "deeplink_resolved" (after backend response)
   └─> Event: "Deep Link Opened" (with full campaign data)
       │
       ▼
7. SDK Sets Journey Context
   └─> All future events include jid
   └─> Attribution maintained across session
       │
       ▼
8. App Navigates
   └─> Callback: paylisherDidReceiveDeepLink()
   └─> Your code: navigate to destination
```

### Backend API Endpoint

**Endpoint**: `GET https://api.usepublisher.com/campaign/{keyName}`

**Request Example**:
```http
GET /campaign/X7kdi5Yq9lTVOv46uHYtV HTTP/1.1
Host: api.usepublisher.com
```

**Response Example**:
```json
{
  "_id": { "$oid": "6762d8a1a2b3c4d5e6f7g8h9" },
  "teamId": "team_123",
  "projectId": "proj_456",
  "sourceId": "src_789",
  "type": "promotion",
  "title": "Black Friday Sale",
  "keyName": "X7kdi5Yq9lTVOv46uHYtV",
  "webUrl": "https://shop.com/sale",
  "iosUrl": "myapp://products/sale",
  "androidUrl": "myapp://products/sale",
  "fallbackUrl": "https://shop.com",
  "scheme": "myapp",
  "webhookUrl": "https://yourserver.com/webhook",
  "jid": "journey_abc123",
  "metaData": {
    "discount": "50%",
    "category": "electronics",
    "expireAt": { "$date": "2025-12-31T23:59:59.000Z" }
  },
  "createdAt": { "$date": "2025-12-01T00:00:00.000Z" },
  "updatedAt": { "$date": "2025-12-20T00:00:00.000Z" },
  "__v": 0
}
```

**Error Response**:
```json
{
  "error": "Campaign not found",
  "statusCode": 404
}
```

---

## 📝 Integration Steps

### Step 1: Add URL Scheme to Info.plist

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.yourapp</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

### Step 2: Configure Universal Links (Optional)

Add associated domain:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:yourapp.com</string>
</array>
```

Create `apple-app-site-association` file on your server:
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.yourcompany.yourapp",
        "paths": ["/campaign/*", "/c/*", "/*"]
      }
    ]
  }
}
```

### Step 3: Initialize SDK (see Quick Start above)

### Step 4: Test Your Integration

```swift
// Test in Xcode simulator
xcrun simctl openurl booted "yourapp://campaign/TEST_KEY_123"

// Test universal link
xcrun simctl openurl booted "https://yourapp.com/campaign/TEST_KEY_123"
```

---

## 🔗 URL Formats

### Supported Formats

| Format | Example | Description |
|--------|---------|-------------|
| **Path - Long** | `yourapp://campaign/X7kdi5Yq9` | Most explicit |
| **Path - Short** | `yourapp://c/X7kdi5Yq9` | Shorter URL |
| **Direct Key** | `yourapp://X7kdi5Yq9lTVOv46uHYtV` | Simplest (10+ chars) |
| **Query - Full** | `yourapp://products?keyName=X7kdi5Yq9` | With destination |
| **Query - Short** | `yourapp://products?key=X7kdi5Yq9` | Alternative param |
| **Query - Tiny** | `yourapp://products?k=X7kdi5Yq9` | Shortest param |
| **Universal Link** | `https://yourapp.com/campaign/X7kdi5Yq9` | Web + app link |

### URL Parameters

```
yourapp://products?keyName=ABC123&jid=journey_xyz&auth=required&source=email
         ^^^^^^^^  ^^^^^^^^ ^^^^^^ ^^^^^^^^^^^^^ ^^^^^^^^^^^^^^ ^^^^^^^^^^^^
           │          │        │         │              │            │
      Destination   Campaign Journey   Requires    Source/UTM
                      Key      ID       Login       Parameter
```

**Built-in Parameters**:
- `keyName` / `key` / `k`: Campaign key (auto-resolved)
- `jid`: Journey ID (auto-tracked)
- `auth`: Set to "required" to enforce login
- `source` / `utm_source`: Traffic source
- `campaign` / `utm_campaign`: Campaign identifier

**Custom Parameters**: Any other parameters are preserved in `deepLink.parameters`

---

## 📊 Event Tracking

### Automatic Events

SDK sends these events automatically:

#### 1. `deeplink_received` (Immediate)
Sent as soon as deeplink is received, before any processing.

```json
{
  "event": "deeplink_received",
  "properties": {
    "source": "url_scheme",
    "timestamp": "2025-12-25T22:00:00Z",
    "full_url": "yourapp://campaign/X7kdi5Yq9",
    "scheme": "yourapp",
    "host": "campaign",
    "path": "/X7kdi5Yq9",
    "path_components": ["campaign", "X7kdi5Yq9"],
    "query": "",
    "query_items": {},
    "campaign_key_detected": "X7kdi5Yq9",
    "has_campaign_key": true,
    "query_param_count": 0,
    "path_component_count": 2
  }
}
```

#### 2. `deeplink_resolved` (After Backend Response)
Sent when campaign data is successfully fetched from backend.

```json
{
  "event": "deeplink_resolved",
  "properties": {
    "source": "url_scheme",
    "timestamp": "2025-12-25T22:00:01Z",
    "opened_full_url": "yourapp://campaign/X7kdi5Yq9",
    "opened_scheme": "yourapp",
    "opened_host": "campaign",
    "opened_path": "/X7kdi5Yq9",

    // Campaign data from backend
    "_id": "6762d8a1...",
    "teamId": "team_123",
    "projectId": "proj_456",
    "type": "promotion",
    "title": "Black Friday Sale",
    "keyName": "X7kdi5Yq9",
    "webUrl": "https://shop.com/sale",
    "iosUrl": "yourapp://products/sale",
    "jid": "journey_abc123",

    // Campaign status
    "is_campaign_active": true,
    "days_until_expire": 7,

    // URL type flags
    "has_web_url": true,
    "has_ios_url": true,
    "has_android_url": true,
    "has_fallback_url": true,
    "has_custom_scheme": true,
    "has_webhook": false,
    "has_metadata": true,

    // Metadata (flattened)
    "metaData": {
      "discount": "50%",
      "category": "electronics"
    },
    "meta_discount": "50%",
    "meta_category": "electronics"
  }
}
```

#### 3. `Deep Link Opened` (Complete Event)
Main event with all data - sent after parsing and resolution.

```json
{
  "event": "Deep Link Opened",
  "properties": {
    "destination": "products",
    "scheme": "yourapp",
    "full_url": "yourapp://products?keyName=X7kdi5Yq9",
    "auth_required": false,

    // Journey tracking
    "jid": "journey_abc123",

    // Campaign data
    "campaign_key": "X7kdi5Yq9",
    "has_campaign_key": true,
    "campaign_resolved": true,
    "title": "Black Friday Sale",
    "type": "promotion",
    "teamId": "team_123",
    "projectId": "proj_456",
    // ... all campaign fields

    // URL parameters
    "parameters": {
      "keyName": "X7kdi5Yq9",
      "source": "email"
    }
  }
}
```

#### 4. `deeplink_resolve_failed` (On Error)
Sent if backend request fails.

```json
{
  "event": "deeplink_resolve_failed",
  "properties": {
    "source": "url_scheme",
    "timestamp": "2025-12-25T22:00:01Z",
    "full_url": "yourapp://campaign/INVALID_KEY",
    "campaign_key": "INVALID_KEY",
    "error_description": "HTTP error: 404",
    "error_type": "PaylisherCampaignAPIError"
  }
}
```

### Manual Tracking (Optional)

You can also use the tracker directly:

```swift
import Paylisher

// Track incoming deeplink (already done by SDK)
PaylisherDeepLinkTracker.shared.logIncoming(
    url: url,
    source: "push_notification"
)

// Track navigation
PaylisherDeepLinkTracker.shared.logNavigation(
    destination: "products",
    url: url,
    source: "deeplink"
)

// Track universal link
PaylisherDeepLinkTracker.shared.logUniversalLink(
    url: url,
    host: "yourapp.com",
    path: "/campaign/X7kdi5Yq9"
)
```

---

## 🎯 Advanced Features

### 1. Authentication Flow

```swift
extension AppDelegate: PaylisherDeepLinkHandler {

    func paylisherDeepLinkRequiresAuth(_ deepLink: PaylisherDeepLink,
                                      completion: @escaping (Bool) -> Void) {
        // Show login modal
        showLoginModal { user in
            if let user = user {
                // Login successful
                PaylisherSDK.shared.identify(user.id, userProperties: [
                    "email": user.email,
                    "name": user.name
                ])

                // Complete the deeplink navigation
                completion(true)
            } else {
                // Login failed/cancelled
                completion(false)
            }
        }
    }
}
```

Or complete manually later:
```swift
// After successful login anywhere in your app
PaylisherSDK.shared.completePendingDeepLink()
```

### 2. Custom Campaign Data Handling

```swift
func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
    guard let campaign = deepLink.campaignData else {
        // Not a campaign link
        navigateToDestination(deepLink.destination)
        return
    }

    // Campaign link - check type
    switch campaign.type {
    case "promotion":
        showPromotionBanner(campaign)
    case "onboarding":
        startOnboardingFlow(campaign)
    case "referral":
        handleReferral(campaign)
    default:
        navigateToDestination(deepLink.destination)
    }

    // Access metadata
    if let metadata = campaign.metaData,
       case .string(let discount) = metadata["discount"] {
        print("Discount: \(discount)")
    }
}
```

### 3. Webhook Integration

If your campaign includes a `webhookUrl`, SDK includes it in events:

```swift
func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
    if let webhookUrl = deepLink.campaignData?.webhookUrl {
        // Send custom webhook notification
        notifyWebhook(url: webhookUrl, userId: currentUser.id)
    }
}
```

### 4. Fallback URL Handling

```swift
func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
    // Try iOS URL first
    if let iosUrl = deepLink.campaignData?.iosUrl {
        navigate(to: iosUrl)
        return
    }

    // Fall back to web URL
    if let webUrl = deepLink.campaignData?.webUrl {
        UIApplication.shared.open(URL(string: webUrl)!)
        return
    }

    // Use fallback URL
    if let fallbackUrl = deepLink.campaignData?.fallbackUrl {
        UIApplication.shared.open(URL(string: fallbackUrl)!)
    }
}
```

### 5. Campaign Expiration Check

```swift
func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
    guard let campaign = deepLink.campaignData else { return }

    // Check if campaign is expired
    if let metadata = campaign.metaData,
       case .string(let expireAtStr) = metadata["expireAt"] {

        let formatter = ISO8601DateFormatter()
        if let expireDate = formatter.date(from: expireAtStr) {
            if expireDate < Date() {
                // Campaign expired
                showExpiredCampaignAlert()
                return
            }
        }
    }

    // Campaign is active
    navigateToDestination(deepLink.destination)
}
```

---

## 🧪 Testing

### Test Scenarios

#### 1. Test Campaign Deeplink
```swift
// In Xcode, run in terminal:
xcrun simctl openurl booted "yourapp://campaign/X7kdi5Yq9lTVOv46uHYtV"

// Expected results:
// ✅ App opens
// ✅ Console shows: "Resolving campaign: X7kdi5Yq9lTVOv46uHYtV"
// ✅ Console shows: "Campaign resolved successfully: Black Friday Sale"
// ✅ Console shows: "Journey ID set: journey_abc123"
// ✅ Event sent: "deeplink_received"
// ✅ Event sent: "deeplink_resolved"
// ✅ Event sent: "Deep Link Opened"
// ✅ Callback: paylisherDidReceiveDeepLink() called
```

#### 2. Test Invalid Campaign
```bash
xcrun simctl openurl booted "yourapp://campaign/INVALID_KEY_123"

# Expected:
# ✅ App opens
# ⚠️ Console shows: "Failed to resolve campaign: HTTP error: 404"
# ✅ Event sent: "deeplink_resolve_failed"
# ✅ Callback still called (without campaign data)
```

#### 3. Test Auth Required
```bash
xcrun simctl openurl booted "yourapp://wallet?keyName=X7kdi5Yq9&auth=required"

# Expected:
# ✅ App opens
# ✅ Console shows: "Auth required for: wallet"
# ✅ Callback: paylisherDeepLinkRequiresAuth() called
# ✅ Login screen shown
```

#### 4. Test Journey Tracking
```swift
// Open campaign link
xcrun simctl openurl booted "yourapp://campaign/X7kdi5Yq9"

// Then trigger any event
PaylisherSDK.shared.capture("product_viewed", properties: [
    "product_id": "123"
])

// Check event in dashboard - should include:
// ✅ "jid": "journey_abc123"
```

### Debug Logging

Enable debug mode to see detailed logs:

```swift
PaylisherDeepLinkManager.shared.config.debugLogging = true
```

Output example:
```
[PaylisherDeepLink] Handling URL: yourapp://campaign/X7kdi5Yq9
[PaylisherDeepLink] Deep link parsed - destination: campaign, requiresAuth: false, jid: none
[PaylisherDeepLink] Resolving campaign: X7kdi5Yq9
[PaylisherDeepLink] Campaign resolved successfully: Black Friday Sale
[PaylisherDeepLink] Journey ID updated from campaign: journey_abc123
[PaylisherDeepLink] Captured 'Deep Link Opened' event
```

### Unit Testing

```swift
import XCTest
@testable import Paylisher

class DeeplinkTests: XCTestCase {

    func testCampaignKeyExtraction() {
        let url1 = URL(string: "myapp://campaign/ABC123")!
        let url2 = URL(string: "myapp://products?keyName=ABC123")!
        let url3 = URL(string: "myapp://ABC1234567890")!

        // Test that all formats extract key correctly
        // (Implementation uses private method, this is conceptual)
    }

    func testCampaignResolution() async throws {
        let payload = try await PaylisherCampaignAPI.resolve(keyName: "TEST_KEY")
        XCTAssertNotNil(payload.title)
        XCTAssertNotNil(payload.jid)
    }
}
```

---

## 🔧 Troubleshooting

### Common Issues

#### Issue: Deeplink not opening app

**Solution**:
1. Check URL scheme in Info.plist
2. Verify scheme matches URL: `yourapp://` requires scheme `yourapp`
3. Test with Safari first: `yourapp://test`
4. Check console for errors

#### Issue: Campaign not resolving

**Solution**:
1. Check network connection
2. Verify campaign key exists in backend
3. Check API endpoint: `https://api.usepublisher.com/campaign/{key}`
4. Look for `deeplink_resolve_failed` event
5. Enable debug logging

#### Issue: Events not showing in dashboard

**Solution**:
1. Verify Paylisher SDK is initialized
2. Check API key is correct
3. Check `config.captureDeepLinkEvents = true` (default)
4. Flush events manually: `PaylisherSDK.shared.flush()`

#### Issue: Journey ID not persisting

**Solution**:
1. Check that `jid` is in URL or campaign data
2. Verify `PaylisherJourneyContext.shared.setJourneyId()` was called
3. Journey ID persists for 24 hours by default
4. Check events include `jid` property

#### Issue: Auth flow not working

**Solution**:
1. Verify destination is in `authRequiredDestinations` array
2. Implement `paylisherDeepLinkRequiresAuth()` callback
3. Call `completion(true)` after successful login
4. Or use `PaylisherSDK.shared.completePendingDeepLink()`

---

## 📚 API Reference

### PaylisherDeepLink

```swift
@objc public class PaylisherDeepLink: NSObject {
    let url: URL                          // Original URL
    let scheme: String                    // "yourapp" or "https"
    let destination: String               // "products", "wallet", etc.
    let parameters: [String: String]      // Query parameters
    let authParamRequired: Bool           // From ?auth=required
    let campaignId: String?               // From ?campaign=XXX
    let source: String?                   // From ?source=XXX
    let jid: String?                      // Journey ID
    let timestamp: Date                   // When received
    let rawQuery: String?                 // Raw query string
    let campaignKeyName: String?          // Extracted campaign key
    var campaignData: PaylisherResolvedDeepLinkPayload?  // Resolved data
}
```

### PaylisherResolvedDeepLinkPayload

```swift
public struct PaylisherResolvedDeepLinkPayload: Codable {
    let id: PaylisherMongoOID?
    let teamId: String?
    let projectId: String?
    let sourceId: String?
    let type: String?                     // "promotion", "onboarding", etc.
    let title: String?                    // Campaign title
    let keyName: String?                  // Campaign key
    let webUrl: String?                   // Web destination
    let iosUrl: String?                   // iOS app destination
    let androidUrl: String?               // Android app destination
    let fallbackUrl: String?              // Fallback URL
    let scheme: String?                   // Custom scheme
    let webhookUrl: String?               // Webhook endpoint
    let createdAt: PaylisherMongoDate?
    let updatedAt: PaylisherMongoDate?
    let jid: String?                      // Journey ID
    let metaData: [String: PaylisherJSONValue]?  // Custom metadata

    func toPropertiesDictionary() -> [String: Any]
}
```

### PaylisherCampaignAPI

```swift
public enum PaylisherCampaignAPI {
    static func resolve(keyName: String) async throws -> PaylisherResolvedDeepLinkPayload
}

public enum PaylisherCampaignAPIError: Error {
    case invalidURL
    case httpError(statusCode: Int)
    case decodingError(underlying: Error)
}
```

### PaylisherDeepLinkTracker

```swift
public final class PaylisherDeepLinkTracker {
    static let shared: PaylisherDeepLinkTracker

    func logIncoming(url: URL, source: String)
    func logResolved(url: URL, source: String, resolved: PaylisherResolvedDeepLinkPayload)
    func logResolutionFailed(url: URL, source: String, keyName: String, error: Error)
    func logNavigation(destination: String, url: URL, source: String)
    func logUniversalLink(url: URL, host: String, path: String)
}
```

---

## 🎓 Best Practices

### 1. Keep Campaign Keys Short
- Use short paths: `/c/ABC123` instead of `/campaign/ABC123`
- Makes URLs cleaner and easier to share

### 2. Use Metadata for Dynamic Content
```json
{
  "metaData": {
    "discount": "50%",
    "code": "SUMMER2025",
    "banner_url": "https://cdn.com/banner.jpg",
    "expireAt": "2025-12-31T23:59:59Z"
  }
}
```

### 3. Set Expiration Dates
- Always include `expireAt` in metadata
- Check expiration in app before showing campaign
- Prevents showing outdated promotions

### 4. Use Type Field for Routing
```swift
switch campaign.type {
case "flash_sale": showFlashSale(campaign)
case "tutorial": startTutorial(campaign)
case "update": showUpdatePrompt(campaign)
default: showGeneric(campaign)
}
```

### 5. Handle Errors Gracefully
```swift
func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
    if deepLink.campaignData == nil {
        // Campaign failed to load - still navigate
        print("⚠️ Campaign data unavailable, using basic navigation")
    }
    navigateToDestination(deepLink.destination)
}
```

### 6. Test Both Online and Offline
- Campaign resolution requires network
- App should handle offline gracefully
- Consider caching campaign data

---

## 📄 Example Campaigns

### Promotion Campaign
```json
{
  "type": "promotion",
  "title": "Summer Sale 50% Off",
  "keyName": "SUMMER2025",
  "iosUrl": "myapp://products/sale",
  "webUrl": "https://shop.com/summer-sale",
  "jid": "journey_summer_2025",
  "metaData": {
    "discount": "50%",
    "code": "SUMMER50",
    "category": "clothing",
    "expireAt": "2025-08-31T23:59:59Z"
  }
}
```

### Onboarding Campaign
```json
{
  "type": "onboarding",
  "title": "Welcome Tutorial",
  "keyName": "WELCOME_NEW",
  "iosUrl": "myapp://onboarding/step1",
  "jid": "journey_welcome",
  "metaData": {
    "steps": 5,
    "estimated_time": "2min"
  }
}
```

### Referral Campaign
```json
{
  "type": "referral",
  "title": "Friend Referral",
  "keyName": "REF_ABC123",
  "iosUrl": "myapp://signup",
  "jid": "journey_ref_abc123",
  "metaData": {
    "referrer_id": "user_456",
    "referrer_name": "John Doe",
    "bonus": "$10"
  }
}
```

---

## 🤝 Support

### Resources
- **Documentation**: [docs.paylisher.com](https://docs.paylisher.com)
- **Dashboard**: [analytics.paylisher.com](https://analytics.paylisher.com)
- **GitHub**: [github.com/paylisher/PAYLISHER-SDK-IOS](https://github.com/paylisher/PAYLISHER-SDK-IOS)

### Need Help?
- Create an issue on GitHub
- Contact: support@paylisher.com
- Check troubleshooting section above

---

**Last Updated**: December 25, 2025
**SDK Version**: 1.5.4+
**Minimum iOS**: 12.0
