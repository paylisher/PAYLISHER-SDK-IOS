# iOS Push — Per-Device Language via a Notification Service Extension (NSE)

Make iOS push notifications show up in the **device's language** (like Android
already does) by adding a small Notification Service Extension to the host app
and linking the Paylisher NSE helper.

---

## 1. The problem

A Paylisher push campaign can carry content in several languages (e.g. `tr` +
`en`) plus a default language.

- **Android:** the SDK builds the notification from the FCM `data` payload and
  localizes it to the device language automatically. Nothing for the host app to
  do.
- **iOS:** when the app is **backgrounded/closed**, iOS draws the notification
  **directly from the APNs `aps.alert`**, which the backend bakes in the
  campaign's **default language**. No app code runs → the device language is
  ignored → the user always sees the default (e.g. Turkish), even on an English
  device.

The **only** place iOS lets app code rewrite a remote notification before it is
shown is a **Notification Service Extension (NSE)**, launched **only when the
push carries `aps."mutable-content" = 1`**.

> **Do I have to add an NSE?** Push still works **without** it — it just shows the
> default language. The NSE only adds the per-device *language* upgrade. It is a
> one-time ~10-minute setup, and the same pattern every major push SDK
> (OneSignal, Braze, Airship, Firebase) uses for rich/modified push.

---

## 2. How it works

```
Backend (Engage)                         iOS device (app backgrounded/closed)
────────────────                         ────────────────────────────────────
Sends ONE push with:                     iOS sees aps.mutable-content = 1
  • aps.alert       = default-lang text  →  launches your single NSE
  • aps.mutable-content = 1                 NSE reads data.title / data.message,
  • data.title      = {"tr":…, "en":…}      picks the DEVICE language,
  • data.message    = {"tr":…, "en":…}      rewrites title/body, then shows it
  • data.defaultLang = "tr"
  • data.source      = "Paylisher"
```

