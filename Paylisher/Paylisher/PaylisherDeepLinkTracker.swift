//
//  PaylisherDeepLinkTracker.swift
//  Paylisher
//
//  Created by Paylisher SDK on 24.12.2025.
//

import Foundation

/// DeepLink tracking ve Paylisher'a loglama için singleton service
public final class PaylisherDeepLinkTracker {

    public static let shared = PaylisherDeepLinkTracker()
    private init() {}

    // MARK: - 1️⃣ Ham DeepLink Log (URL Alındığında)

    /// Gelen ham deeplink'i tüm detaylarıyla loglar
    /// - Parameters:
    ///   - url: Gelen deeplink URL
    ///   - source: Deeplink kaynağı (örn: "url_scheme", "universal_link", "push_notification")
    public func logIncoming(url: URL, source: String) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Query parametrelerini dictionary'ye çevir
        var queryDict: [String: String] = [:]
        for item in queryItems {
            queryDict[item.name] = item.value ?? ""
        }

        // URL path'i parçalara ayır
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        var properties: [String: Any] = [
            // Kaynak bilgisi
            "source": source,
            "timestamp": ISO8601DateFormatter().string(from: Date()),

            // URL bileşenleri
            "full_url": url.absoluteString,
            "scheme": url.scheme ?? "",
            "host": url.host ?? "",
            "path": url.path,
            "path_components": pathComponents,
            "query": components?.percentEncodedQuery ?? "",
            "query_items": queryDict,
            "fragment": url.fragment ?? "",

            // URL parçalarının sayısı (analytics için)
            "query_param_count": queryItems.count,
            "path_component_count": pathComponents.count
        ]

        // Port varsa ekle
        if let port = url.port {
            properties["port"] = port
        }

        // User info varsa ekle
        if let user = url.user {
            properties["user"] = user
        }

        // Campaign key varsa tespit et ve ekle
        if let campaignKey = extractCampaignKey(from: url) {
            properties["campaign_key_detected"] = campaignKey
            properties["has_campaign_key"] = true
        } else {
            properties["has_campaign_key"] = false
        }

