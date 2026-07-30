//
//  PaylisherSKAdNetworkSchema.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

/**
 * The conversion-value schema as the Paylisher dashboard defines it, decoded on the device.
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * WHY THIS IS FETCHED RATHER THAN COMPILED IN
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * A conversion schema is a marketing decision — which events matter, which revenue tiers to
 * split on — and it changes far more often than an app ships. Hardcoding it means every
 * change waits for App Review and then only reaches users who updated, so the fleet ends up
 * encoding several different meanings for the same integer at the same time. Serving it from
 * the backend means the app and the postback decoder read the SAME definition, always.
 *
 * The tradeoff is that the schema now arrives over the network, so everything here is built
 * to keep working when it does not: the last good copy is cached on disk, a failed fetch
 * changes nothing, and a host-supplied local rule set still takes precedence.
 */

// MARK: - Rule

/// One row of the schema: a condition and the value to report when it holds.
@objc(PaylisherSKAdNetworkSchemaRule)
public class PaylisherSKAdNetworkSchemaRule: NSObject, Codable {
    @objc public let label: String
    @objc public let fineValue: Int
    /// "none" | "low" | "medium" | "high" — kept as the wire string and mapped on use.
    @objc public let coarseValue: String
    @objc public let lockWindow: Bool

    /// conversion mode: the exact event name this rule matches.
    public let eventName: String?
    /// revenue / engagement mode: inclusive lower bound.
    public let min: Double?
    /// revenue / engagement mode: exclusive upper bound; nil means unbounded.
    public let max: Double?

    public init(
        label: String,
        fineValue: Int,
        coarseValue: String,
        lockWindow: Bool,
        eventName: String?,
        min: Double?,
        max: Double?
    ) {
        self.label = label
        self.fineValue = fineValue
        self.coarseValue = coarseValue
        self.lockWindow = lockWindow
        self.eventName = eventName
        self.min = min
        self.max = max
        super.init()
    }

    // Written out rather than synthesised for the same reason as the schema below: a rule
    // that is missing an optional field must decode to a usable rule, not fail and take the
    // whole rule ARRAY down with it — one malformed row would otherwise silently disable
    // conversion measurement for the entire app.
    private enum CodingKeys: String, CodingKey {
        case label, fineValue, coarseValue, lockWindow, eventName, min, max
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        fineValue = (try? c.decode(Int.self, forKey: .fineValue)) ?? 0
        coarseValue = (try? c.decode(String.self, forKey: .coarseValue)) ?? "none"
        lockWindow = (try? c.decode(Bool.self, forKey: .lockWindow)) ?? false
        eventName = try? c.decode(String.self, forKey: .eventName)
        min = try? c.decode(Double.self, forKey: .min)
        max = try? c.decode(Double.self, forKey: .max)
        super.init()
    }

    var coarse: PaylisherSKAdNetworkCoarseValue {
        switch coarseValue.lowercased() {
        case "low": return .low
        case "medium": return .medium
        case "high": return .high
        default: return .unset
        }
    }

    /// True when `value` falls in [min, max). An absent bound is treated as unbounded, which
    /// is what makes a top bucket of "50 and up" expressible without inventing a ceiling.
    func matchesRange(_ value: Double) -> Bool {
        if let min, value < min { return false }
        if let max, value >= max { return false }
        return min != nil || max != nil
    }
}

// MARK: - Schema

/// A whole schema version: the mode, its parameters, and the rules.
@objc(PaylisherSKAdNetworkSchema)
public class PaylisherSKAdNetworkSchema: NSObject, Codable {
    /// Monotonic version from the dashboard. Only used for logging — the device never has to
    /// reason about versions, because it always encodes with whatever it last fetched.
    @objc public let schemaVersion: Int

    /// "conversion" | "revenue" | "engagement".
    @objc public let mode: String

    /// Hours after install during which the value keeps being updated. 0 = never lock early;
    /// let Apple's own window expire.
    @objc public let measurementWindowHours: Int

    @objc public let currency: String

    /// revenue mode: only this event contributes revenue. nil = every event may.
    public let revenueEventName: String?
    /// revenue mode: which property carries the amount. Defaults to "revenue".
    public let revenueProperty: String?
    /// revenue mode: sum across events (true) or take the latest amount (false).
    public let accumulateRevenue: Bool?

    /// engagement mode: "sessions" | "days".
    public let engagementMetric: String?

    /// Rules, served highest-fine-value first so the first match is the highest that applies.
    public let rules: [PaylisherSKAdNetworkSchemaRule]

    public init(
        schemaVersion: Int,
        mode: String,
        measurementWindowHours: Int,
        currency: String,
        revenueEventName: String?,
        revenueProperty: String?,
        accumulateRevenue: Bool?,
        engagementMetric: String?,
        rules: [PaylisherSKAdNetworkSchemaRule]
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.measurementWindowHours = measurementWindowHours
        self.currency = currency
        self.revenueEventName = revenueEventName
        self.revenueProperty = revenueProperty
        self.accumulateRevenue = accumulateRevenue
        self.engagementMetric = engagementMetric
        self.rules = rules
        super.init()
    }

    // Defensive defaults on decode. A schema that is missing a field it should have had is a
    // backend bug, but crashing an app launch over it — or worse, throwing away a schema that
    // is 95% usable — is a strictly worse outcome than filling in the obvious default.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, mode, measurementWindowHours, currency
        case revenueEventName, revenueProperty, accumulateRevenue
        case engagementMetric, rules
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? 0
        mode = (try? c.decode(String.self, forKey: .mode)) ?? "conversion"
        measurementWindowHours = (try? c.decode(Int.self, forKey: .measurementWindowHours)) ?? 24
        currency = (try? c.decode(String.self, forKey: .currency)) ?? "USD"
        revenueEventName = try? c.decode(String.self, forKey: .revenueEventName)
        revenueProperty = try? c.decode(String.self, forKey: .revenueProperty)
        accumulateRevenue = try? c.decode(Bool.self, forKey: .accumulateRevenue)
        engagementMetric = try? c.decode(String.self, forKey: .engagementMetric)
        rules = (try? c.decode([PaylisherSKAdNetworkSchemaRule].self, forKey: .rules)) ?? []
        super.init()
    }

    /// Rules ordered highest fine value first. The backend already sorts them, but a cached
    /// copy from an older backend might not, and the ordering is load-bearing: the first match
    /// wins, and Apple only accepts an increase.
    var rulesHighestFirst: [PaylisherSKAdNetworkSchemaRule] {
        rules.sorted { $0.fineValue > $1.fineValue }
    }

    var isConversionMode: Bool { mode.lowercased() == "conversion" }
    var isRevenueMode: Bool { mode.lowercased() == "revenue" }
    var isEngagementMode: Bool { mode.lowercased() == "engagement" }
}

// MARK: - Response envelope

/// What `GET /v1/skan/config` returns.
///
/// `enabled: false` is the normal answer for an app that is simply not set up for
/// SKAdNetwork — not an error, and deliberately indistinguishable from "switched off", so the
/// SDK has one code path for both.
struct PaylisherSKAdNetworkConfigResponse: Decodable {
    let enabled: Bool
    let schema: PaylisherSKAdNetworkSchema?
}