Language order (identical to Android's `InAppLocalize`):
**device language → campaign `defaultLang` → first available value.**

---

## 3. Prerequisites — the backend

For a normal (non-silent) push the backend must:

1. Set **`aps."mutable-content": 1`** (launches the NSE).
2. Ship the language maps on the **`data`** channel:
   `data.title` / `data.message` as JSON strings like `{"tr":"…","en":"…"}`,
   plus `data.defaultLang` and `data.source = "Paylisher"`.

The Paylisher Engage backend already does this for real campaigns.

---

## 4. Integration (recommended — using the SDK helper)

### Step 1 — Add the NSE target (Xcode)

1. **File ▸ New ▸ Target… ▸ iOS ▸ Notification Service Extension ▸ Next**.
2. Product Name e.g. `NotificationService`, pick your **Team**, **Finish**.
   ("Activate scheme?" → **Activate**.)
3. Xcode creates a `NotificationService` group (`NotificationService.swift` +
   `Info.plist`), **embeds** the extension in the app, and adds the build
   dependency. Bundle id auto = `<app-bundle-id>.NotificationService`.
4. Extension target → **General ▸ Minimum Deployments** → set **≤ your app's**
   deployment target (and ≤ your test devices).
5. **Signing & Capabilities** → *Automatically manage signing* + your Team.

### Step 2 — Add the Paylisher NSE helper to the **NSE target only**

The helper is a **separate, lightweight, extension-safe** module — it does **not**
pull in the main Paylisher SDK (no UIKit / Replay), so it is safe inside an
extension.

**Swift Package Manager:**

1. Make sure the app depends on the Paylisher package on a version that
   **contains the module — 1.8.9 or newer** (older tags don't have it).
2. Select the **NSE target** (not the app) → **General ▸ Frameworks and
   Libraries** → **`+`** → under the **PAYLISHER-SDK-IOS** package pick
   **`PaylisherNotificationServiceExtension`** → **Add**.

> ⚠️ **Step 2 is required and easy to miss.** Resolving the package is not
> enough — each *target* must explicitly link the product it imports. Skip it and
> you get **`No such module 'PaylisherNotificationServiceExtension'`**. If the
> product doesn't show up in the `+` list, run **File ▸ Packages ▸ Reset Package
> Caches**, then **Resolve Package Versions**, and try again.

You can also remove `Paylisher` / `PaylisherFramework` from the **NSE** target's
Frameworks and Libraries if they were linked there — the extension only needs
`PaylisherNotificationServiceExtension`. (Keep them on the app target.)

**CocoaPods:** in your `Podfile`, add it under the **NSE target**:

```ruby
target 'NotificationService' do        # your NSE target
  pod 'PaylisherNotificationServiceExtension'
end
```

### Step 3 — Replace `NotificationService.swift`

```swift
import UserNotifications
import PaylisherNotificationServiceExtension

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        // Paylisher localizes ONLY its own pushes and returns true; returns
        // false immediately for anything else so you can chain other SDKs.
        if PaylisherNotificationService.didReceive(
            request, with: bestAttemptContent, withContentHandler: contentHandler
        ) { return }

        // Not a Paylisher push → your other push SDKs / your own logic:
        // if OneSignal.didReceiveNotificationExtensionRequest(request, with: bestAttemptContent, withContentHandler: contentHandler) { return }
        contentHandler(bestAttemptContent ?? request.content)
    }

    override func serviceExtensionTimeWillExpire() {
        // Deliver the best attempt (already localized in place) if a slow image
        // download was cut short.
        if let handler = contentHandler, let content = bestAttemptContent {
            handler(content)
        }
    }
}
```

The only Paylisher-specific line is the `if PaylisherNotificationService.didReceive(…) { return }`.

### Step 4 — Fix `Multiple commands produce … NotificationService.appex/Info.plist`

Xcode 15/16 add the NSE folder as a **synchronized group**, so `Info.plist` gets
both *copied as a resource* **and** *processed as the target's Info.plist* →
duplicate output → build error.

**Fix:** Project navigator → select `NotificationService/Info.plist` → **File
Inspector (⌥⌘1)** → under **Target Membership**, **uncheck** the
`NotificationService` target. Then **Product ▸ Clean Build Folder (⇧⌘K)** and
rebuild.

### Step 5 — (Optional) App Group

Only needed if you *also* use the NSE to write shared state (e.g. a "received"
marker for analytics). Add the **same App Group** to **both** the app and the
extension (Signing & Capabilities ▸ App Groups). **Pure localization does NOT
need this.**

---

## 5. Multi-SDK apps

**iOS allows only ONE Notification Service Extension per app.** If your app (or
your customer's app) uses several push SDKs — Paylisher + Firebase + OneSignal +
your own — they must all share that single NSE.

The Paylisher helper is built for this:

- It is a set of **static functions**, never a base class (you can only inherit
  one base class, and a base class would "own" the whole NSE).
- `PaylisherNotificationService.didReceive(…)` touches **only** pushes marked
  `source == "Paylisher"` and returns **`false`** for everything else.

So your single NSE just chains the providers — each claims its own pushes:

```swift
override func didReceive(_ request: UNNotificationRequest,
                         withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

    if PaylisherNotificationService.didReceive(request, with: bestAttemptContent, withContentHandler: contentHandler) { return }
    // if OneSignal.didReceiveNotificationExtensionRequest(request, with: bestAttemptContent, withContentHandler: contentHandler) { return }
    // if FirebaseMessaging... { return }
    contentHandler(bestAttemptContent ?? request.content)
}
```

This mirrors how you already route foreground pushes by `source` in your app
delegate — same idea, one background NSE.

---

## 6. The backend data contract (what the NSE reads)

| Key | Example | Purpose |
|---|---|---|
| `source` | `"Paylisher"` | the NSE only touches Paylisher pushes |
| `title` | `{"tr":"…","en":"…"}` (JSON string) | localized title source |
| `message` | `{"tr":"…","en":"…"}` (JSON string) | localized body source |
| `defaultLang` | `"tr"` | fallback language |
| `imageUrl` | `"https://…"` | optional rich media |
| `aps.mutable-content` | `1` | **required** — launches the NSE |
| `aps.alert` | default-lang text | the no-NSE fallback |

---

## 7. Testing

> ⚠️ **`xcrun simctl push` does NOT trigger the NSE.** It injects the
> notification directly and bypasses the APNs pipeline, so you always see the raw
> (default-language) alert. **Test with a REAL APNs/FCM push.**

1. Run the app on a **real device** (or an Apple-Silicon simulator that obtained a
   real FCM token).
2. Set the device language to a **non-default** language (e.g. English).
3. **Background the app.**
4. Send a real campaign — or a direct FCM v1 send to the device token:

   ```jsonc
   {
     "message": {
       "token": "<DEVICE_FCM_TOKEN>",
       "data": {
         "source": "Paylisher",
         "type": "PUSH",
         "title":   "{\"tr\":\"Merhaba\",\"en\":\"Hello\"}",
         "message": "{\"tr\":\"Selam\",\"en\":\"Hi there\"}",
         "defaultLang": "tr"
       },
       "apns": { "payload": { "aps": {
         "alert": { "title": "Merhaba", "body": "Selam" },
         "sound": "default",
         "mutable-content": 1
       } } }
     }
   }
   ```
5. **Expected:** the banner appears in the device language.

*(FCM v1 needs an OAuth token from the project's service account; the legacy
single-key API is shut down.)*

---

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Build error `No such module 'PaylisherNotificationServiceExtension'` | The product isn't linked to the **NSE target** (or your SDK version < 1.8.9) | Add the product to the NSE target's Frameworks and Libraries (Step 2); ensure the Paylisher dependency is **1.8.9+**; if it's not in the `+` list, **File ▸ Packages ▸ Reset Package Caches** → Resolve |
| Always the default language, on a real push | Push has no `mutable-content` → NSE never runs | Confirm the backend sets `aps.mutable-content = 1` |
| Notification unchanged, only via `simctl push` | simctl **bypasses** the NSE | Test with a real APNs/FCM push |
| Notification unchanged, app in **foreground** | NSE only runs when backgrounded/closed | Background the app before sending |
| Still default after a code change | Stale extension install | Delete the app, **Clean Build Folder**, reinstall |
| Only a "test/Deneme" send isn't localized | That send didn't include the `{tr,en}` maps on `data` | Test with a real campaign send |
| Build error: *Multiple commands produce … Info.plist* | Synchronized-folder Info.plist duplication | Step 4 (uncheck Info.plist Target Membership) |
| FCM `messaging/mismatched-credential` | The app's Firebase project ≠ the sender's | Use the app's Firebase project's service account |

**Confirm the NSE runs** (temporary): add `NSLog("NSE lang=\(Locale.preferredLanguages.first ?? "?")")` at the top of `didReceive`, then Mac → **Console.app** → select the device → filter your tag → send a push (app backgrounded). No line = the NSE isn't being invoked (see the first two rows).

---

## 9. Alternative — no SDK dependency (standalone copy-paste)

If you can't (or don't want to) add the `PaylisherNotificationServiceExtension`
dependency to your extension, paste this **self-contained** implementation into
your `NotificationService.swift` instead of Steps 2–3. It has no dependencies
(only `Foundation` + `UserNotifications`) but you own the code and must re-sync it
if the logic changes.

```swift
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let best = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content); return
        }
        self.bestAttemptContent = best
        guard (best.userInfo["source"] as? String) == "Paylisher" else {
            contentHandler(best); return   // not ours → pass through / chain other SDKs
        }
        let defaultLang = best.userInfo["defaultLang"] as? String
        if let t = best.userInfo["title"] as? String, let v = Self.pick(t, defaultLang) { best.title = v }
        if let b = best.userInfo["message"] as? String, let v = Self.pick(b, defaultLang) { best.body = v }
        if let s = best.userInfo["imageUrl"] as? String, !s.isEmpty, let url = URL(string: s) {
            URLSession.shared.downloadTask(with: url) { local, _, _ in
                if let local = local {
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(url.pathExtension.isEmpty ? "jpg" : url.pathExtension)
                    if (try? FileManager.default.moveItem(at: local, to: tmp)) != nil,
                       let att = try? UNNotificationAttachment(identifier: UUID().uuidString, url: tmp) {
                        best.attachments = [att]
                    }
                }
                contentHandler(best)
            }.resume()
        } else {
            contentHandler(best)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let h = contentHandler, let c = bestAttemptContent { h(c) }
    }

    /// device language → defaultLang → first value; nil if not a {lang:text} map.
    static func pick(_ json: String, _ defaultLang: String?) -> String? {
        guard let data = json.data(using: .utf8),
              let map = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              !map.isEmpty else { return nil }
        let dev = (Locale.preferredLanguages.first ?? Locale.current.languageCode ?? "")
            .split(separator: "-").first.map { $0.lowercased() }
        if let d = dev, let v = map[d] { return v }
        if let dl = defaultLang, let v = map[dl] { return v }
        return map.values.first
    }
}
```

---

## 10. Notes

- The helper is **backward-compatible**: apps *without* an NSE keep showing the
  baked default-language alert; the backend's `mutable-content` is harmless for
  them and for Android.
- **In-app messages are unaffected** — they are delivered as silent pushes (no
  `alert`), which never launch the NSE, and are rendered by the SDK in-app.
