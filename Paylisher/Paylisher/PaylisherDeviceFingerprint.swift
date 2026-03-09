//
//  PaylisherDeviceFingerprint.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation
import UIKit
import AdSupport
import AppTrackingTransparency
import WebKit

/**
 * Generates a unique device fingerprint for deferred deep link attribution.
 *
 * The fingerprint combines multiple device identifiers to create a probabilistic match
 * between click and install events. This enables attribution even when the user
 * installs the app after clicking a deep link.
 *
 * Privacy Note:
 * - Fingerprint generation respects user privacy settings
 * - IDFA collection requires ATTrackingManager authorization (iOS 14.5+)
 * - All data is hashed before transmission
 * - Compliant with Apple's App Tracking Transparency framework
 *
 * Components used:
 * - IDFV (Identifier for Vendor) - persistent across app reinstalls
 * - IDFA (Identifier for Advertisers) - user-resettable, requires authorization
 * - Device model and name
 * - OS version
 * - Screen resolution
 * - Timezone
 * - Language/Locale
 * - Screen scale
 */
internal class PaylisherDeviceFingerprint {

    /**
     * Generates a deferred deep link fingerprint (V1) that matches backend click-time fingerprint.
     *
     * IMPORTANT: This fingerprint MUST match exactly what backend generates at click-time.
     * Backend cannot access IDFV/IDFA at click-time, so we use only publicly available device info.
     *
     * Algorithm (MUST match backend exactly):
     * 1. Device model (UIDevice.current.model) - e.g., "iPhone", "iPad"
     * 2. OS version (UIDevice.current.systemVersion) - e.g., "17.2"
     * 3. Screen width (orientation-safe physical pixels) - e.g., "1170" (min(widthPx, heightPx))
     * 4. Timezone (TimeZone.current.identifier) - e.g., "Europe/Istanbul"
     * 5. Language code (Locale.current.languageCode) - e.g., "tr" (NOT "tr_TR")
     *
     * Components are joined with "|" separator, then SHA-256 hashed to lowercase hex.
     *
     * Example raw string: "iPhone|17.2|1170|Europe/Istanbul|tr"
     * Example hash: "a1b2c3d4e5f6789abcdef123456789abcdef123456789abcdef123456789abcd"
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
        print("📱 [1/5] Device Model: \(deviceModel)")

        // 2. OS version (e.g., "17.2")
        let osVersion = UIDevice.current.systemVersion
        components.append(osVersion)
        print("💿 [2/5] OS Version: \(osVersion)")

        // 3. Screen width (orientation-safe, physical pixels)
        // Uses bounds * scale to match web bridge's screen.width * devicePixelRatio.
        // Height is excluded: browser screen.height * DPR differs from native heightPixels
        // by ~2px due to status bar / nav bar calculation differences.
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        let widthPx = Int(bounds.width * scale)
        let heightPx = Int(bounds.height * scale)
        print("📐 [3/5] Screen Raw Dimensions: widthPt=\(bounds.width), heightPt=\(bounds.height), scale=\(scale)")

        // Normalize: always use min(widthPx, heightPx) to handle orientation changes
        let screenWidth = String(min(widthPx, heightPx))
        components.append(screenWidth)
        print("📐 [3/5] Screen Width (orientation-safe): \(screenWidth)")

        // 4. Timezone identifier (e.g., "Europe/Istanbul")
        let timezone = TimeZone.current.identifier
        components.append(timezone)
        print("🌍 [4/5] Timezone: \(timezone)")

        // 5. Language code only (e.g., "tr", NOT "tr_TR")
        let languageCode = Locale.current.languageCode ?? "en"
        components.append(languageCode)
        print("🗣️ [5/5] Language Code: \(languageCode)")

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

    /**
     * Generates a SHA-256 hash of combined device identifiers.
     *
     * This method is async because IDFA retrieval may require user authorization prompt.
     *
     * NOTE: This rich fingerprint is NOT used for deferred deep link matching.
     * Use generateDeferredFingerprintV1() for deferred deep link attribution.
     *
     * @param includeIDFA Whether to include IDFA (requires ATT authorization)
     * @return SHA-256 hash of device fingerprint, or nil if generation fails
     */
    func generate(includeIDFA: Bool = true) async -> String? {
        var components: [String] = []

        // 1. IDFV (Identifier for Vendor) - persistent identifier
        if let idfv = getIDFV() {
            components.append(idfv)
        }

        // 2. IDFA (Identifier for Advertisers) - user-resettable, requires authorization
        if includeIDFA {
            if let idfa = await getIDFA() {
                components.append(idfa)
            }
        }

        // 3. Device hardware info
        components.append(getDeviceModel())
        components.append(getDeviceName())

        // 4. OS version
        components.append(getOSVersion())

        // 5. Screen resolution
        if let screenResolution = getScreenResolution() {
            components.append(screenResolution)
        }

        // 6. Timezone
        components.append(getTimezone())

        // 7. Language/Locale
        components.append(getLocale())

        // 8. Screen scale
        components.append(getScreenScale())

        // Generate SHA-256 hash
        guard !components.isEmpty else {
            return nil
        }

        let combined = components.joined(separator: "|")
        return sha256(combined)
    }

