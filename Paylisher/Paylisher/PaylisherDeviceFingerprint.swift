//
//  PaylisherDeviceFingerprint.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation
import UIKit
import WebKit

/**
 * Generates a device fingerprint for deferred deep link attribution.
 *
 * The fingerprint is a coarse, NON-IDENTIFYING hash of publicly visible device traits. It
 * lets the backend match an install back to a click probabilistically, without any
 * device-unique identifier ever being read or transmitted.
 *
 * Privacy note — deliberately contains NO advertising identifier:
 * - This file (and the whole core module) imports neither `AdSupport` nor
 *   `AppTrackingTransparency`, so the shipped binary carries none of those symbols. That is
 *   what keeps the core SDK out of App Review's ATT symbol scan (Guidelines 2.5.1 / 2.1),
 *   which a runtime flag cannot do.
 * - IDFA support lives in the separate, optional `PaylisherATT` module and reaches the SDK
 *   through the `PaylisherIDFA` seam. See `PaylisherIDFAProvider.swift`.
 * - All fingerprint inputs are hashed (SHA-256) before transmission.
 *
 * Components used by the live V1 fingerprint:
 * - Device model
 * - Timezone
 * - Language code
 */
/**
 * The raw, coarse device traits behind the V1 fingerprint, plus screen width and
 * OS major. Sent ALONGSIDE the hash (never instead of it) so the backend can
 * compare the install to a click field by field instead of requiring an exact
 * hash match. Everything here is already visible to the campaign landing page
 * through the browser, so this transmits nothing new about the device — and it
 * still contains no identifier of any kind.
 */
internal struct PaylisherDeviceSignals {
    let model: String
    let screenWidth: String?
    let osMajor: String
    let timezone: String
    let language: String

    /// Compact JSON for the `X-Device-Signals` header. Hand-rolled: five known
    /// keys, so no Codable round trip on the launch path.
    func toJson() -> String {
        func q(_ s: String?) -> String {
            guard let s else { return "null" }
            let escaped = s
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return "{\"model\":\(q(model)),\"screenWidth\":\(q(screenWidth))," +
            "\"osMajor\":\(q(osMajor)),\"tz\":\(q(timezone)),\"lang\":\(q(language))}"
    }
}

internal class PaylisherDeviceFingerprint {

    /**
     * The V1 fingerprint's raw inputs plus screen width and OS major, for
     * field-level matching on the backend. Reads the SAME sources as
     * generateDeferredFingerprintV1() so the two can never disagree.
     *
     * Screen width and OS major are deliberately NOT in the hash (see the notes
     * in generateDeferredFingerprintV1) but ARE useful as scoring fields: a
     * mismatch there lowers confidence instead of vetoing the match outright.
     */
    func collectSignals() -> PaylisherDeviceSignals {
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        let widthPx = Int(bounds.width * scale)
        let heightPx = Int(bounds.height * scale)
        return PaylisherDeviceSignals(
            model: UIDevice.current.model,
            screenWidth: String(min(widthPx, heightPx)),
            osMajor: UIDevice.current.systemVersion.split(separator: ".").first.map(String.init) ?? "",
            timezone: TimeZone.current.identifier,
            language: Locale.current.languageCode ?? "en"
        )
    }

    /**
     * Generates a deferred deep link fingerprint (V1) that matches backend click-time fingerprint.
     *
     * IMPORTANT: This fingerprint MUST match exactly what backend generates at click-time.
     * Backend cannot access IDFV/IDFA at click-time, so we use only publicly available device info.
     *
     * Algorithm (MUST match the backend web landing's iOS branch exactly):
     *   sha256( deviceModel | timezone | languageCode )  — joined with "|", lowercase hex.
     * 1. Device model (UIDevice.current.model) - e.g., "iPhone", "iPad"
     * 2. Timezone (TimeZone.current.identifier) - e.g., "Europe/Istanbul"
     * 3. Language code (Locale.current.languageCode) - e.g., "tr" (NOT "tr_TR")
     *
     * DELIBERATELY EXCLUDED (computed + logged for debug, never hashed):
     *   - OS version: iOS 26+ Safari freezes the UA OS token, so the web side can't read it.
     *   - Screen width: web screen.width*dpr diverges from native UIScreen*scale under Display Zoom
     *     ("Zoomed" mode) and inside WebViews, so iOS installs never matched. (Android keeps width.)
     *
     * Example raw string: "iPhone|Europe/Istanbul|tr"
     *
     * @return 64-character lowercase hex SHA-256 fingerprint string
     */
    func generateDeferredFingerprintV1() -> String {
        print("========================================")
        print("🔍 [Fingerprint V1] Starting generation")
        print("========================================")

        // Get UserAgent for logging (this is what backend sees in HTTP requests)
        let userAgent = getUserAgent()
        print("🌐 UserAgent String (from WKWebView):")
        print("   \"\(userAgent)\"")
        print("----------------------------------------")

        var components: [String] = []

        // 1. Device model (e.g., "iPhone", "iPad")
        let deviceModel = UIDevice.current.model
        components.append(deviceModel)
        print("📱 [1/3] Device Model: \(deviceModel)")

        // OS version EXCLUDED from fingerprint: iOS 26+ Safari freezes the UA OS token
        // (e.g. "CPU iPhone OS 18_7") so the web click-time script can never read the real
        // systemVersion (e.g. 26.3.1) -> fingerprints never matched. Logged for debug only.
        let osVersion = UIDevice.current.systemVersion
        print("💿 [info] OS Version (NOT in fingerprint): \(osVersion)")

        // Screen width EXCLUDED from the fingerprint: web screen.width * devicePixelRatio diverges
        // from the native UIScreen.bounds * scale under Display Zoom ("Zoomed" mode) and inside
        // WebViews / in-app browsers, so the click-time and install-time hashes never matched on
        // iOS. Computed + logged for debug only; NOT appended. (The Android SDK keeps screen width.)
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        let widthPx = Int(bounds.width * scale)
        let heightPx = Int(bounds.height * scale)
        let screenWidth = String(min(widthPx, heightPx))
        print("📐 [info] Screen Width (NOT in fingerprint): \(screenWidth) [wPt=\(bounds.width), hPt=\(bounds.height), scale=\(scale)]")

        // 2. Timezone identifier (e.g., "Europe/Istanbul")
        let timezone = TimeZone.current.identifier
        components.append(timezone)
        print("🌍 [2/3] Timezone: \(timezone)")

        // 3. Language code only (e.g., "tr", NOT "tr_TR")
        let languageCode = Locale.current.languageCode ?? "en"
        components.append(languageCode)
        print("🗣️ [3/3] Language Code: \(languageCode)")

        print("----------------------------------------")
        print("📋 All Components (in order):")
        for (index, component) in components.enumerated() {
            print("   [\(index + 1)] \(component)")
        }

        // Join with "|" and hash
        let combined = components.joined(separator: "|")
        print("----------------------------------------")
        print("🔗 Combined String (before hash):")
        print("   \"\(combined)\"")

        let fingerprint = sha256(combined)
        print("----------------------------------------")
        print("🔐 SHA-256 Fingerprint:")
        print("   \(fingerprint)")
        print("========================================")

        return fingerprint
    }

