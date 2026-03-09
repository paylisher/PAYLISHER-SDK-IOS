//
//  PaylisherJourneyContext.swift
//  Paylisher
//
//  Created by Journey Tracking Integration on 25.12.2025.
//

import Foundation

/// Journey source enum for attribution tracking
public enum PaylisherJourneySource {
    case deeplink
    case deferredDeeplink
    case campaignResolution
    case push
    case email
    case custom(String)

    var rawValue: String {
        switch self {
        case .deeplink:
            return "deeplink"
        case .deferredDeeplink:
            return "deferred_deeplink"
        case .campaignResolution:
            return "campaign_resolution"
        case .push:
            return "push"
        case .email:
            return "email"
        case .custom(let value):
            return value
        }
    }
}

/// Journey ID (jid) session manager - SDK Core Component
/// Manages jid lifecycle across app sessions with TTL support
class PaylisherJourneyContext {
    static let shared = PaylisherJourneyContext()

    // MARK: - Properties

    private var currentJourneyId: String?
    private let storage: PaylisherStorageProtocol
    private let journeyIdKey = "paylisher_journey_id"
    private let journeyIdTimestampKey = "paylisher_journey_id_timestamp"
    private let journeySourceKey = "paylisher_journey_source"

    // TTL: 7 days (journey active duration)
    private let journeyTTL: TimeInterval = 7 * 24 * 60 * 60

    // Lock for thread safety
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {
        // Use SDK's storage system
        self.storage = UserDefaultsStorage()
        loadJourneyId()
    }

    // MARK: - Private Methods

    /// Load journey ID from storage (crash recovery + persist across app restarts)
    private func loadJourneyId() {
        lock.lock()
        defer { lock.unlock() }

        guard let jid = storage.getString(forKey: journeyIdKey),
              let timestampDouble = storage.getDouble(forKey: journeyIdTimestampKey) else {
            hedgeLog("[JourneyContext] No saved jid")
            return
        }

        let timestamp = Date(timeIntervalSince1970: timestampDouble)

        // TTL check
        let elapsed = Date().timeIntervalSince(timestamp)
        if elapsed > journeyTTL {
            let daysElapsed = Int(elapsed / (24 * 60 * 60))
            hedgeLog("[JourneyContext] jid expired (TTL: 7 days, elapsed: \(daysElapsed) days)")
            clearJourneyId()
            return
        }

        currentJourneyId = jid
        let source = storage.getString(forKey: journeySourceKey) ?? "unknown"
        let hoursActive = Int(elapsed / 3600)
        hedgeLog("[JourneyContext] jid restored: \(jid) (source: \(source), active: \(hoursActive)h)")
    }

    // MARK: - Public Methods

    /// Set journey ID from deep link
    /// - Parameters:
    ///   - jid: Journey ID
    ///   - source: Attribution source (e.g., .deeplink, .deferredDeeplink, .push, .email)
    func setJourneyId(_ jid: String, source: PaylisherJourneySource = .deeplink) {
        lock.lock()
        defer { lock.unlock() }

        // Validate jid is not empty
        guard !jid.isEmpty else {
            hedgeLog("[JourneyContext] Attempted to set empty jid")
            return
        }

        // If jid is different, log the change
        if let currentJid = currentJourneyId, currentJid != jid {
            hedgeLog("[JourneyContext] jid changed: \(currentJid) → \(jid)")
        }

        currentJourneyId = jid
        let sourceValue = source.rawValue
        storage.setString(forKey: journeyIdKey, value: jid)
        storage.setDouble(forKey: journeyIdTimestampKey, value: Date().timeIntervalSince1970)
        storage.setString(forKey: journeySourceKey, value: sourceValue)

        hedgeLog("[JourneyContext] jid set: \(jid) (source: \(sourceValue))")
    }

    /// Get current journey ID
    /// - Returns: Active journey ID or nil
    func getJourneyId() -> String? {
        lock.lock()
        defer { lock.unlock() }

        return currentJourneyId
    }

    /// Get journey metadata (jid, source, age)
    /// - Returns: Dictionary with journey metadata
    func getJourneyMetadata() -> [String: Any]? {
        lock.lock()
        defer { lock.unlock() }

        guard let jid = currentJourneyId,
              let timestampDouble = storage.getDouble(forKey: journeyIdTimestampKey) else {
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: timestampDouble)
        let source = storage.getString(forKey: journeySourceKey) ?? "unknown"
        let ageSeconds = Int(Date().timeIntervalSince(timestamp))
        let ageHours = ageSeconds / 3600
        let ageDays = ageSeconds / (24 * 3600)

        return [
            "jid": jid,
            "source": source,
            "age_seconds": ageSeconds,
            "age_hours": ageHours,
            "age_days": ageDays,
            "started_at": ISO8601DateFormatter().string(from: timestamp)
        ]
    }

    /// Clear journey ID (logout, manual clear, or expiry)
    func clearJourneyId() {
        lock.lock()
        defer { lock.unlock() }

        if let jid = currentJourneyId {
            hedgeLog("[JourneyContext] jid cleared: \(jid)")
        }

        currentJourneyId = nil
        storage.remove(key: journeyIdKey)
        storage.remove(key: journeyIdTimestampKey)
        storage.remove(key: journeySourceKey)
    }

    /// Check if active journey exists
    var hasActiveJourney: Bool {
        lock.lock()
        defer { lock.unlock() }

        return currentJourneyId != nil
    }

    /// Get journey source (e.g., "deeplink", "push", "email")
    func getJourneySource() -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard currentJourneyId != nil else {
            return nil
        }

        return storage.getString(forKey: journeySourceKey)
    }

    /// Get journey age in hours
    func getJourneyAgeHours() -> Int? {
        lock.lock()
        defer { lock.unlock() }

        guard currentJourneyId != nil,
              let timestampDouble = storage.getDouble(forKey: journeyIdTimestampKey) else {
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: timestampDouble)
        let elapsed = Date().timeIntervalSince(timestamp)
        return Int(elapsed / 3600)
    }

    /// Check if journey is about to expire (within 24 hours)
    var isJourneyExpiringSoon: Bool {
        lock.lock()
        defer { lock.unlock() }

        guard currentJourneyId != nil,
              let timestampDouble = storage.getDouble(forKey: journeyIdTimestampKey) else {
            return false
        }

        let timestamp = Date(timeIntervalSince1970: timestampDouble)
        let elapsed = Date().timeIntervalSince(timestamp)
        let remaining = journeyTTL - elapsed
        return remaining < (24 * 60 * 60) && remaining > 0
    }
}

// MARK: - Storage Protocol

/// Simple storage protocol for journey data
private protocol PaylisherStorageProtocol {
    func getString(forKey key: String) -> String?
    func getDouble(forKey key: String) -> Double?
    func setString(forKey key: String, value: String)
    func setDouble(forKey key: String, value: Double)
    func remove(key: String)
}

/// UserDefaults-based storage implementation
private class UserDefaultsStorage: PaylisherStorageProtocol {
    private let userDefaults = UserDefaults.standard

    func getString(forKey key: String) -> String? {
        return userDefaults.string(forKey: key)
    }

    func getDouble(forKey key: String) -> Double? {
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }
        return userDefaults.double(forKey: key)
    }

    func setString(forKey key: String, value: String) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    func setDouble(forKey key: String, value: Double) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    func remove(key: String) {
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
    }
}
