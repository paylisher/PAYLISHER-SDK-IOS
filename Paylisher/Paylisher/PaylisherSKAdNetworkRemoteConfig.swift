//
//  PaylisherSKAdNetworkRemoteConfig.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

/**
 * Fetches the app's SKAdNetwork conversion schema from the Paylisher backend and caches it.
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * FAILURE IS THE NORMAL CASE, NOT THE EXCEPTION
 * ─────────────────────────────────────────────────────────────────────────────────────────
 * This runs during app launch, on whatever network the user happens to have. So every path
 * through it is designed around not being able to reach the backend:
 *
 *   - the last good schema is cached on disk and applied SYNCHRONOUSLY before the fetch
 *     starts, so the first event of a cold launch is already encoded correctly;
 *   - a failed or malformed response changes nothing — the cache is never cleared on error,
 *     because "we could not ask" must never be mistaken for "the answer changed";
 *   - `enabled: false`, on the other hand, IS an answer, and clears the cache.
 *
 * Nothing here blocks the launch and nothing here throws into the host app.
 */
enum PaylisherSKAdNetworkRemoteConfig {
    /// Default backend host. Same deployment as the deferred deep link API — a customer
    /// running on-prem overrides both together, since a schema fetched from the SaaS backend
    /// would describe someone else's app.
    static let defaultHost = "https://link.paylisher.com"

    // MARK: - Cache

    /// Reads the cached schema. Nil when nothing has been fetched yet or the cache is corrupt.
    static func cachedSchema(storage: PaylisherStorage) -> PaylisherSKAdNetworkSchema? {
        guard let json = storage.getString(forKey: .skAdNetworkSchema),
              let data = json.data(using: .utf8)
        else {
            return nil
        }
        return decodeSchema(from: data)
    }

    static func cache(schema: PaylisherSKAdNetworkSchema, storage: PaylisherStorage) {
        guard let data = try? JSONEncoder().encode(schema),
              let json = String(data: data, encoding: .utf8)
        else {
            return
        }
        storage.setString(forKey: .skAdNetworkSchema, contents: json)
    }

    static func clearCache(storage: PaylisherStorage) {
        storage.remove(key: .skAdNetworkSchema)
    }

    // MARK: - Fetch

    /**
     * Pulls the active schema for this app.
     *
     * The app is identified by its bundle id, which the SDK reads from its own bundle rather
     * than asking the host to configure it — one fewer thing to get wrong, and it is exactly
     * the identifier the dashboard registers.
     *
     * `completion` is called with the schema on success, or nil on ANY failure including a
     * deliberate `enabled: false`. The two are distinguished by `disabled`, because they lead
     * to opposite cache actions.
     */
    static func fetch(
        host: String?,
        bundleId: String?,
        apiKey: String?,
        timeout: TimeInterval = 10,
        completion: @escaping (_ schema: PaylisherSKAdNetworkSchema?, _ disabled: Bool) -> Void
    ) {
        let base = (host?.isEmpty == false ? host! : defaultHost)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let bundle = bundleId ?? Bundle.main.bundleIdentifier ?? ""

        guard !bundle.isEmpty else {
            hedgeLog("[PaylisherSKAdNetwork] no bundle identifier — schema fetch skipped")
            completion(nil, false)
            return
        }

        guard var components = URLComponents(string: "\(base)/v1/skan/config") else {
            completion(nil, false)
            return
        }
        components.queryItems = [URLQueryItem(name: "bundle_id", value: bundle)]

        guard let url = components.url else {
            completion(nil, false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                hedgeLog("[PaylisherSKAdNetwork] schema fetch failed: \(error.localizedDescription)")
                completion(nil, false)
                return
            }

            if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                // A 403 means this app registered an api key and ours does not match. Worth
                // saying out loud: it is a configuration mistake that otherwise looks exactly
                // like a network problem and would be debugged for hours as one.
                hedgeLog("[PaylisherSKAdNetwork] schema fetch HTTP \(http.statusCode)")
                completion(nil, false)
                return
            }

            guard let data else {
                completion(nil, false)
                return
            }

            guard let envelope = try? JSONDecoder().decode(
                PaylisherSKAdNetworkConfigResponse.self,
                from: data
            ) else {
                hedgeLog("[PaylisherSKAdNetwork] schema response could not be decoded")
                completion(nil, false)
                return
            }

            if !envelope.enabled || envelope.schema == nil {
                completion(nil, true)
                return
            }

            completion(envelope.schema, false)
        }.resume()
    }

    // MARK: - Helpers

    /**
     * Works out which backend to ask.
     *
     * An explicit `configHost` wins. Otherwise the deployment is inferred from the deferred
     * deep link host, which points at the same campaign service — this matters because an
     * on-prem customer who overrode only that one would otherwise silently fetch a SaaS
     * schema describing a different operator's app. Only the ORIGIN is taken; the deferred
     * host carries a path (`/v1/deferred-deeplink`) that must not leak into this URL.
     */
    static func resolveHost(explicit: String?, deferredHost: String?) -> String {
        if let explicit, !explicit.isEmpty { return explicit }

        if let deferredHost, !deferredHost.isEmpty,
           let components = URLComponents(string: deferredHost),
           let scheme = components.scheme,
           let host = components.host
        {
            if let port = components.port {
                return "\(scheme)://\(host):\(port)"
            }
            return "\(scheme)://\(host)"
        }

        return defaultHost
    }

    private static func decodeSchema(from data: Data) -> PaylisherSKAdNetworkSchema? {
        try? JSONDecoder().decode(PaylisherSKAdNetworkSchema.self, from: data)
    }
}
