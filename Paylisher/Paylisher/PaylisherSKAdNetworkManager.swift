//
//  PaylisherSKAdNetworkManager.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

#if os(iOS)
    import StoreKit
#endif

/**
 * Drives Apple's SKAdNetwork from the advertised app's side: registers the install, then
 * reports a conversion value as the user does things worth measuring.
 *
 * Nothing here reads a device identifier and nothing here needs App Tracking Transparency.
 * SKAdNetwork is Apple's answer to attribution WITHOUT identifiers — the OS decides which ad
 * produced the install and later posts a signed result to the ad network.
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * API SELECTION — why there is no `registerAppForAdNetworkAttribution` here
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * `registerAppForAdNetworkAttribution()` (deprecated iOS 14.5) and `updateConversionValue(_:)`
 * (deprecated iOS 16.1) are deliberately not used. `updatePostbackConversionValue` both
 * registers the app for attribution and reports the value, so the modern call alone covers
 * everything, and avoiding the deprecated pair keeps the build free of deprecation warnings
 * that tend to turn into errors in strict host projects.
 *
 * The consequence is an explicit floor: SKAdNetwork support requires iOS 15.4+. On anything
 * older the manager logs once and does nothing. The SDK's own deployment target stays at
 * iOS 13 — every call site is `#available`-guarded — so this raises no minimum for anyone.
 *
 *   iOS 16.1+     updatePostbackConversionValue(_:coarseValue:lockWindow:completionHandler:)
 *   iOS 15.4-16.0 updatePostbackConversionValue(_:completionHandler:)   (fine value only)
 *   below 15.4    no-op
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * CONVERSION WINDOWS
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * Apple measures in three windows after install: 0-2 days, 2-7 days, 7-35 days. The 6-bit
 * FINE value only counts in the first window; the COARSE tier keeps counting in all three.
 * Within a window Apple accepts only an INCREASE, so this manager enforces monotonicity
 * itself rather than firing calls the OS would silently drop.
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * WHERE THE VALUE COMES FROM
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * Three sources, consulted in this order, first answer wins:
 *
 *   1. `conversionValueResolver` — the host's own closure.
 *   2. `rules` — the host's hardcoded event map.
 *   3. the schema fetched from the Paylisher dashboard.
 *
 * Local beats remote on purpose: a host that wrote code has said something deliberate, and a
 * remote config silently overriding it would be the worst kind of surprise. In practice most
 * apps configure nothing locally and run entirely on (3).
 */
@objc(PaylisherSKAdNetworkManager)
public class PaylisherSKAdNetworkManager: NSObject {
    // MARK: - Singleton

    @objc public static let shared = PaylisherSKAdNetworkManager()

    // MARK: - Windows

    private enum Window {
        static let first: TimeInterval = 2 * 24 * 60 * 60
        static let second: TimeInterval = 7 * 24 * 60 * 60
        static let third: TimeInterval = 35 * 24 * 60 * 60
    }

    /// Sentinel for "no fine value reported yet". Apple's range is 0...63, so -1 is safely
    /// outside it and lets a rule legitimately report 0.
    private static let unsetFineValue = -1

    // MARK: - Persisted state keys

    private enum StateKey {
        static let fine = "fine"
        static let coarse = "coarse"
        /// Which measurement window was locked, not merely "a lock happened".
        ///
        /// Apple's `lockWindow` ends the CURRENT conversion window early; windows 2
        /// and 3 still accept updates afterwards. A boolean therefore silences the
        /// rest of the install's lifetime — and because the default schema locks
        /// automatically once `measurementWindowHours` elapses, that is not an edge
        /// case: every install would go permanently quiet about 24h in, and the
        /// coarse value (the only signal windows 2 and 3 carry) would never be sent.
        static let lockedWindow = "lockedWindow"
        /// Legacy boolean from the first implementation; read for migration only.
        static let locked = "locked"
        static let installAt = "installAt"
        static let registered = "registered"
        /// Accumulated revenue for revenue mode.
        static let revenue = "revenue"
        /// Engagement counters and the de-duplication markers that make them countable.
        static let sessions = "sessions"
        static let lastSessionId = "lastSessionId"
        static let days = "days"
        static let lastDayKey = "lastDayKey"
        /// Schema version last used to encode, for diagnostics.
        static let schemaVersion = "schemaVersion"
    }

