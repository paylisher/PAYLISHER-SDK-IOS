//
//  PaylisherApi.swift
//  Paylisher
//
//  Created by Ben White on 06.02.23.
//

import Foundation

class PaylisherApi {
    private let config: PaylisherConfig

    // default is 60s but we do 10s
    private let defaultTimeout: TimeInterval = 10

    init(_ config: PaylisherConfig) {
        self.config = config
    }

    /// Render a response body for a log line without ever force-unwrapping it.
    /// An error response legitimately arrives with no body, and crashing while
    /// building a diagnostic message is the worst possible failure mode.
    static func describeBody(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
            return String(describing: json)
        }
        return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
    }

    func sessionConfig() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default

        config.httpAdditionalHeaders = [
            "Content-Type": "application/json; charset=utf-8",
            "User-Agent": "\(paylisherSdkName)/\(paylisherVersion)",
        ]

        return config
    }

    private func getURL(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = defaultTimeout
        return request
    }

    func batch(events: [PaylisherEvent], completion: @escaping (PaylisherBatchUploadInfo) -> Void) {
        guard let url = URL(string: "batch", relativeTo: config.host) else {
            hedgeLog("Malformed batch URL error.")
            return completion(PaylisherBatchUploadInfo(statusCode: nil, error: nil))
        }

        let config = sessionConfig()
        var headers = config.httpAdditionalHeaders ?? [:]
        headers["Accept-Encoding"] = "gzip"
        headers["Content-Encoding"] = "gzip"
        config.httpAdditionalHeaders = headers

        let request = getURL(url)

        let toSend: [String: Any] = [
            "api_key": self.config.apiKey,
            "batch": events.map { $0.toJSON() },
            "sent_at": toISO8601String(Date()),
        ]

        var data: Data?

        do {
            data = try JSONSerialization.data(withJSONObject: toSend)
        } catch {
            hedgeLog("Error parsing the batch body: \(error)")
            return completion(PaylisherBatchUploadInfo(statusCode: nil, error: error))
        }

        var gzippedPayload: Data?
        do {
            gzippedPayload = try data!.gzipped()
        } catch {
            hedgeLog("Error gzipping the batch body: \(error).")
            return completion(PaylisherBatchUploadInfo(statusCode: nil, error: error))
        }

        URLSession(configuration: config).uploadTask(with: request, from: gzippedPayload!) { data, response, error in
            if error != nil {
                hedgeLog("Error calling the batch API: \(String(describing: error)).")
                return completion(PaylisherBatchUploadInfo(statusCode: nil, error: error))
            }

            // Not every URLResponse is an HTTPURLResponse: a registered custom
            // URLProtocol (APM agents, pinning proxies, MDM inspection — all common
            // in enterprise apps) can hand back a plain URLResponse, and force-casting
            // it crashed the host app.
            guard let httpResponse = response as? HTTPURLResponse else {
                let errorMessage = "Batch API returned a non-HTTP response."
                hedgeLog(errorMessage)
                return completion(PaylisherBatchUploadInfo(
                    statusCode: nil,
                    error: InternalPaylisherError(description: errorMessage)
                ))
            }

            if !(200 ... 299 ~= httpResponse.statusCode) {
                let jsonBody = PaylisherApi.describeBody(data)
                let errorMessage = "Error sending events to batch API: status: \(httpResponse.statusCode), body: \(jsonBody)."
                hedgeLog(errorMessage)
            } else {
                hedgeLog("Events sent successfully.")
            }

            return completion(PaylisherBatchUploadInfo(statusCode: httpResponse.statusCode, error: error))
        }.resume()
    }

    func snapshot(events: [PaylisherEvent], completion: @escaping (PaylisherBatchUploadInfo) -> Void) {
        guard let url = URL(string: config.snapshotEndpoint, relativeTo: config.host) else {
            hedgeLog("Malformed snapshot URL error.")
            return completion(PaylisherBatchUploadInfo(statusCode: nil, error: nil))
        }

        for event in events {
            event.apiKey = self.config.apiKey
        }

        let config = sessionConfig()
        var headers = config.httpAdditionalHeaders ?? [:]
        headers["Accept-Encoding"] = "gzip"
        headers["Content-Encoding"] = "gzip"
        config.httpAdditionalHeaders = headers

        let request = getURL(url)

        let toSend = events.map { $0.toJSON() }

        var data: Data?

        do {
            data = try JSONSerialization.data(withJSONObject: toSend)
//            remove it only for debugging
//            if let newData = data {
//                let convertedString = String(data: newData, encoding: .utf8)
//                hedgeLog("snapshot body: \(convertedString ?? "")")
//            }
        } catch {
            hedgeLog("Error parsing the snapshot body: \(error)")
            return completion(PaylisherBatchUploadInfo(statusCode: nil, error: error))
        }

        var gzippedPayload: Data?
        do {
            gzippedPayload = try data!.gzipped()
        } catch {
            hedgeLog("Error gzipping the snapshot body: \(error).")
            return completion(PaylisherBatchUploadInfo(statusCode: nil, error: error))
        }

        URLSession(configuration: config).uploadTask(with: request, from: gzippedPayload!) { data, response, error in
            if error != nil {
                hedgeLog("Error calling the snapshot API: \(String(describing: error)).")
                return completion(PaylisherBatchUploadInfo(statusCode: nil, error: error))
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                let errorMessage = "Snapshot API returned a non-HTTP response."
                hedgeLog(errorMessage)
                return completion(PaylisherBatchUploadInfo(
                    statusCode: nil,
                    error: InternalPaylisherError(description: errorMessage)
                ))
            }

            if !(200 ... 299 ~= httpResponse.statusCode) {
                let jsonBody = PaylisherApi.describeBody(data)
                let errorMessage = "Error sending events to snapshot API: status: \(httpResponse.statusCode), body: \(jsonBody)."
                hedgeLog(errorMessage)
            } else {
                hedgeLog("Snapshots sent successfully.")
            }

            return completion(PaylisherBatchUploadInfo(statusCode: httpResponse.statusCode, error: error))
        }.resume()
    }

    func decide(
        distinctId: String,
        anonymousId: String,
        groups: [String: String],
        completion: @escaping ([String: Any]?, _ error: Error?) -> Void
    ) {
        var urlComps = URLComponents()
        urlComps.path = "/decide"
        urlComps.queryItems = [URLQueryItem(name: "v", value: "3")]

        guard let url = urlComps.url(relativeTo: config.host) else {
            hedgeLog("Malformed decide URL error.")
            return completion(nil, nil)
        }

        let config = sessionConfig()

        let request = getURL(url)

        let toSend: [String: Any] = [
            "api_key": self.config.apiKey,
            "distinct_id": distinctId,
            "$anon_distinct_id": anonymousId,
            "$groups": groups,
        ]

        var data: Data?

        do {
            data = try JSONSerialization.data(withJSONObject: toSend)
        } catch {
            hedgeLog("Error parsing the decide body: \(error)")
            return completion(nil, error)
        }

        URLSession(configuration: config).uploadTask(with: request, from: data!) { data, response, error in
            if error != nil {
                hedgeLog("Error calling the decide API: \(String(describing: error))")
                return completion(nil, error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                let errorMessage = "Decide API returned a non-HTTP response."
                hedgeLog(errorMessage)
                return completion(nil, InternalPaylisherError(description: errorMessage))
            }

            if !(200 ... 299 ~= httpResponse.statusCode) {
                let jsonBody = PaylisherApi.describeBody(data)
                let errorMessage = "Error calling decide API: status: \(httpResponse.statusCode), body: \(jsonBody)."
                hedgeLog(errorMessage)

                return completion(nil,
                                  InternalPaylisherError(description: errorMessage))
            } else {
                hedgeLog("Decide called successfully.")
            }

            // `data` here is URLSession's optional body. A force-unwrap traps and is
            // NOT caught by the surrounding do/catch, so a 200 with an empty body
            // crashed the host app.
            guard let data, !data.isEmpty else {
                let errorMessage = "Decide API returned an empty body."
                hedgeLog(errorMessage)
                return completion(nil, InternalPaylisherError(description: errorMessage))
            }

            do {
                let jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
                completion(jsonData, nil)
            } catch {
                hedgeLog("Error parsing the decide response: \(error)")
                completion(nil, error)
            }
        }.resume()
    }

    // MARK: - Heartbeat

    /// Send heartbeat acknowledgment to the backend.
    ///
    /// Uses a minimal JSON payload (no gzip) for fast round-trip.
    /// The endpoint path is configurable via `PaylisherConfig.heartbeatEndpoint`.
    ///
    /// - Parameters:
    ///   - distinctId: The current user's distinct ID
    ///   - deviceToken: The APNs device token (hex string), if available
    ///   - appState: Current application state (foreground/background/inactive)
    ///   - completion: Called with (success: Bool, error: Error?)
    func heartbeat(
        distinctId: String,
        deviceToken: String?,
        appState: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard let url = URL(string: config.heartbeatEndpoint, relativeTo: config.host) else {
            hedgeLog("Malformed heartbeat URL error.")
            return completion(false, nil)
        }

        let sessionConfiguration = sessionConfig()
        let request = getURL(url)

        var toSend: [String: Any] = [
            "api_key": self.config.apiKey,
            "distinct_id": distinctId,
            "timestamp": toISO8601String(Date()),
            "platform": "ios",
            "sdk_version": paylisherVersion,
            "app_state": appState,
        ]

        if let deviceToken = deviceToken {
            toSend["device_token"] = deviceToken
        }

        var data: Data?

        do {
            data = try JSONSerialization.data(withJSONObject: toSend)
        } catch {
            hedgeLog("Error parsing the heartbeat body: \(error)")
            return completion(false, error)
        }

        URLSession(configuration: sessionConfiguration).uploadTask(with: request, from: data!) { data, response, error in
            if let error = error {
                hedgeLog("Error calling the heartbeat API: \(error.localizedDescription)")
                return completion(false, error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                hedgeLog("Heartbeat: No HTTP response received.")
                return completion(false, nil)
            }

            if 200 ... 299 ~= httpResponse.statusCode {
                hedgeLog("Heartbeat ack sent successfully (HTTP \(httpResponse.statusCode)).")
                completion(true, nil)
            } else {
                let bodyString: String
                if let data = data {
                    bodyString = String(data: data, encoding: .utf8) ?? "unreadable"
                } else {
                    bodyString = "empty"
                }
                hedgeLog("Heartbeat API error: HTTP \(httpResponse.statusCode), body: \(bodyString)")
                completion(false, InternalPaylisherError(description: "Heartbeat failed with HTTP \(httpResponse.statusCode)"))
            }
        }.resume()
    }
}