    // MARK: - Device Identifiers

    /**
     * Gets IDFV (Identifier for Vendor).
     *
     * This ID is:
     * - Unique per vendor (apps from same developer share same IDFV)
     * - Persistent across app reinstalls
     * - Changes if all apps from vendor are uninstalled
     * - Does not require user authorization
     *
     * @return IDFV string or nil if unavailable
     */
    private func getIDFV() -> String? {
        return UIDevice.current.identifierForVendor?.uuidString
    }

    /**
     * Gets IDFA (Identifier for Advertisers) asynchronously.
     *
     * This ID is:
     * - User-resettable via device settings
     * - Shared across all apps
     * - Requires ATTrackingManager authorization (iOS 14.5+)
     * - Returns zeros if user has not granted tracking permission
     *
     * Important:
     * - This method is async and may show authorization prompt
     * - Returns nil if user has not granted tracking permission
     * - Must add NSUserTrackingUsageDescription to Info.plist
     *
     * @return IDFA string or nil if unavailable or user opted out
     */
    private func getIDFA() async -> String? {
        // Request tracking authorization (iOS 14.5+)
        if #available(iOS 14.5, *) {
            let status = await ATTrackingManager.requestTrackingAuthorization()

            guard status == .authorized else {
                return nil
            }
        }

        // Get IDFA
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString

        // Check if it's the zero UUID (user opted out or restricted)
        let zeroUUID = "00000000-0000-0000-0000-000000000000"
        guard idfa != zeroUUID else {
            return nil
        }

        return idfa
    }

    // MARK: - Device Information

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

    /**
     * Checks if IDFA tracking is authorized.
     *
     * This should be called before including IDFA in fingerprint to ensure
     * compliance with Apple's App Tracking Transparency framework.
     *
     * @return true if IDFA can be collected, false otherwise
     */
    static func canCollectIDFA() -> Bool {
        if #available(iOS 14.5, *) {
            return ATTrackingManager.trackingAuthorizationStatus == .authorized
        }

        // Pre-iOS 14.5: Check if advertising tracking is enabled
        return ASIdentifierManager.shared().isAdvertisingTrackingEnabled
    }

    /**
     * Gets the current tracking authorization status.
     *
     * @return ATTrackingManager.AuthorizationStatus
     */
    @available(iOS 14.5, *)
    static func trackingAuthorizationStatus() -> ATTrackingManager.AuthorizationStatus {
        return ATTrackingManager.trackingAuthorizationStatus
    }
}

// MARK: - Import CommonCrypto for SHA-256

import CommonCrypto
