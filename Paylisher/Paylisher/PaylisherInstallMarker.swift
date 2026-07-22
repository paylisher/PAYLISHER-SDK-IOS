//
//  PaylisherInstallMarker.swift
//  Paylisher
//
//  Distinguishes a genuine first install from a reinstall.
//

import Foundation
import Security

/// A tiny, privacy-preserving "has this device seen this app before" marker.
///
/// It stores a FIXED, non-identifying value in the Keychain. The Keychain survives
/// an app uninstall, so on the next install we can tell a genuine first install
/// from a reinstall — WITHOUT storing any device identifier and without anything
/// ever leaving the device. That is the point: there is no personal data here,
/// only a single bit of local state, so it needs no consent and no server call.
///
/// `UserDefaults` cannot do this: it is wiped on uninstall, which is exactly why
/// "Application Installed" fires again on a reinstall in the first place.
enum PaylisherInstallMarker {
    enum InstallType: String {
        case first
        case reinstall
        /// The Keychain was unreadable (rare). Reported as-is rather than guessed,
        /// so the dashboard can keep these out of both buckets.
        case unknown
    }

    // Fixed across app installs AND across api-key rotations on purpose. Keying the
    // marker on the api key would reset every device when the key rotates, which
    // would look like a wave of brand-new "first" installs.
    private static let service = "com.paylisher.sdk.install-marker"
    private static let account = "device"

    /// Returns whether this launch is a first install or a reinstall, writing the
    /// marker on a first install so the next install reads `reinstall`.
    static func resolve() -> InstallType {
        switch markerState() {
        case .present:
            return .reinstall
        case .absent:
            // Adding it succeeds → genuine first install. A duplicate here means the
            // marker actually existed (a read that could not see it, e.g. a locked
            // Keychain) → treat as reinstall, not a fresh first.
            switch add() {
            case .added: return .first
            case .duplicate: return .reinstall
            case .failed: return .unknown
            }
        case .unknown:
            // Keychain was unreadable (locked before first unlock). Do not guess.
            return .unknown
        }
    }

    /// Seeds the marker for an EXISTING install that predates this feature, so its
    /// NEXT reinstall is correctly read as a reinstall rather than a first install.
    /// Must NOT run before install classification — see the call site guard.
    static func seedIfMissing() {
        if case .absent = markerState() {
            _ = add()
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private enum MarkerState { case present, absent, unknown }
    private enum AddResult { case added, duplicate, failed }

    private static func markerState() -> MarkerState {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        switch SecItemCopyMatching(query as CFDictionary, nil) {
        case errSecSuccess:
            return .present
        case errSecItemNotFound:
            return .absent
        default:
            // errSecInteractionNotAllowed etc. — the Keychain is there but we could
            // not read it (locked). "Not found" would be wrong; report unknown.
            return .unknown
        }
    }

    private static func add() -> AddResult {
        var query = baseQuery()
        query[kSecValueData as String] = Data("1".utf8)
        // AfterFirstUnlock: readable in the background on a normal launch.
        // ThisDeviceOnly: never restored onto a NEW device from a backup, so moving
        // to a new phone correctly reads as a first install, not a reinstall.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        switch SecItemAdd(query as CFDictionary, nil) {
        case errSecSuccess: return .added
        case errSecDuplicateItem: return .duplicate
        default: return .failed
        }
    }
}
