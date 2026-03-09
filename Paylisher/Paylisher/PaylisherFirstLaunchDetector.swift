//
//  PaylisherFirstLaunchDetector.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

/**
 * Detects first app launch for deferred deep link attribution.
 *
 * This class tracks whether the app has been launched before and stores
 * the install timestamp. This is crucial for deferred deep linking as we
 * only want to check for deferred deep links on the very first launch.
 *
 * Use Cases:
 * - Deferred deep link attribution (check only on first launch)
 * - Onboarding flow triggering
 * - Install-to-action time tracking
 *
 * Thread Safety:
 * - All methods are thread-safe
 * - Uses NSLock for synchronization
 *
 * Storage:
 * - Uses UserDefaults for persistence
 * - Survives app crashes and restarts
 */
internal class PaylisherFirstLaunchDetector {

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    // UserDefaults keys
    private let keyHasLaunched = "paylisher_first_launch_has_launched"
    private let keyInstallTimestamp = "paylisher_first_launch_install_timestamp"

    // MARK: - Constants

    /// Default attribution window: 24 hours (86400000 milliseconds)
    /// This is the industry standard attribution window for deferred deep links.
    /// If a user clicks a link and installs the app more than 24 hours later,
    /// the attribution is considered invalid.
    static let defaultAttributionWindowMillis: Int64 = 24 * 60 * 60 * 1000 // 24 hours

    /// Extended attribution window: 7 days (604800000 milliseconds)
    /// Some campaigns (e.g., email, retargeting) may benefit from a longer window.
    static let extendedAttributionWindowMillis: Int64 = 7 * 24 * 60 * 60 * 1000 // 7 days

    /// Short attribution window: 1 hour (3600000 milliseconds)
    /// For testing or high-intent campaigns where users install immediately.
    static let shortAttributionWindowMillis: Int64 = 60 * 60 * 1000 // 1 hour

    // MARK: - Singleton

    static let shared = PaylisherFirstLaunchDetector()

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - First Launch Detection

    /**
     * Checks if this is the first time the app has been launched.
     *
     * This method will return true ONLY ONCE per app installation.
     * On the first call, it will:
     * 1. Return true
     * 2. Mark the app as "launched"
     * 3. Store the current timestamp
     *
     * Subsequent calls will always return false.
     *
     * Thread-safe: Yes
     *
     * @return true if this is the first launch, false otherwise
     */
    func isFirstLaunch() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let hasLaunched = userDefaults.bool(forKey: keyHasLaunched)

        if !hasLaunched {
            // Mark as launched
            userDefaults.set(true, forKey: keyHasLaunched)
            userDefaults.set(Date().timeIntervalSince1970, forKey: keyInstallTimestamp)
            userDefaults.synchronize()

            return true
        }

        return false
    }

    /**
     * Checks if the app has been launched before (without modifying state).
     *
     * Unlike isFirstLaunch(), this method does NOT modify the launch state.
     * Use this for checking without side effects.
     *
     * @return true if app has been launched before, false if this would be first launch
     */
    func hasLaunchedBefore() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return userDefaults.bool(forKey: keyHasLaunched)
    }

    // MARK: - Install Timestamp

    /**
     * Gets the timestamp when the app was first installed/launched.
     *
     * @return Install timestamp as TimeInterval (seconds since 1970), or 0 if not set
     */
    func getInstallTimestamp() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }

        return userDefaults.double(forKey: keyInstallTimestamp)
    }

    /**
     * Manually sets the install timestamp.
     *
     * This is useful if you want to override the automatic timestamp
     * or restore it from a backup.
     *
     * @param timestamp Install timestamp as TimeInterval (seconds since 1970)
     */
    func setInstallTimestamp(_ timestamp: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.set(timestamp, forKey: keyInstallTimestamp)
        userDefaults.synchronize()
    }

    // MARK: - Time Calculations

    /**
     * Gets the time elapsed since installation in milliseconds.
     *
     * @return Time since install in milliseconds, or 0 if install timestamp not set
     */
    func getTimeSinceInstallMillis() -> Int64 {
        let installTimestamp = getInstallTimestamp()
        guard installTimestamp > 0 else {
            return 0
        }

        let currentTimestamp = Date().timeIntervalSince1970
        let elapsedSeconds = currentTimestamp - installTimestamp
        return Int64(elapsedSeconds * 1000) // Convert to milliseconds
    }

    /**
     * Gets the time elapsed since installation in hours.
     *
     * Useful for analytics and attribution window checks.
     *
     * @return Time since install in hours, or 0 if install timestamp not set
     */
    func getTimeSinceInstallHours() -> Int64 {
        let milliseconds = getTimeSinceInstallMillis()
        return milliseconds / (60 * 60 * 1000)
    }

    /**
     * Gets the time elapsed since installation in days.
     *
     * @return Time since install in days, or 0 if install timestamp not set
     */
    func getTimeSinceInstallDays() -> Int64 {
        let hours = getTimeSinceInstallHours()
        return hours / 24
    }

    // MARK: - Attribution Window

    /**
     * Checks if the install is within the given attribution window.
     *
     * This is used to determine if a deferred deep link attribution is still valid.
     * For example, if attribution window is 24 hours, a click that happened
     * 25 hours before install should not be attributed.
     *
     * @param attributionWindowMillis Attribution window in milliseconds
     * @return true if install is within window, false otherwise
     */
    func isWithinAttributionWindow(_ attributionWindowMillis: Int64) -> Bool {
        let timeSinceInstall = getTimeSinceInstallMillis()
        return timeSinceInstall > 0 && timeSinceInstall <= attributionWindowMillis
    }

    // MARK: - Reset (Testing Only)

    /**
     * Resets the first launch state.
     *
     * ⚠️ WARNING: This will make the next launch be treated as "first launch" again!
     *
     * Use Cases:
     * - Testing deferred deep link flow
     * - Debugging
     * - User explicitly requests data reset
     *
     * DO NOT use this in production code unless you have a specific reason!
     */
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.removeObject(forKey: keyHasLaunched)
        userDefaults.removeObject(forKey: keyInstallTimestamp)
        userDefaults.synchronize()
    }

    // MARK: - State Debugging

    /**
     * Gets all first launch state as a dictionary (for debugging/logging).
     *
     * @return Dictionary containing launch state data
     */
    func getState() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        return [
            "has_launched": hasLaunchedBefore(),
            "install_timestamp": getInstallTimestamp(),
            "time_since_install_hours": getTimeSinceInstallHours(),
            "time_since_install_days": getTimeSinceInstallDays()
        ]
    }
}
