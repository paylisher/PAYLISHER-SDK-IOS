//
//  PaylisherCertificatePinning.swift
//  Paylisher
//
//  SSL public key (SPKI) pinning for the SDK network layer.
//

import CryptoKit
import Foundation

/// `URLSessionDelegate` that enforces public key pinning against `PaylisherConfig.certificatePins`.
///
/// The initializer returns nil when no pin is configured, which lets the caller create plain
/// sessions exactly as before. Pinning is therefore strictly opt in and an integration that does
/// not set `certificatePins` is not affected at all.
///
/// What is compared is the SubjectPublicKeyInfo (the public key) and not the whole certificate, so
/// a certificate renewal that reuses the same key keeps matching. That is what makes short lived
/// certificates safe to use together with pinning.
final class PaylisherCertificatePinner: NSObject, URLSessionDelegate {
    private static let sha256Prefix = "sha256/"
    private static let sha1Prefix = "sha1/"

    /// Only this host is pinned. Every other host keeps the default system validation.
    private let pinnedHost: String?
    private let pins: Set<String>

    init?(config: PaylisherConfig) {
        let normalized = Set(PaylisherCertificatePinner.normalize(config.certificatePins))
        pins = normalized
        pinnedHost = config.host.host
        super.init()

        if normalized.isEmpty {
            return nil
        }
        if pinnedHost == nil {
            hedgeLog("Certificate pinning is skipped, no hostname could be read from the configured host.")
            return nil
        }
        if normalized.count == 1 {
            hedgeLog("Certificate pinning is active with a single pin. Configure a backup pin as well, otherwise rotating the server key locks installed apps out.")
        } else {
            hedgeLog("Certificate pinning is active with \(normalized.count) pins.")
        }
    }

    func urlSession(
        _: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Pin only the configured host. Redirects or unrelated hosts keep default handling so the
        // SDK never breaks traffic it was not asked to pin.
        if let pinnedHost, challenge.protectionSpace.host != pinnedHost {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Step 1, the normal chain validation. Pinning is an additional check on top of it, never
        // a replacement, otherwise an expired or wrongly named certificate would be accepted.
        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            hedgeLog("Certificate pinning refused \(challenge.protectionSpace.host), trust evaluation failed: \(String(describing: trustError)).")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Step 2, compare the server public key with the configured pins.
        guard let publicKey = PaylisherCertificatePinner.serverPublicKey(serverTrust),
              let spki = PaylisherCertificatePinner.subjectPublicKeyInfo(publicKey)
        else {
            hedgeLog("Certificate pinning refused \(challenge.protectionSpace.host), the server public key could not be read.")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let digest = PaylisherCertificatePinner.sha256Prefix + Data(SHA256.hash(data: spki)).base64EncodedString()

        if pins.contains(digest) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            hedgeLog("Certificate pinning refused \(challenge.protectionSpace.host), \(digest) is not in the configured pin list.")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    // MARK: - Helpers

    /// Accepts a bare base64 digest as SHA-256 so a pin copied straight out of openssl works.
    /// SHA-1 pins are rejected on purpose, they are obsolete and would silently never match.
    private static func normalize(_ raw: [String]) -> [String] {
        raw.compactMap { entry in
            let pin = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            if pin.isEmpty {
                return nil
            }
            if pin.hasPrefix(sha1Prefix) {
                hedgeLog("Certificate pinning is ignoring the SHA-1 pin '\(pin)', only SHA-256 is supported.")
                return nil
            }
            return pin.hasPrefix(sha256Prefix) ? pin : sha256Prefix + pin
        }
    }

    private static func serverPublicKey(_ trust: SecTrust) -> SecKey? {
        if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
            return SecTrustCopyKey(trust)
        }
        return SecTrustCopyPublicKey(trust)
    }

    /// `SecKeyCopyExternalRepresentation` yields the bare key, while a pin is computed over the
    /// full SubjectPublicKeyInfo structure. The matching ASN.1 header has to be prepended,
    /// otherwise the digest would never equal the one produced by openssl or by OkHttp.
    private static func subjectPublicKeyInfo(_ key: SecKey) -> Data? {
        guard let raw = SecKeyCopyExternalRepresentation(key, nil) as Data?,
              let header = asn1Header(for: key)
        else {
            return nil
        }
        return header + raw
    }

    private static func asn1Header(for key: SecKey) -> Data? {
        guard let attributes = SecKeyCopyAttributes(key) as? [CFString: Any],
              let keyType = attributes[kSecAttrKeyType] as? String,
              let keySize = attributes[kSecAttrKeySizeInBits] as? Int
        else {
            return nil
        }

        if keyType == (kSecAttrKeyTypeRSA as String) {
            switch keySize {
            case 2048: return Data(rsa2048Header)
            case 3072: return Data(rsa3072Header)
            case 4096: return Data(rsa4096Header)
            default:
                hedgeLog("Certificate pinning does not know the ASN.1 header for a \(keySize) bit RSA key.")
                return nil
            }
        }

        if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) {
            switch keySize {
            case 256: return Data(ecSecPrimeRandom256Header)
            case 384: return Data(ecSecPrimeRandom384Header)
            default:
                hedgeLog("Certificate pinning does not know the ASN.1 header for a \(keySize) bit EC key.")
                return nil
            }
        }

        hedgeLog("Certificate pinning does not support the key type \(keyType).")
        return nil
    }

    // Standard SubjectPublicKeyInfo prefixes, one per key type and size.
    private static let rsa2048Header: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86,
        0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0F, 0x00,
    ]

    private static let rsa3072Header: [UInt8] = [
        0x30, 0x82, 0x01, 0xA2, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86,
        0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x8F, 0x00,
    ]

    private static let rsa4096Header: [UInt8] = [
        0x30, 0x82, 0x02, 0x22, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86,
        0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0F, 0x00,
    ]

    private static let ecSecPrimeRandom256Header: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02,
        0x01, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03,
        0x42, 0x00,
    ]

    private static let ecSecPrimeRandom384Header: [UInt8] = [
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02,
        0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00,
    ]
}
