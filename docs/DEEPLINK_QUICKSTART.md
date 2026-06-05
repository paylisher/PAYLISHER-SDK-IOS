# Paylisher Deeplink - 5 Minute Quick Start

> Get deeplink + campaign tracking working in under 5 minutes

## What You Get

✅ Automatic campaign data from backend
✅ Journey tracking (attribution)
✅ Detailed analytics events
✅ Zero URL parsing code
✅ Auth flow handling

## Step 1: Add URL Scheme (30 seconds)

**Info.plist**:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

Replace `yourapp` with your app's scheme.

## Step 2: AppDelegate Setup (2 minutes)

```swift
import Paylisher

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 1. Initialize SDK
        let config = PaylisherConfig(apiKey: "phc_YOUR_KEY", host: "https://analytics.paylisher.com")
        PaylisherSDK.shared.setup(config)

        // 2. Set deeplink handler
        PaylisherSDK.shared.setDeepLinkHandler(self)

        return true
    }

    // 3. Handle deeplinks
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return PaylisherSDK.shared.handleDeepLink(url)
    }
}

// 4. Implement handler
extension AppDelegate: PaylisherDeepLinkHandler {

    func paylisherDidReceiveDeepLink(_ deepLink: PaylisherDeepLink, requiresAuth: Bool) {
        print("📱 Deeplink to: \(deepLink.destination)")

        // Check campaign data (automatically fetched from backend!)
        if let campaign = deepLink.campaignData {
            print("✅ Campaign: \(campaign.title ?? "Unknown")")
            print("✅ Journey ID: \(campaign.jid ?? "none")")
        }

        // Navigate to destination
        navigateToDestination(deepLink.destination)
    }

    private func navigateToDestination(_ destination: String) {
        // Your navigation code
        print("🚀 Navigate to: \(destination)")
    }
}
```

## Step 3: Test (1 minute)

```bash
# Run in terminal while app is running
xcrun simctl openurl booted "yourapp://campaign/TEST_KEY_123"
```

**Expected console output**:
```
[PaylisherDeepLink] Handling URL: yourapp://campaign/TEST_KEY_123
[PaylisherDeepLink] Resolving campaign: TEST_KEY_123
[PaylisherDeepLink] Campaign resolved successfully: Test Campaign
📱 Deeplink to: campaign
✅ Campaign: Test Campaign
✅ Journey ID: journey_abc123
🚀 Navigate to: campaign
```

## Done! 🎉

Your app now:
- ✅ Opens deeplinks
- ✅ Fetches campaign data from backend automatically
- ✅ Tracks journey attribution
- ✅ Sends analytics events

## Supported URL Formats

All of these work automatically:

```
yourapp://campaign/ABC123
yourapp://c/ABC123
yourapp://ABC1234567890
yourapp://products?keyName=ABC123
yourapp://products?key=ABC123
yourapp://products?k=ABC123
https://yourapp.com/campaign/ABC123
```

SDK extracts the campaign key and fetches data automatically!

## What Happens Automatically

When user opens `yourapp://campaign/ABC123`:

1. **SDK extracts** campaign key: `ABC123`
2. **SDK calls** `GET https://api.usepublisher.com/campaign/ABC123`
3. **SDK receives** campaign data (title, type, URLs, metadata, jid)
4. **SDK sets** journey ID for attribution
5. **SDK sends** analytics events:
   - `deeplink_received` (raw URL)
   - `deeplink_resolved` (campaign data)
   - `Deep Link Opened` (complete event)
6. **SDK calls** your handler with all data
7. **You navigate** to destination

## Add Auth Flow (Optional)

```swift
// In didFinishLaunchingWithOptions:
PaylisherSDK.shared.configureDeepLinks(authRequired: [
    "wallet",
    "transfer",
    "profile"
])

// In handler:
func paylisherDeepLinkRequiresAuth(_ deepLink: PaylisherDeepLink,
                                  completion: @escaping (Bool) -> Void) {
    showLoginScreen { success in
        completion(success)
    }
}
```

## View Analytics

Open Paylisher dashboard to see events:
- `Deep Link Opened` - with full campaign data
- `deeplink_received` - raw URL details
- `deeplink_resolved` - backend response

Each event includes:
- Campaign title, type, metadata
- Journey ID (jid) for attribution
- User properties
- Custom parameters

## Next Steps

- **Full docs**: See `DEEPLINK_INTEGRATION.md`
- **AI help**: See `AI_INTEGRATION_PROMPT.md`
- **Advanced features**: Auth flow, metadata, type-based routing

## Need Help?

Common issues and solutions in `DEEPLINK_INTEGRATION.md` → Troubleshooting section

---

**That's it!** You now have enterprise-grade deeplink + campaign tracking in your app.
