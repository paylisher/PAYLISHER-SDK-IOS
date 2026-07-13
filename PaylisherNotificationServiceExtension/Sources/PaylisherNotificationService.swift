//
//  PaylisherNotificationService.swift
//  PaylisherNotificationServiceExtension
//
//  Drop-in Notification Service Extension helper for per-device push language.
//
//  WHY
//  ---
//  When an iOS app is backgrounded/closed, iOS draws a remote push straight from
//  the APNs `aps.alert`, which the backend bakes in the campaign's DEFAULT
//  language — so the device language is ignored (Android localizes client-side
//  and doesn't have this problem). A Notification Service Extension is the only
//  place app code can rewrite a push before it is shown, and iOS launches it
//  only when the push carries `aps."mutable-content" = 1` (the Paylisher backend
//  sends this). This helper reads the {tr,en,…} language maps Paylisher ships on
//  the FCM `data` channel and rewrites title/body to the device's language
//  (device language → campaign defaultLang → first available).
//
//  MULTI-SDK SAFE
//  --------------
//  iOS allows only ONE Notification Service Extension per app, so if the host app
//  uses several push SDKs they must share that single NSE. This API is therefore
//  a set of STATIC functions (never a base class) that touch ONLY Paylisher
//  pushes (`source == "Paylisher"`) and return `false` for everything else, so
//  you can chain other providers (Firebase, OneSignal, your own) in the same NSE.
//
//  Extension-safe: uses only Foundation + UserNotifications — no UIKit, no
//  Firebase, no app-only APIs.
//
//  USAGE (your app's single NotificationService):
//
//      import UserNotifications
//      import PaylisherNotificationServiceExtension
//
//      class NotificationService: UNNotificationServiceExtension {
//          var contentHandler: ((UNNotificationContent) -> Void)?
//          var bestAttemptContent: UNMutableNotificationContent?
//
//          override func didReceive(_ request: UNNotificationRequest,
//                                   withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
//              self.contentHandler = contentHandler
//              self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
//
//              // Paylisher claims + handles ONLY its own pushes; false otherwise.
//              if PaylisherNotificationService.didReceive(request,
//                                                         with: bestAttemptContent,
//                                                         withContentHandler: contentHandler) { return }
//
//              // Not a Paylisher push → your other SDKs / your own logic:
//              // if OneSignal.didReceiveNotificationExtensionRequest(...) { return }
//              contentHandler(bestAttemptContent ?? request.content)
//          }
//
//          override func serviceExtensionTimeWillExpire() {
//              if let handler = contentHandler, let content = bestAttemptContent {
//                  handler(content)  // best attempt (already localized in place)
//              }
//          }
//      }
//

import Foundation
import UserNotifications

public enum PaylisherNotificationService {

    /// `true` if this notification is a Paylisher push (i.e. its data payload has
    /// `source == "Paylisher"`). Use it to route in a multi-SDK NSE.
    public static func isPaylisherNotification(_ request: UNNotificationRequest) -> Bool {
        (request.content.userInfo["source"] as? String) == "Paylisher"
    }

    /// Handle a notification request in your NSE's `didReceive`.
    ///
    /// - Returns: `true` if this was a Paylisher push — in which case this method
    ///   localizes `bestAttemptContent` in place, attaches any `imageUrl`, and
    ///   eventually calls `contentHandler`. Returns `false` IMMEDIATELY (doing
    ///   nothing) if it is NOT a Paylisher push, so you can hand it to the next
    ///   push SDK or deliver it yourself.
    ///
    /// - Parameters:
    ///   - request: the incoming `UNNotificationRequest`.
    ///   - bestAttemptContent: your mutable copy of `request.content`. This object
    ///     is mutated in place, so your `serviceExtensionTimeWillExpire()` can
    ///     deliver it (already localized) if a slow image download is cut short.
    ///   - contentHandler: your NSE's content handler. Called exactly once, only
    ///     when the push is a Paylisher push.
    @discardableResult
    public static func didReceive(
        _ request: UNNotificationRequest,
        with bestAttemptContent: UNMutableNotificationContent?,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) -> Bool {
        guard isPaylisherNotification(request) else { return false }

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return true
        }

        localizeInPlace(content)

        if let imageURLString = content.userInfo["imageUrl"] as? String,
           !imageURLString.isEmpty,
           let imageURL = URL(string: imageURLString) {
            downloadAttachment(from: imageURL) { attachment in
                if let attachment = attachment {
                    content.attachments = [attachment]
                }
                contentHandler(content)
            }
        } else {
            contentHandler(content)
        }
        return true
    }

    /// Synchronous, transform-only variant: localizes `content`'s title/body in
    /// place if it is a Paylisher push and returns `true`; otherwise leaves it
    /// untouched and returns `false`. Does NOT download images and does NOT call
    /// any handler — use this if you prefer to own the content handler and just
    /// want the text localized (e.g. to compose several SDKs' transforms before
    /// calling `contentHandler` once yourself).
    @discardableResult
    public static func localize(_ content: UNMutableNotificationContent) -> Bool {
        guard (content.userInfo["source"] as? String) == "Paylisher" else { return false }
        localizeInPlace(content)
        return true
    }

    // MARK: - Internals

    private static func localizeInPlace(_ content: UNMutableNotificationContent) {
        let userInfo = content.userInfo
        let defaultLang = userInfo["defaultLang"] as? String
        if let titleJSON = userInfo["title"] as? String,
           let value = pickLanguage(titleJSON, defaultLang: defaultLang) {
            content.title = value
        }
        if let bodyJSON = userInfo["message"] as? String,
           let value = pickLanguage(bodyJSON, defaultLang: defaultLang) {
            content.body = value
        }
    }

    /// Picks the device-language value from a `{"tr":"…","en":"…"}` JSON string.
    /// Order: device language → campaign `defaultLang` → first available value.
    /// Returns `nil` if the string is not a non-empty `{lang: text}` map (so the
    /// caller keeps the original text). Uses `Locale.preferredLanguages` — the
    /// real device language, independent of the extension bundle's localizations,
    /// primary subtag only ("en-TR" → "en"). Mirrors Android's `InAppLocalize`.
    static func pickLanguage(_ jsonString: String, defaultLang: String?) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let map = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              !map.isEmpty else {
            return nil
        }
        let deviceLang = (Locale.preferredLanguages.first ?? Locale.current.languageCode ?? "")
            .split(separator: "-").first.map { $0.lowercased() }

        if let deviceLang = deviceLang, let value = map[deviceLang] {
            return value
        }
        if let defaultLang = defaultLang, let value = map[defaultLang] {
            return value
        }
        return map.values.first
    }

    private static func downloadAttachment(
        from url: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        URLSession.shared.downloadTask(with: url) { localURL, _, _ in
            guard let localURL = localURL else { completion(nil); return }
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            do {
                try FileManager.default.moveItem(at: localURL, to: tmpURL)
                let attachment = try UNNotificationAttachment(
                    identifier: UUID().uuidString, url: tmpURL, options: nil
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }.resume()
    }
}