    // MARK: - Dependencies (set during SDK setup)

    private let lock = NSLock()
    private var config: PaylisherSKAdNetworkConfig?
    private var storage: PaylisherStorage?
    private var schema: PaylisherSKAdNetworkSchema?
    private var didLogUnsupportedOS = false

    // MARK: - Init

    override private init() {
        super.init()
    }

    // MARK: - Configuration

    /// Wires the manager to the SDK. Called from `PaylisherSDK.setup(_:)`; hosts never call it.
    ///
    /// The cached schema is applied here, synchronously, so the first event of a cold launch
    /// is already encoded correctly instead of being dropped while a network fetch is in
    /// flight. A fresh copy replaces it later via `applySchema(_:)`.
    func configure(config: PaylisherSKAdNetworkConfig, storage: PaylisherStorage) {
        lock.lock()
        self.config = config
        self.storage = storage
        didLogUnsupportedOS = false
        if config.useRemoteSchema {
            schema = PaylisherSKAdNetworkRemoteConfig.cachedSchema(storage: storage)
        } else {
            schema = nil
        }
        let cachedVersion = schema?.schemaVersion
        lock.unlock()

        let cachedDescription = cachedVersion == nil ? "none" : "v\(cachedVersion!)"
        log(
            config,
            "configured (local rules: \(config.rules.count), registerOnInstall: "
                + "\(config.registerOnInstall), cached schema: \(cachedDescription))"
        )
    }

    /// Installs a freshly fetched schema. Pass nil when the backend reports the feature off.
    func applySchema(_ newSchema: PaylisherSKAdNetworkSchema?) {
        lock.lock()
        schema = newSchema
        let config = self.config
        lock.unlock()

        guard let config else { return }
        if let newSchema {
            log(config, "schema v\(newSchema.schemaVersion) applied (mode: \(newSchema.mode), rules: \(newSchema.rules.count))")
        } else {
            log(config, "schema cleared — backend reports SKAdNetwork disabled for this app")
        }
    }

    /**
     * Drops the dependencies. Called from `PaylisherSDK.close()`, which nils out the storage
     * and replaces the config, so holding on to either would keep a dead object alive and
     * let a late event write through a storage the SDK no longer owns.
     */
    func reset() {
        lock.lock()
        config = nil
        storage = nil
        schema = nil
        didLogUnsupportedOS = false
        lock.unlock()
    }

    // MARK: - Install registration

    /**
     * Registers the install with Apple. Safe to call more than once — it runs at most once
     * per install, guarded by persisted state.
     *
     * Called from the first-install branch of the app lifecycle. Registration reports
     * conversion value 0, which is exactly how Apple expects an install with no value yet to
     * be recorded.
     */
    func registerInstallIfNeeded() {
        lock.lock()
        guard let config, config.enabled, config.registerOnInstall else {
            lock.unlock()
            return
        }
        guard let storage else {
            lock.unlock()
            return
        }

        var state = readState(storage)
        if state[StateKey.registered] as? Bool == true {
            lock.unlock()
            log(config, "install already registered, skipping")
            return
        }

        state[StateKey.registered] = true
        // Stamp the install time here rather than reusing the analytics install timestamp:
        // Apple's measurement windows are counted from the SKAdNetwork registration, and
        // conflating the two would drift the window boundaries.
        if state[StateKey.installAt] == nil {
            state[StateKey.installAt] = Date().timeIntervalSince1970
        }
        writeState(storage, state)
        lock.unlock()

        log(config, "registering install with SKAdNetwork (conversion value 0)")
        sendToApple(fineValue: 0, coarseValue: .unset, lockWindow: false, config: config)
    }

    // MARK: - Event hook