        PaylisherSDK.shared.capture("deeplink_received", properties: properties)
    }

    // MARK: - 2️⃣ Resolved DeepLink Log (Backend'den Gelen Data ile)

    /// Backend'den resolve edilmiş campaign bilgilerini loglar
    /// - Parameters:
    ///   - url: Orijinal deeplink URL
    ///   - source: Deeplink kaynağı
    ///   - resolved: Backend'den gelen resolve edilmiş payload
    public func logResolved(url: URL, source: String, resolved: PaylisherResolvedDeepLinkPayload) {
        var properties: [String: Any] = [
            // Orijinal URL bilgisi
            "source": source,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "opened_full_url": url.absoluteString,
            "opened_scheme": url.scheme ?? "",
            "opened_host": url.host ?? "",
            "opened_path": url.path
        ]

        // Backend'den gelen tüm campaign bilgilerini ekle
        let resolvedProps = resolved.toPropertiesDictionary()
        properties.merge(resolvedProps) { (_, new) in new }

        // Campaign'in aktif olup olmadığını kontrol et (expireAt varsa)
        if let metaData = resolved.metaData,
           case .string(let expireAtStr) = metaData["expireAt"] {
            let isoFormatter = ISO8601DateFormatter()
            if let expireDate = isoFormatter.date(from: expireAtStr) {
                properties["is_campaign_active"] = expireDate > Date()
                properties["days_until_expire"] = Calendar.current.dateComponents(
                    [.day],
                    from: Date(),
                    to: expireDate
                ).day ?? 0
            }
        }

        // URL type detection (web/app store/fallback)
        properties["has_web_url"] = !(resolved.webUrl?.isEmpty ?? true)
        properties["has_ios_url"] = !(resolved.iosUrl?.isEmpty ?? true)
        properties["has_android_url"] = !(resolved.androidUrl?.isEmpty ?? true)
        properties["has_fallback_url"] = !(resolved.fallbackUrl?.isEmpty ?? true)
        properties["has_custom_scheme"] = !(resolved.scheme?.isEmpty ?? true)
        properties["has_webhook"] = !(resolved.webhookUrl?.isEmpty ?? true)
        properties["has_metadata"] = resolved.metaData != nil && !resolved.metaData!.isEmpty

        PaylisherSDK.shared.capture("deeplink_resolved", properties: properties)
    }

    // MARK: - 3️⃣ DeepLink Resolution Failure Log

    /// Campaign resolution başarısız olduğunda loglar
    /// - Parameters:
    ///   - url: Orijinal deeplink URL
    ///   - source: Deeplink kaynağı
    ///   - keyName: Resolve edilmeye çalışılan campaign key
    ///   - error: Hata detayı
    public func logResolutionFailed(url: URL, source: String, keyName: String, error: Error) {
        PaylisherSDK.shared.capture("deeplink_resolve_failed", properties: [
            "source": source,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "full_url": url.absoluteString,
            "campaign_key": keyName,
            "error_description": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ])
    }

    // MARK: - 4️⃣ DeepLink Navigation Log

    /// DeepLink ile yapılan navigasyonu loglar
    /// - Parameters:
    ///   - destination: Hedef ekran/sayfa
    ///   - url: Orijinal deeplink URL
    ///   - source: Deeplink kaynağı
    public func logNavigation(destination: String, url: URL, source: String) {
        PaylisherSDK.shared.capture("deeplink_navigation", properties: [
            "destination": destination,
            "source": source,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "full_url": url.absoluteString,
            "navigation_category": "deeplink"
        ])
    }

    // MARK: - 5️⃣ Universal Link Specific Log

    /// Universal Link özelinde detaylı log
    /// - Parameters:
    ///   - url: Universal link URL
    ///   - host: Domain/host
    ///   - path: URL path
    public func logUniversalLink(url: URL, host: String, path: String) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        var queryDict: [String: String] = [:]
        for item in queryItems {
            queryDict[item.name] = item.value ?? ""
        }

        PaylisherSDK.shared.capture("universal_link_received", properties: [
            "host": host,
            "path": path,
            "full_url": url.absoluteString,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "query_items": queryDict,
            "navigation_category": "universal_link",
            "campaign_key": extractCampaignKey(from: url) ?? ""
        ])
    }

    // MARK: - Helper Methods

    /// URL'den campaign key'i extract eder
    /// Desteklenen formatlar:
    /// - Query parameter: ?keyName=XXX, ?key=XXX, ?k=XXX
    /// - Path: /campaign/XXX
    /// - Path: /c/XXX
    private func extractCampaignKey(from url: URL) -> String? {
        // 1️⃣ Query parametrelerinden kontrol et
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            // keyName öncelikli
            if let value = items.first(where: { $0.name == "keyName" })?.value, !value.isEmpty {
                return value
            }
            // key alternatif
            if let value = items.first(where: { $0.name == "key" })?.value, !value.isEmpty {
                return value
            }
            // k kısa form
            if let value = items.first(where: { $0.name == "k" })?.value, !value.isEmpty {
                return value
            }
        }

        // 2️⃣ Path'den kontrol et: /campaign/<key> veya /c/<key>
        let pathParts = url.pathComponents.filter { $0 != "/" }

        // /campaign/XXX formatı
        if let index = pathParts.firstIndex(of: "campaign"),
           pathParts.count > index + 1 {
            let key = pathParts[index + 1]
            if !key.isEmpty {
                return key
            }
        }

        // /c/XXX formatı (kısa form)
        if let index = pathParts.firstIndex(of: "c"),
           pathParts.count > index + 1 {
            let key = pathParts[index + 1]
            if !key.isEmpty {
                return key
            }
        }

        // 3️⃣ Eğer path sadece tek bir component ise ve campaign/c yoksa, direkt onu al
        if pathParts.count == 1 {
            let potentialKey = pathParts[0]
            // Short link domain (https://link.usepublisher.com/nARvW): uzunluk kontrolü olmadan kabul et
            if let host = url.host, host == "link.usepublisher.com" {
                return potentialKey
            }
            // Genel durum: en az 4 karakter (kısa key'leri de yakala)
            if potentialKey.count >= 4 {
                return potentialKey
            }
        }

        return nil
    }
}
