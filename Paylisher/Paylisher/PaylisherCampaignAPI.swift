//
//  PaylisherCampaignAPI.swift
//  Paylisher
//
//  Created by Paylisher SDK on 24.12.2025.
//

import Foundation

/// Backend campaign API ile iletişim için servis
public enum PaylisherCampaignAPI {

    /// Campaign keyName'e göre deeplink bilgilerini backend'den çeker
    /// - Parameters:
    ///   - keyName: Campaign key (örn: "nARvW" veya "X7kdi5Yq9lTVOv46uHYtV")
    ///   - shortLinkHost: Short link domain (örn: "link.usepublisher.com").
    ///     Verilirse o domain üzerinden /resolve/{key} çağrılır.
    ///     Verilmezse api.paylisher.com/campaign/resolve/{key} kullanılır.
    /// - Returns: Resolve edilmiş deeplink payload
    /// - Throws: Network veya decode hataları
    public static func resolve(keyName: String, shortLinkHost: String? = nil) async throws -> PaylisherResolvedDeepLinkPayload {
        // Short link domain varsa: https://<host>/resolve/<key>
        // Yoksa: https://api.paylisher.com/campaign/resolve/<key>
        let urlString: String
        if let host = shortLinkHost {
            urlString = "https://\(host)/resolve/\(keyName)"
        } else {
            urlString = "https://api.paylisher.com/campaign/resolve/\(keyName)"
        }

        guard let url = URL(string: urlString) else {
            throw PaylisherCampaignAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        // Network isteği
        let (data, response) = try await URLSession.shared.data(for: request)

        // HTTP status kontrolü
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw PaylisherCampaignAPIError.httpError(statusCode: httpResponse.statusCode)
            }
        }

        // JSON decode
        let decoder = JSONDecoder()
        do {
            let payload = try decoder.decode(PaylisherResolvedDeepLinkPayload.self, from: data)
            return payload
        } catch {
            throw PaylisherCampaignAPIError.decodingError(underlying: error)
        }
    }
}

// MARK: - Errors
public enum PaylisherCampaignAPIError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)
    case decodingError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid campaign URL"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