    /**
     * Evaluates one captured event and, when it maps to a higher value than the one already
     * reported, updates Apple.
     *
     * Called from `PaylisherQueue.add(_:)` — the single chokepoint every analytics event
     * passes through. `capture(_:)` is not that chokepoint: `$identify`, `$screen`,
     * `$create_alias` and `$groupidentify` enqueue directly and would be invisible here.
     *
     * Because the queue is only reached after `capture(_:)`'s opt-out check, an opted-out
     * user never produces a conversion update.
     */
    func handleEvent(_ event: PaylisherEvent) {
        lock.lock()
        guard let config, config.enabled, storage != nil else {
            lock.unlock()
            return
        }
        let schema = self.schema
        lock.unlock()

        // Counters advance on EVERY event, before any rule is consulted. A revenue total that
        // only moved when a rule happened to match would under-report the moment the buckets
        // are edited, and an engagement count is by definition about events that map to
        // nothing in particular.
        updateCounters(for: event, schema: schema)

        // Closing an expired measurement window is checked here rather than on a timer: the
        // app may not be running when the window elapses, and a background timer for this
        // would be both unreliable and a battery cost for no gain.
        closeMeasurementWindowIfElapsed(schema: schema)

        if let conversion = config.conversion(for: event.event, properties: event.properties) {
            apply(conversion, reason: event.event)
            return
        }

        guard let schema, let conversion = resolveFromSchema(schema, event: event) else {
            return
        }
        apply(conversion, reason: event.event, schemaVersion: schema.schemaVersion)
    }

    // MARK: - Schema evaluation

    /// Picks the rule that applies to this event under the schema's mode.
    private func resolveFromSchema(
        _ schema: PaylisherSKAdNetworkSchema,
        event: PaylisherEvent
    ) -> PaylisherSKAdNetworkConversion? {
        if schema.isConversionMode {
            // Highest-first, so when several rules name the same event the strongest wins.
            guard let rule = schema.rulesHighestFirst.first(where: { $0.eventName == event.event })
            else {
                return nil
            }
            return conversion(from: rule)
        }

        if schema.isRevenueMode {
            let total = currentRevenue()
            guard let rule = schema.rulesHighestFirst.first(where: { $0.matchesRange(total) })
            else {
                return nil
            }
            return conversion(from: rule)
        }

        if schema.isEngagementMode {
            let metric = (schema.engagementMetric ?? "sessions").lowercased()
            let value = metric == "days" ? Double(currentDays()) : Double(currentSessions())
            guard let rule = schema.rulesHighestFirst.first(where: { $0.matchesRange(value) })
            else {
                return nil
            }
            return conversion(from: rule)
        }

        return nil
    }

    private func conversion(from rule: PaylisherSKAdNetworkSchemaRule) -> PaylisherSKAdNetworkConversion {
        PaylisherSKAdNetworkConversion(
            fineValue: rule.fineValue,
            coarseValue: rule.coarse,
            lockWindow: rule.lockWindow
        )
    }

    // MARK: - Counters

    /// Advances revenue / session / day counters from one event.
    private func updateCounters(for event: PaylisherEvent, schema: PaylisherSKAdNetworkSchema?) {
        lock.lock()
        guard let storage else {
            lock.unlock()
            return
        }

        var state = readState(storage)
        var changed = false

        if let schema, schema.isRevenueMode {
            let property = schema.revenueProperty ?? "revenue"
            let eventMatches = schema.revenueEventName == nil || schema.revenueEventName == event.event
            if eventMatches, let amount = doubleValue(event.properties[property]) {
                let accumulate = schema.accumulateRevenue ?? true
                let previous = state[StateKey.revenue] as? Double ?? 0
                // A negative amount (a refund) is added when accumulating, because the bucket
                // is meant to describe what the user is worth NOW. It is not allowed to pull
                // the total below zero, which would make an "over $0" bucket stop matching and
                // look like the install never converted at all.
                let next = accumulate ? max(previous + amount, 0) : max(amount, 0)
                if next != previous {
                    state[StateKey.revenue] = next
                    changed = true
                }
            }
        }

        if let schema, schema.isEngagementMode {
            let metric = (schema.engagementMetric ?? "sessions").lowercased()

            if metric == "sessions" {
                // Sessions are counted by watching the session id change rather than by
                // listening for a session-start event, because not every app produces one and
                // the id is on every event regardless.
                if let sessionId = event.properties["$session_id"] as? String, !sessionId.isEmpty {
                    let last = state[StateKey.lastSessionId] as? String
                    if last != sessionId {
                        state[StateKey.lastSessionId] = sessionId
                        state[StateKey.sessions] = (state[StateKey.sessions] as? Int ?? 0) + 1
                        changed = true
                    }
                }
            } else if metric == "days" {
                // UTC day key. The alternative — the device's local calendar — makes the count
                // jump when the user travels or changes timezone, which would show up as
                // phantom engagement.
                let dayKey = Self.utcDayKey(for: event.timestamp)
                let last = state[StateKey.lastDayKey] as? String
                if last != dayKey {
                    state[StateKey.lastDayKey] = dayKey
                    state[StateKey.days] = (state[StateKey.days] as? Int ?? 0) + 1
                    changed = true
                }
            }
        }

        if changed {
            writeState(storage, state)
        }
        lock.unlock()
    }

