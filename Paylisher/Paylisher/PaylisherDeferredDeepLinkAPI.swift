//
//  PaylisherDeferredDeepLinkAPI.swift
//  Paylisher
//
//  Created by Paylisher SDK
//

import Foundation

/**
 * API client for checking deferred deep link attribution.
 *
 * This client communicates with the Paylisher backend to check if a device
 * has clicked a deep link before installing the app. This enables attribution
 * of install events to marketing campaigns.
 *
 * Flow:
 * 1. User clicks deep link (e.g., from email, social media)
 * 2. Backend stores click with device fingerprint
 * 3. User installs app
 * 4. On first launch, SDK checks for deferred deep link
 * 5. If match found, user is directed to deep link destination
 */
internal class PaylisherDeferredDeepLinkAPI {

    // MARK: - Properties

    private let apiKey: String
    private let sdkVersion: String
    private let deferredDeepLinkHost: String
    private let timeout: TimeInterval

    // MARK: - Constants

    private static let defaultDeferredDeepLinkHost = "https://link.paylisher.com/v1/deferred-deeplink"
    private static let defaultTimeout: TimeInterval = 10.0 // 10 seconds

    // MARK: - Initialization

    init(
        apiKey: String,
        sdkVersion: String,
        deferredDeepLinkHost: String? = nil,
        timeout: TimeInterval = defaultTimeout
    ) {
        self.apiKey = apiKey
        self.sdkVersion = sdkVersion
        self.deferredDeepLinkHost = deferredDeepLinkHost ?? Self.defaultDeferredDeepLinkHost
        self.timeout = timeout
    }

    // MARK: - API Methods

    /**
     * Checks for a deferred deep link match based on device fingerprint.
     *
     * This is an async method that performs a network request.
     *
     * @param fingerprint Device fingerprint (SHA-256 hash)
     * @return Deferred deep link response if successful
     * @throws PaylisherDeferredDeepLinkAPIError if API request fails
     */
    func check(fingerprint: String) async throws -> PaylisherDeferredDeepLinkResponse {
        // Build URL
        guard let url = buildDeferredDeepLinkURL(fingerprint: fingerprint) else {
            throw PaylisherDeferredDeepLinkAPIError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("paylisher-ios/\(sdkVersion)", forHTTPHeaderField: "X-SDK-Version")
        request.timeoutInterval = timeout

        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaylisherDeferredDeepLinkAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PaylisherDeferredDeepLinkAPIError.httpError(
                statusCode: httpResponse.statusCode,
                fingerprint: fingerprint
            )
        }

        // Parse JSON
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let deferredResponse = try decoder.decode(
                PaylisherDeferredDeepLinkResponse.self,
                from: data
            )
            return deferredResponse
        } catch {
            throw PaylisherDeferredDeepLinkAPIError.decodingError(error)
        }
    }

    // MARK: - URL Building

    /**
     * Builds the API URL for deferred deep link check.
     *
     * Format: https://link.paylisher.com/v1/deferred-deeplink?fingerprint={fingerprint}
     *
     * @param fingerprint Device fingerprint
     * @return Full API URL
     */
    private func buildDeferredDeepLinkURL(fingerprint: String) -> URL? {
        // Remove trailing slash if present
        var baseURL = deferredDeepLinkHost
        if baseURL.hasSuffix("/") {
            baseURL.removeLast()
        }

        // Build URL with query parameter
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "fingerprint", value: fingerprint)
        ]

        return components?.url
    }
}

// MARK: - Response Model

/**
 * Response from deferred deep link API.
 */
struct PaylisherDeferredDeepLinkResponse: Codable {
    /// Match status: "match" or "no_match"
    let status: String

    /// Deep link URL if match found
    let url: String?

    /// Campaign key if available
    let campaignKey: String?

    /// Journey ID from backend
    let jid: String?

    /// When the deep link was clicked (ISO 8601)
    let clickTimestamp: String?

    /// Attribution window in seconds
    let attributionWindow: Int64?

    /// Additional campaign metadata
    let metadata: [String: AnyCodable]?

    /**
     * Checks if this response indicates a successful match.
     */
    func isMatch() -> Bool {
        return status == "match"
    }

    /**
     * Gets a metadata value as a string.
     */
    func getMetadataString(key: String) -> String? {
        guard let metadata = metadata else { return nil }
        return metadata[key]?.stringValue
    }
}

// MARK: - Error Types

/**
 * Error thrown when deferred deep link API request fails.
 */
enum PaylisherDeferredDeepLinkAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, fingerprint: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to build deferred deep link URL"
        case .invalidResponse:
            return "Invalid response from deferred deep link API"
        case .httpError(let statusCode, let fingerprint):
            return "HTTP error \(statusCode) for fingerprint \(fingerprint.prefix(16))..."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - AnyCodable Helper

/**
 * Helper type for decoding dynamic JSON values in metadata.
 */
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        return value as? String
    }

    var intValue: Int? {
        return value as? Int
    }

    var doubleValue: Double? {
        return value as? Double
    }

    var boolValue: Bool? {
        return value as? Bool
    }
}
