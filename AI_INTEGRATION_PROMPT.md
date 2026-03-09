# Paylisher SDK Deeplink Integration - AI Assistant Prompt

> **Copy this entire prompt to Claude, ChatGPT, or any AI assistant to help integrate Paylisher deeplink features into an iOS app**

---

## Context

I need to integrate Paylisher SDK's deeplink and campaign tracking features into my iOS application. The Paylisher SDK provides automatic campaign resolution, journey tracking, and comprehensive analytics.

## What Paylisher SDK Does Automatically

When a user opens a deeplink:
1. ✅ Extracts campaign key from URL (supports multiple formats)
2. ✅ Makes backend API call to fetch campaign data
3. ✅ Extracts and sets journey ID (jid) for attribution
4. ✅ Sends detailed analytics events
5. ✅ Handles authentication requirements
6. ✅ Provides rich callback with all data

## Integration Requirements

### Backend API
- **Endpoint**: `GET https://api.usepublisher.com/campaign/{keyName}`
- **Returns**: Campaign data including title, type, URLs, metadata, journey ID
- **SDK handles**: Automatic async call, error handling, retry logic

### URL Formats Supported
The SDK automatically extracts campaign keys from these formats:
```
✅ yourapp://campaign/X7kdi5Yq9lTVOv46uHYtV
✅ yourapp://c/X7kdi5Yq9
✅ yourapp://X7kdi5Yq9lTVOv46uHYtV (10+ characters)
✅ yourapp://products?keyName=X7kdi5Yq9
✅ yourapp://products?key=X7kdi5Yq9
✅ yourapp://products?k=X7kdi5Yq9
✅ https://yourapp.com/campaign/X7kdi5Yq9
```

### Events Automatically Tracked
1. **`deeplink_received`** - Immediate, includes raw URL details
2. **`deeplink_resolved`** - After successful backend call, includes full campaign data
3. **`Deep Link Opened`** - Main event with complete information
4. **`deeplink_resolve_failed`** - If backend call fails

## Tasks for AI Assistant

Please help me with the following:

### 1. Basic Setup
- [ ] Add Paylisher SDK initialization in AppDelegate
- [ ] Configure URL scheme in Info.plist
- [ ] Set up deeplink handler callbacks
- [ ] Configure Universal Links (if needed)

### 2. Implement Deeplink Handler
- [ ] Create AppDelegate extension conforming to `PaylisherDeepLinkHandler`
- [ ] Implement `paylisherDidReceiveDeepLink()` - main callback
- [ ] Implement `paylisherDeepLinkRequiresAuth()` - auth flow (optional)
- [ ] Implement `paylisherDeepLinkDidFail()` - error handling (optional)

### 3. Navigation Logic
- [ ] Create navigation function based on `destination` parameter
- [ ] Handle campaign data (title, type, metadata, URLs)
- [ ] Implement different flows based on `campaign.type`
- [ ] Add fallback URL handling

### 4. Authentication Flow (if needed)
- [ ] Configure `authRequiredDestinations` list
- [ ] Show login screen when auth required
- [ ] Call `completePendingDeepLink()` after successful login
- [ ] Handle auth failure/cancellation

### 5. Testing
- [ ] Create test deeplinks for each format
- [ ] Test campaign resolution (valid and invalid keys)
- [ ] Test auth flow
- [ ] Verify events in Paylisher dashboard

## Code Templates

### Template 1: AppDelegate Setup
```swift
import Paylisher

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Initialize Paylisher
        let config = PaylisherConfig(
            apiKey: "phc_YOUR_API_KEY",
            host: "https://analytics.paylisher.com"
        )
        PaylisherSDK.shared.setup(config)

        // Configure auth requirements
        PaylisherSDK.shared.configureDeepLinks(authRequired: [
            "wallet",
            "transfer",
            "profile"
        ])

        // Enable debug mode (development only)
        PaylisherDeepLinkManager.shared.config.debugLogging = true

        // Set handler
        PaylisherSDK.shared.setDeepLinkHandler(self)

        return true
    }

    // Handle URL schemes
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return PaylisherSDK.shared.handleDeepLink(url)
    }

    // Handle Universal Links
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return PaylisherSDK.shared.handleUserActivity(userActivity)
    }
}
```