    private func currentRevenue() -> Double {
        lock.lock()
        defer { lock.unlock() }
        guard let storage else { return 0 }
        return readState(storage)[StateKey.revenue] as? Double ?? 0
    }

    private func currentSessions() -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let storage else { return 0 }
        return readState(storage)[StateKey.sessions] as? Int ?? 0
    }

    private func currentDays() -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let storage else { return 0 }
        return readState(storage)[StateKey.days] as? Int ?? 0
    }

    // MARK: - Measurement window

    /**
     * Closes the first measurement window once the configured number of hours has passed.
     *
     * Why anyone would want this: Apple holds the postback until the window expires and then
     * adds up to 24h of random delay, so the default puts install data 2-3 days out of date.
     * Locking early trades late signal for fresher reporting, and the schema's
     * `measurementWindowHours` is where that tradeoff is expressed. 0 means "do not".
     */
    private func closeMeasurementWindowIfElapsed(schema: PaylisherSKAdNetworkSchema?) {
        guard let schema, schema.measurementWindowHours > 0 else { return }

        lock.lock()
        guard let config, let storage else {
            lock.unlock()
            return
        }

        var state = readState(storage)
        guard let installAt = state[StateKey.installAt] as? TimeInterval else {
            lock.unlock()
            return
        }
        guard let window = currentWindow(installAt: installAt) else {
            lock.unlock()
            return
        }
        // FIRST window only. `measurementWindowHours` is capped at 48 — the length of
        // Apple's own first window — so once that many hours have passed the condition
        // below is true forever. Without this guard the early close would fire again
        // the moment windows 2 and 3 opened, shutting each one before it could report
        // anything, which is the exact outcome the window-scoped lock exists to avoid.
        guard window == 1 else {
            lock.unlock()
            return
        }
        if lockedWindow(state) == window {
            lock.unlock()
            return
        }

        let elapsed = Date().timeIntervalSince1970 - installAt
        guard elapsed >= Double(schema.measurementWindowHours) * 3600 else {
            lock.unlock()
            return
        }

        state[StateKey.lockedWindow] = window
        writeState(storage, state)

        let fine = max(state[StateKey.fine] as? Int ?? Self.unsetFineValue, 0)
        let coarse = PaylisherSKAdNetworkCoarseValue(
            rawValue: state[StateKey.coarse] as? Int ?? 0
        ) ?? .unset
        lock.unlock()

        log(
            config,
            "measurement window of \(schema.measurementWindowHours)h elapsed — locking at "
                + "fine \(fine), coarse \(coarse.name)"
        )
        sendToApple(fineValue: fine, coarseValue: coarse, lockWindow: true, config: config)
    }

    // MARK: - Core update logic

    private func apply(
        _ conversion: PaylisherSKAdNetworkConversion,
        reason: String,
        schemaVersion: Int? = nil
    ) {
        lock.lock()

        guard let config, config.enabled, let storage else {
            lock.unlock()
            return
        }

        var state = readState(storage)

        let installAt = state[StateKey.installAt] as? TimeInterval
        guard let window = currentWindow(installAt: installAt) else {
            lock.unlock()
            log(config, "'\(reason)' ignored — outside every measurement window")
            return
        }

        // A lock belongs to the window it was issued in. Apple reopens measurement at
        // each window boundary, so treating the flag as permanent would throw away
        // windows 2 and 3 — which are the only ones that still carry the coarse value.
        if lockedWindow(state) == window {
            lock.unlock()
            log(config, "'\(reason)' ignored — window \(window) already locked")
            return
        }

        let storedFine = state[StateKey.fine] as? Int ?? Self.unsetFineValue
        let storedCoarseRaw = state[StateKey.coarse] as? Int ?? PaylisherSKAdNetworkCoarseValue.unset.rawValue

        var newFine = storedFine
        var newCoarse = storedCoarseRaw
        var changed = false

        // The fine value only counts in window 1. Reporting it later is not merely useless —
        // Apple drops it, so pretending otherwise would corrupt our own monotonicity state.
        if window == 1, conversion.fineValue > storedFine {
            newFine = conversion.fineValue
            changed = true
        }

        // The coarse tier keeps counting in every window, and only ever upward.
        if conversion.coarseValue.rawValue > storedCoarseRaw {
            newCoarse = conversion.coarseValue.rawValue
            changed = true
        }

        guard changed else {
            lock.unlock()
            log(
                config,
                "'\(reason)' ignored — not an increase (window \(window), "
                    + "fine \(conversion.fineValue) vs \(storedFine), "
                    + "coarse \(conversion.coarseValue.name))"
            )
            return
        }

        state[StateKey.fine] = newFine
        state[StateKey.coarse] = newCoarse
        if let schemaVersion {
            state[StateKey.schemaVersion] = schemaVersion
        }
        if conversion.lockWindow {
            state[StateKey.lockedWindow] = window
        }
        if state[StateKey.installAt] == nil {
            state[StateKey.installAt] = Date().timeIntervalSince1970
        }
        // Persisted BEFORE the call, on purpose. `PaylisherQueue.add` runs synchronously on
        // whatever thread captured the event, so two events can arrive together; committing
        // the new high-water mark inside the lock is what stops both from computing off the
        // same stale value and double-reporting. If Apple then rejects the call the value is
        // simply re-reported by the next qualifying event, since Apple ignores anything that
        // is not an increase anyway.
        writeState(storage, state)

        let effectiveFine = max(newFine, 0)
        let effectiveCoarse = PaylisherSKAdNetworkCoarseValue(rawValue: newCoarse) ?? .unset
        let shouldLock = conversion.lockWindow
        lock.unlock()

        log(
            config,
            "'\(reason)' -> window \(window), fine \(effectiveFine), "
                + "coarse \(effectiveCoarse.name), lock \(shouldLock)"
        )
        sendToApple(
            fineValue: effectiveFine,
            coarseValue: effectiveCoarse,
            lockWindow: shouldLock,
            config: config
        )
    }

    // MARK: - Apple bridge

    private func sendToApple(
        fineValue: Int,
        coarseValue: PaylisherSKAdNetworkCoarseValue,
        lockWindow: Bool,
        config: PaylisherSKAdNetworkConfig
    ) {
        #if os(iOS)
            if #available(iOS 16.1, *) {
                SKAdNetwork.updatePostbackConversionValue(
                    fineValue,
                    coarseValue: Self.appleCoarseValue(coarseValue),
                    lockWindow: lockWindow
                ) { error in
                    if let error {
                        hedgeLog("[PaylisherSKAdNetwork] updatePostbackConversionValue failed: \(error.localizedDescription)")
                    } else {
                        self.log(config, "Apple accepted fine \(fineValue) / coarse \(coarseValue.name)")
                    }
                }
                return
            }

            if #available(iOS 15.4, *) {
                // No coarse value and no lock window before 16.1 — SKAdNetwork 3.0 semantics.
                SKAdNetwork.updatePostbackConversionValue(fineValue) { error in
                    if let error {
                        hedgeLog("[PaylisherSKAdNetwork] updatePostbackConversionValue failed: \(error.localizedDescription)")
                    } else {
                        self.log(config, "Apple accepted fine \(fineValue) (pre-16.1, coarse/lock unsupported)")
                    }
                }
                return
            }

            logUnsupportedOSOnce(config)
        #else
            logUnsupportedOSOnce(config)
        #endif
    }

    #if os(iOS)
        @available(iOS 16.1, *)
        private static func appleCoarseValue(
            _ value: PaylisherSKAdNetworkCoarseValue
        ) -> SKAdNetwork.CoarseConversionValue {
            switch value {
            // SKAdNetwork has no "unset" tier; `.low` is Apple's neutral floor, and it is what
            // a postback carries when the app never sets a coarse value at all.
            case .unset, .low: return .low
            case .medium: return .medium
            case .high: return .high
            }
        }
    #endif

    // MARK: - Windows

    /// Current measurement window (1, 2 or 3), or `nil` once all of them have closed.
    private func currentWindow(installAt: TimeInterval?) -> Int? {
        guard let installAt else {
            // No registration timestamp yet: treat as the first window. This is the
            // conversion that arrives before `registerInstallIfNeeded()` has run, e.g. on an
            // app that was already installed when SKAdNetwork support was switched on.
            return 1
        }

        let elapsed = Date().timeIntervalSince1970 - installAt
        if elapsed < 0 {
            // Clock moved backwards. Be permissive rather than silently dropping values.
            return 1
        }
        if elapsed < Window.first { return 1 }
        if elapsed < Window.second { return 2 }
        if elapsed < Window.third { return 3 }
        return nil
    }

    /// Which window, if any, is currently locked.
    ///
    /// Migrates the original boolean on read: a device that upgraded mid-install has
    /// `locked = true` and no window number, and the only window it can have meant is
    /// the first one — that is the only window the old code could lock, because the
    /// auto-lock fires inside `measurementWindowHours` (at most 48h) and every explicit
    /// `lockWindow` rule fires off an event in window 1.
    private func lockedWindow(_ state: [AnyHashable: Any]) -> Int? {
        if let window = state[StateKey.lockedWindow] as? Int { return window }
        if state[StateKey.locked] as? Bool == true { return 1 }
        return nil
    }

    // MARK: - Persistence

    /// Reads the persisted state.
    ///
    /// Stored under its own `StorageKey` which is deliberately absent from
    /// `PaylisherStorage.reset()`: `reset()` runs on logout, and a logout must not resurrect
    /// a conversion window that Apple already considers spent.
    private func readState(_ storage: PaylisherStorage) -> [AnyHashable: Any] {
        storage.getDictionary(forKey: .skAdNetworkState) ?? [:]
    }

    private func writeState(_ storage: PaylisherStorage, _ state: [AnyHashable: Any]) {
        storage.setDictionary(forKey: .skAdNetworkState, contents: state)
    }

    // MARK: - Diagnostics

    /// Snapshot of the current SKAdNetwork state, for debugging and integration tests.
    @objc public func currentState() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        guard let storage else {
            return ["configured": false]
        }
        let state = readState(storage)
        let installAt = state[StateKey.installAt] as? TimeInterval
        return [
            "configured": true,
            "enabled": config?.enabled ?? false,
            "registered": state[StateKey.registered] as? Bool ?? false,
            "fineValue": state[StateKey.fine] as? Int ?? Self.unsetFineValue,
            "coarseValue": (PaylisherSKAdNetworkCoarseValue(
                rawValue: state[StateKey.coarse] as? Int ?? 0
            ) ?? .unset).name,
            // -1 = nothing locked. Bridged to NSDictionary, so no Optional here.
            "lockedWindow": lockedWindow(state) ?? -1,
            // -1 rather than nil: this dictionary is bridged to NSDictionary for ObjC callers,
            // where a wrapped Optional.none has no sane representation.
            "window": currentWindow(installAt: installAt) ?? -1,
            "mode": schema?.mode ?? "local",
            "schemaVersion": schema?.schemaVersion ?? -1,
            "revenue": state[StateKey.revenue] as? Double ?? 0,
            "sessions": state[StateKey.sessions] as? Int ?? 0,
            "activeDays": state[StateKey.days] as? Int ?? 0,
        ]
    }

    // MARK: - Helpers

    /// Accepts the shapes a revenue property realistically arrives in — a number, or a string
    /// straight out of a JSON payload or a price label the host forgot to parse.
    private func doubleValue(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    private static let utcDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func utcDayKey(for date: Date) -> String {
        utcDayFormatter.string(from: date)
    }

    // MARK: - Logging

    private func log(_ config: PaylisherSKAdNetworkConfig, _ message: String) {
        guard config.debugLogging else { return }
        hedgeLog("[PaylisherSKAdNetwork] \(message)")
    }

    private func logUnsupportedOSOnce(_ config: PaylisherSKAdNetworkConfig) {
        lock.lock()
        let alreadyLogged = didLogUnsupportedOS
        didLogUnsupportedOS = true
        lock.unlock()

        guard !alreadyLogged else { return }
        log(config, "SKAdNetwork requires iOS 15.4 or later — no conversion value reported on this device")
    }
}