    // MARK: - Device Information
    //
    // REMOVED (deliberately, do not reintroduce here):
    //   - `generate(includeIDFA:)`  — a rich IDFV+IDFA fingerprint that nothing called.
    //   - `getIDFV()`               — its only consumer was `generate()`.
    //   - `getIDFA()`               — the SDK's ONLY `ATTrackingManager.requestTrackingAuthorization()`
    //                                 call site. It carried `includeIDFA: Bool = true`, so wiring up
    //                                 a single caller would have made every host app show the ATT
    //                                 permission prompt on first launch, unasked, and crash outright
    //                                 on any app without `NSUserTrackingUsageDescription`.
    //
    // The SDK must never present a permission prompt of its own; the host app owns that call and
    // its timing. Reading an already-granted IDFA now lives in the optional `PaylisherATT` module
    // and is reached through the `PaylisherIDFA` seam, which keeps `AdSupport` /
    // `AppTrackingTransparency` symbols out of the core binary entirely.

    /**
     * Gets UserAgent string (what backend sees in HTTP requests).
     *
     * This is useful for debugging fingerprint mismatches between iOS SDK and backend.
     *
     * @return UserAgent string
     */
    private func getUserAgent() -> String {
        // Create a temporary UserAgent string matching what iOS sends in HTTP requests
        let systemVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        let deviceModel = UIDevice.current.model

        // Standard iOS UserAgent format:
        // "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        let userAgent = "Mozilla/5.0 (\(deviceModel); CPU \(deviceModel) OS \(systemVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"

        return userAgent
    }

    /**
     * Gets device model (e.g., "iPhone14,2" for iPhone 13 Pro).
     *
     * @return Device model identifier
     */
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    /**
     * Gets device name (e.g., "iPhone", "iPad").
     *
     * @return Device name
     */
    private func getDeviceName() -> String {
        return UIDevice.current.model
    }

    /**
     * Gets OS version (e.g., "16.4.1").
     *
     * @return OS version string
     */
    private func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    /**
     * Gets screen resolution in format "widthxheight" (in points).
     *
     * @return Screen resolution string (e.g., "390x844") or nil
     */
    private func getScreenResolution() -> String? {
        let bounds = UIScreen.main.bounds
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        return "\(width)x\(height)"
    }

    /**
     * Gets screen scale (e.g., "2.0" for @2x, "3.0" for @3x).
     *
     * @return Screen scale string
     */
    private func getScreenScale() -> String {
        let scale = UIScreen.main.scale
        return String(format: "%.1f", scale)
    }

    /**
     * Gets timezone identifier (e.g., "America/New_York").
     *
     * @return Timezone identifier
     */
    private func getTimezone() -> String {
        return TimeZone.current.identifier
    }

    /**
     * Gets locale identifier (e.g., "en_US").
     *
     * @return Locale identifier
     */
    private func getLocale() -> String {
        return Locale.current.identifier
    }

    // MARK: - Hashing

    /**
     * Generates SHA-256 hash of input string.
     *
     * @param input String to hash
     * @return Lowercase hexadecimal SHA-256 hash
     */
    private func sha256(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else {
            return ""
        }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Authorization Checks
    //
    // REMOVED (deliberately, do not reintroduce here): `canCollectIDFA()`,
    // `authorizedIDFA()` and `trackingAuthorizationStatus()`. All three read
    // `ATTrackingManager` / `ASIdentifierManager`, and their presence is exactly what App
    // Review's symbol scan looks for. Their replacements live in the optional `PaylisherATT`
    // module: `PaylisherATT.authorizedIDFA()` and `PaylisherATT.authorizationStatusName()`,
    // surfaced to the core SDK through `PaylisherIDFA`.
}

// MARK: - Import CommonCrypto for SHA-256

import CommonCrypto