### Template 2: Deeplink Handler
```swift
extension AppDelegate: PaylisherDeepLinkHandler {

    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        // SDK already handled:
        // ✅ Campaign key extraction
        // ✅ Backend API call
        // ✅ Journey ID (jid) tracking
        // ✅ Analytics events

        print("📱 Deeplink: \(deepLink.destination)")

        // Check if campaign data loaded
        if let campaign = deepLink.campaignData {
            print("✅ Campaign: \(campaign.title ?? "Unknown")")
            print("✅ Type: \(campaign.type ?? "Unknown")")

            // Access metadata
            if let metadata = campaign.metaData {
                // Process custom fields
            }

            // Handle by type
            switch campaign.type {
            case "promotion":
                handlePromotion(campaign)
            case "onboarding":
                startOnboarding(campaign)
            default:
                navigateToDestination(deepLink.destination)
            }
        } else {
            // No campaign data (organic link or failed to load)
            navigateToDestination(deepLink.destination)
        }

        // Check journey tracking
        if let jid = deepLink.jid {
            print("✅ Journey ID: \(jid)")
            // All future events will include this jid automatically
        }

        // Handle auth
        if requiresAuth {
            print("⚠️ Auth required - showing login")
            showLoginScreen()
        }
    }

    func paylisherDeepLinkRequiresAuth(_ deepLink: PaylisherDeepLink,
                                      completion: @escaping (Bool) -> Void) {
        // Show login modal
        presentLoginModal { success in
            if success {
                // Login successful - SDK will navigate
                completion(true)
            } else {
                // Login failed/cancelled
                completion(false)
            }
        }
    }

    func paylisherDeepLinkDidFail(_ url: URL, error: Error?) {
        print("❌ Deeplink failed: \(url)")
        // Show error or default screen
    }

    // Helper methods
    private func navigateToDestination(_ destination: String) {
        // Your navigation logic
    }

    private func handlePromotion(_ campaign: PaylisherResolvedDeepLinkPayload) {
        // Show promotion UI
    }

    private func startOnboarding(_ campaign: PaylisherResolvedDeepLinkPayload) {
        // Start onboarding flow
    }
}
```

### Template 3: Info.plist URL Scheme
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

### Template 4: SwiftUI Integration
```swift
import SwiftUI
import Combine

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var deepLinkDestination: String?

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .onReceive(AppDelegate.deepLinkPublisher) { destination in
                deepLinkDestination = destination
            }
            .sheet(item: $deepLinkDestination) { dest in
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

## Important Notes for AI

1. **SDK Classes**:
   - `PaylisherCampaignAPI` - Backend API integration (auto-called)
   - `PaylisherDeepLinkTracker` - Analytics tracking (auto-called)
   - `PaylisherResolvedDeepLinkPayload` - Campaign data model
   - `PaylisherDeepLink` - Deeplink object with all data
   - `PaylisherDeepLinkManager` - Core manager (auto-configured)

2. **No Manual Parsing Needed**:
   - Don't write code to extract campaign key from URL
   - Don't make manual API calls to backend
   - Don't manually track journey ID
   - SDK handles all of this automatically

3. **Campaign Data Access**:
   ```swift
   if let campaign = deepLink.campaignData {
       let title = campaign.title           // Campaign name
       let type = campaign.type             // "promotion", "onboarding", etc.
       let jid = campaign.jid               // Journey ID
       let iosUrl = campaign.iosUrl         // iOS destination
       let webUrl = campaign.webUrl         // Web fallback
       let metadata = campaign.metaData     // Custom fields
   }
   ```

4. **Metadata Access**:
   ```swift
   if let metadata = campaign.metaData,
      case .string(let discount) = metadata["discount"] {
       print("Discount: \(discount)")
   }
   ```

5. **Journey Tracking**:
   - Journey ID (jid) is automatically set when present
   - All subsequent events include jid automatically
   - Persists for 24 hours by default
   - No manual tracking needed

6. **Testing Commands**:
   ```bash
   # Test URL scheme
   xcrun simctl openurl booted "yourapp://campaign/TEST_KEY"

   # Test universal link
   xcrun simctl openurl booted "https://yourapp.com/campaign/TEST_KEY"

   # Test with auth
   xcrun simctl openurl booted "yourapp://wallet?keyName=TEST_KEY&auth=required"
   ```

## My Specific Needs

[User should fill this in:]

**My app scheme**: `_____________`

**My destinations**:
- `_____________` (e.g., "products", "wallet", "profile")
- `_____________`
- `_____________`

**Auth required for**:
- `_____________` (e.g., "wallet", "transfer")
- `_____________`

**Campaign types I'll use**:
- `_____________` (e.g., "promotion", "onboarding", "referral")
- `_____________`

**Navigation framework**:
- [ ] UIKit (UINavigationController)
- [ ] SwiftUI (NavigationView/NavigationStack)
- [ ] Coordinator pattern
- [ ] Other: `_____________`

**Additional requirements**:
```
[Describe any special requirements, custom metadata fields,
specific flows, or unique use cases]
```

## Expected AI Output

Please provide:

1. **Complete AppDelegate code** with Paylisher setup
2. **PaylisherDeepLinkHandler implementation** with:
   - Campaign data handling
   - Type-based routing logic
   - Auth flow (if needed)
   - Error handling
3. **Info.plist configuration** for URL scheme
4. **Navigation helper methods** matching my framework
5. **Test commands** for my specific URLs
6. **Example campaign JSON** for my use cases

## Reference Documentation

Full documentation: See `DEEPLINK_INTEGRATION.md` in the repository

Key sections:
- Campaign Backend Architecture (how backend API works)
- URL Formats (all supported formats)
- Event Tracking (all automatic events)
- Advanced Features (auth, metadata, webhooks)
- Troubleshooting (common issues)

---

**Ready to start!** Please review the above and provide the integration code customized to my needs.
