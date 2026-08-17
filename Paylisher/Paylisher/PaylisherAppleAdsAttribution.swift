//
//  PaylisherAppleAdsAttribution.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

#if os(iOS) && canImport(AdServices)
    import AdServices
#endif
#if os(iOS) || os(tvOS)
    import UIKit
#endif

/**
 * Apple Ads (Apple Search Ads) install attribution.
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * WHAT THIS IS
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * When a user installs the app after tapping an Apple Ads placement in the App Store, only
 * Apple knows the link between the two. Apple exposes it through the AdServices framework
 * (iOS 14.3+): the app asks for an opaque *attribution token*, a SERVER posts that token to
 * Apple's Attribution API, and Apple answers with the campaign / ad group / keyword / ad ids.
 * No IDFA is read, no ATT prompt is shown, no fingerprint is built. It is Apple's own,
 * privacy-preserving mechanism, and the only one Apple offers for Apple Ads.
 *
 * So the SDK's whole job here is small and deliberately dumb: get the token, send it to the
 * Paylisher campaign service, remember whether that is done. Everything that makes it an
 * attribution — the Apple round trip, retries while Apple's record is not ready, the tenant
 * mapping, naming, reporting — lives on the backend (`campaign/src/modules/apple-ads`).
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * WHEN IT RUNS
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * On every launch until the backend gives a *terminal* answer (attributed / organic /
 * invalid / expired / unsupported), then never again for this install. The token can be
 * requested at any time after install and always describes the same install, so re-sending
 * on a later launch is safe: the backend keys on the device, not the token, and answers from
 * its store without asking Apple twice. Requests stop after `maxAgeDays` even if the backend
 * never answered — a token that old is past Apple's validity anyway.
 *
 * Nothing here blocks the launch, throws into the host, or shows anything to the user.
 */
public final class PaylisherAppleAdsAttribution {
    public static let shared = PaylisherAppleAdsAttribution()

    /// Event captured when the backend confirms an Apple Ads install.
    public static let attributedEventName = "Apple Ads Attribution"

    // MARK: - Persisted state

    struct State: Codable {
        /// The backend's last answer for this install. `nil` = never answered.
        var status: String?
        /// First time this install tried, for `maxAgeDays`.
        var firstAttemptAt: TimeInterval?
        var lastAttemptAt: TimeInterval?
        var attempts: Int = 0
        /// Set once the analytics event has been captured, so it is captured exactly once.
        var eventCaptured: Bool = false
        /// Backend-suggested minimum wait before the next send (seconds).
        var retryAfter: TimeInterval?

        var isTerminal: Bool {
            guard let status else { return false }
            return ["attributed", "organic", "invalid", "expired", "unsupported"].contains(status)
        }
    }

    // MARK: - Configuration

    private var apiKey: String?
    private var host: String?
    private var storage: PaylisherStorage?
    private var enabled = false
    private var maxAgeDays: Int = 30
    private var isOptedOut: () -> Bool = { false }

    private let lock = NSLock()
    private var inFlight = false
    private let queue = DispatchQueue(label: "com.paylisher.appleads", qos: .utility)

    private init() {}

    /**
     * Wires the manager. Called by `PaylisherSDK.setup` when
     * `PaylisherConfig.appleAdsAttributionEnabled` is true (the default).
     *
     * `host` is the campaign service origin (same deployment as the deferred deep link API);
     * `PaylisherSKAdNetworkRemoteConfig.resolveHost` derives it so an on-prem customer that
     * overrode the deferred host is not silently posting tokens to the SaaS backend.
     */
    func configure(
        apiKey: String,
        host: String,
        storage: PaylisherStorage,
        maxAgeDays: Int,
        isOptedOut: @escaping () -> Bool
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.apiKey = apiKey
        self.host = host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.storage = storage
        self.maxAgeDays = max(1, maxAgeDays)
        self.isOptedOut = isOptedOut
        self.enabled = true
    }

    /// Drops references on `PaylisherSDK.close()`. State on disk is deliberately kept: it
    /// describes the INSTALL, not the session or the person.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        enabled = false
        apiKey = nil
        host = nil
        storage = nil
    }

    // MARK: - Entry point

    /**
     * Runs one attempt if one is due. Safe to call on every launch and more than once per
     * launch — it is idempotent per process and per install.
     */
    func runIfNeeded() {
        lock.lock()
        guard enabled, let apiKey, let host, let storage else {
            lock.unlock()
            return
        }
        if inFlight {
            lock.unlock()
            return
        }
        inFlight = true
        lock.unlock()

        queue.async { [weak self] in
            guard let self else { return }
            defer {
                self.lock.lock()
                self.inFlight = false
                self.lock.unlock()
            }
            self.attempt(apiKey: apiKey, host: host, storage: storage)
        }
    }

    // MARK: - One attempt

    private func attempt(apiKey: String, host: String, storage: PaylisherStorage) {
        var state = loadState(storage)

        if state.isTerminal {
            // Belt and braces: an `attributed` answer whose event failed to capture (for
            // example the queue was not up yet) gets its event on the next launch.
            return
        }
        if isOptedOut() {
            hedgeLog("[PaylisherAppleAds] opted out — attribution not sent")
            return
        }

        let now = Date().timeIntervalSince1970
        if let first = state.firstAttemptAt, now - first > Double(maxAgeDays) * 86_400 {
            hedgeLog("[PaylisherAppleAds] giving up after \(maxAgeDays) days without a terminal answer")
            state.status = "expired"
            saveState(state, storage)
            return
        }
        if let last = state.lastAttemptAt, let wait = state.retryAfter, now - last < wait {
            hedgeLog("[PaylisherAppleAds] backend asked to wait \(Int(wait))s — skipping this launch")
            return
        }
        // Never more than one send per 60 s from the same process, whatever the backend said.
        if let last = state.lastAttemptAt, now - last < 60 {
            return
        }

        state.firstAttemptAt = state.firstAttemptAt ?? now
        state.lastAttemptAt = now
        state.attempts += 1
        saveState(state, storage)

        let tokenResult = Self.fetchToken()

        var body: [String: Any] = [
            "bundle_id": Bundle.main.bundleIdentifier ?? "",
            "distinct_id": PaylisherSDK.shared.getDistinctId(),
            "anonymous_id": PaylisherSDK.shared.getAnonymousId(),
            "sdk_version": paylisherVersion,
            "os_version": Self.osVersion(),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            // NOTE: no install_type here on purpose. PaylisherInstallMarker.resolve() WRITES
            // the Keychain marker when absent, so calling it from this queue could stamp the
            // device before the SDK's own "Application Installed" classification runs and turn
            // a genuine first install into a "reinstall" there. The install event already
            // carries install_type; the backend field stays optional.
            "token_issued_at": Int64(now * 1000),
        ]
        #if os(iOS) || os(tvOS)
            if let idfv = Self.vendorId() {
                body["device_id"] = idfv
            }
        #endif

        switch tokenResult {
        case let .token(token):
            body["token"] = token
        case let .unsupported(reason):
            // Tell the backend so "no signal" is distinguishable from "no attribution".
            body["unsupported"] = true
            body["unsupported_reason"] = reason
        case let .failed(reason):
            // Transient (AdServices network / internal error). Do not burn the attempt as
            // terminal; try again next launch.
            hedgeLog("[PaylisherAppleAds] token unavailable: \(reason)")
            state.retryAfter = 300
            saveState(state, storage)
            return
        }

        send(body: body, apiKey: apiKey, host: host) { [weak self] outcome in
            guard let self else { return }
            var latest = self.loadState(storage)
            switch outcome {
            case let .answered(response):
                latest.status = response.status
                latest.retryAfter = response.retryAfterSeconds.map { TimeInterval($0) }
                if response.status == "attributed", !latest.eventCaptured {
                    self.captureAttributedEvent(response)
                    latest.eventCaptured = true
                }
                self.saveState(latest, storage)
                hedgeLog("[PaylisherAppleAds] backend answered: \(response.status)")
            case let .transient(reason):
                latest.retryAfter = 300
                self.saveState(latest, storage)
                hedgeLog("[PaylisherAppleAds] send failed: \(reason)")
            }
        }
    }

    // MARK: - Token

    enum TokenResult {
        case token(String)
        case unsupported(String)
        case failed(String)
    }

    /**
     * Asks AdServices for the attribution token. Synchronous; may take a few hundred ms and
     * MUST be called off the main thread (it is — see `runIfNeeded`).
     */
    static func fetchToken() -> TokenResult {
        #if os(iOS) && canImport(AdServices)
            #if targetEnvironment(simulator)
                return .unsupported("simulator")
            #else
                if #available(iOS 14.3, *) {
                    do {
                        let token = try AAAttribution.attributionToken()
                        return token.isEmpty ? .failed("empty token") : .token(token)
                    } catch {
                        // AAAttributionError.Code: networkError / internalError / platformNotSupported.
                        // Only the last is permanent; the other two are worth another launch.
                        if let aa = error as? AAAttributionError, aa.code == .platformNotSupported {
                            return .unsupported("platform not supported")
                        }
                        return .failed(error.localizedDescription)
                    }
                } else {
                    return .unsupported("iOS < 14.3")
                }
            #endif
        #else
            return .unsupported("AdServices unavailable")
        #endif
    }

    // MARK: - Network

    struct Response: Decodable {
        struct Attribution: Decodable {
            let attribution: Bool
            let orgId: String?
            let campaignId: String?
            let adGroupId: String?
            let keywordId: String?
            let adId: String?
            let conversionType: String?
            let claimType: String?
            let countryOrRegion: String?
            let clickDate: String?
        }

        struct Names: Decodable {
            let orgName: String?
            let campaignName: String?
            let adGroupName: String?
            let keywordText: String?
            let adName: String?
        }

        let status: String
        let attribution: Attribution?
        let names: Names?
        let retryAfterSeconds: Int?
        let claimed: Bool?
        let error: String?
    }

    enum SendOutcome {
        case answered(Response)
        case transient(String)
    }

    private func send(
        body: [String: Any],
        apiKey: String,
        host: String,
        completion: @escaping (SendOutcome) -> Void
    ) {
        guard let url = URL(string: "\(host)/v1/apple-ads/attribution") else {
            completion(.transient("bad host"))
            return
        }
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion(.transient("body encode failed"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("paylisher-ios/\(paylisherVersion)", forHTTPHeaderField: "X-SDK-Version")
        request.setValue("ios", forHTTPHeaderField: "X-Device-Platform")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.transient(error.localizedDescription))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.transient("no HTTP response"))
                return
            }
            guard (200 ... 299).contains(http.statusCode) else {
                // 4xx other than what the backend encodes in-band is a configuration problem
                // (wrong host, prefix); 5xx is transient. Both are retried next launch.
                completion(.transient("HTTP \(http.statusCode)"))
                return
            }
            guard let data else {
                completion(.transient("empty body"))
                return
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let parsed = try? decoder.decode(Response.self, from: data) else {
                completion(.transient("undecodable body"))
                return
            }
            if parsed.status == "rejected" {
                // Our own request was malformed. Nothing a retry fixes; treat as unsupported
                // so the install stops asking.
                completion(.answered(Response(
                    status: "unsupported",
                    attribution: nil,
                    names: nil,
                    retryAfterSeconds: nil,
                    claimed: parsed.claimed,
                    error: parsed.error
                )))
                return
            }
            completion(.answered(parsed))
        }.resume()
    }

    // MARK: - Analytics

    /**
     * Makes the attribution usable inside analytics: one event with the campaign hierarchy,
     * plus the same values as person properties (`$set`) so cohorts and funnels can be cut by
     * Apple Ads campaign / keyword without a join.
     */
    private func captureAttributedEvent(_ response: Response) {
        guard let a = response.attribution, a.attribution else { return }
        var props: [String: Any] = [
            "source": "apple_ads",
            "attribution_method": "adservices",
        ]
        var person: [String: Any] = ["apple_ads_attributed": true]

        func put(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            props[key] = value
            person["apple_ads_\(key)"] = value
        }
        put("org_id", a.orgId)
        put("campaign_id", a.campaignId)
        put("ad_group_id", a.adGroupId)
        put("keyword_id", a.keywordId)
        put("ad_id", a.adId)
        put("conversion_type", a.conversionType)
        put("claim_type", a.claimType)
        put("country_or_region", a.countryOrRegion)
        put("click_date", a.clickDate)
        put("campaign_name", response.names?.campaignName)
        put("ad_group_name", response.names?.adGroupName)
        put("keyword_text", response.names?.keywordText)
        put("ad_name", response.names?.adName)

        PaylisherSDK.shared.capture(
            Self.attributedEventName,
            properties: props,
            userProperties: person
        )
    }

    // MARK: - State I/O

    private func loadState(_ storage: PaylisherStorage) -> State {
        guard let json = storage.getString(forKey: .appleAdsAttributionState),
              let data = json.data(using: .utf8),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else {
            return State()
        }
        return state
    }

    private func saveState(_ state: State, _ storage: PaylisherStorage) {
        guard let data = try? JSONEncoder().encode(state),
              let json = String(data: data, encoding: .utf8)
        else {
            return
        }
        storage.setString(forKey: .appleAdsAttributionState, contents: json)
    }

    // MARK: - Helpers

    private static func osVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    #if os(iOS) || os(tvOS)
        private static func vendorId() -> String? {
            // identifierForVendor is not an advertising identifier and needs no ATT; the
            // backend stores only a hash of it, as the row key.
            var result: String?
            if Thread.isMainThread {
                result = UIDevice.current.identifierForVendor?.uuidString
            } else {
                DispatchQueue.main.sync {
                    result = UIDevice.current.identifierForVendor?.uuidString
                }
            }
            return result
        }
    #endif

    // MARK: - Test hooks

    /// Clears the persisted install state. Tests only.
    func resetForTesting() {
        lock.lock()
        let s = storage
        lock.unlock()
        s?.remove(key: .appleAdsAttributionState)
    }
}
