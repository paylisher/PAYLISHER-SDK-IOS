//
//  PaylisherDeeplinkResolvedModel.swift
//  Paylisher
//
//  Created by Paylisher SDK on 24.12.2025.
//

import Foundation

// MARK: - Mongo Wrappers
public struct PaylisherMongoOID: Codable {
    public let oid: String

    enum CodingKeys: String, CodingKey {
        case oid = "$oid"
    }
}

public struct PaylisherMongoDate: Codable {
    public let date: String

    enum CodingKeys: String, CodingKey {
        case date = "$date"
    }
}

// MARK: - JSONValue for Dynamic MetaData
/// MetaData içinde number/string/bool/object karışık geleceği için generic JSON value type
public enum PaylisherJSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: PaylisherJSONValue])
    case array([PaylisherJSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }

        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }

        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }

        if let object = try? container.decode([String: PaylisherJSONValue].self) {
            self = .object(object)
            return
        }

        if let array = try? container.decode([PaylisherJSONValue].self) {
            self = .array(array)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported JSON value type"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    /// Paylisher properties için Any'a dönüştür
    public func toAny() -> Any {
        switch self {
        case .string(let s):
            return s
        case .number(let n):
            return n
        case .bool(let b):
            return b
        case .object(let o):
            return o.mapValues { $0.toAny() }
        case .array(let a):
            return a.map { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
}

// MARK: - Resolved DeepLink Payload
/// Backend'den gelen campaign/deeplink bilgilerinin tam modeli
public struct PaylisherResolvedDeepLinkPayload: Codable {
    public let id: PaylisherMongoOID?
    public let teamId: String?
    public let projectId: String?
    public let sourceId: String?
    public let type: String?
    public let title: String?
    public let keyName: String?
    public let webUrl: String?
    public let iosUrl: String?
    public let androidUrl: String?
    public let huaweiUrl: String?
    public let fallbackUrl: String?
    public let scheme: String?
    public let iosUniversalUrl: String?
    public let webhookUrl: String?
    public let createdAt: PaylisherMongoDate?
    public let updatedAt: PaylisherMongoDate?
    public let v: Int?
    public let adId: PaylisherMongoOID?
    public let metaData: [String: PaylisherJSONValue]?
    public let jid: String? // ✅ Journey ID (campaign tracking için)

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case teamId, projectId, sourceId, type, title, keyName
        case webUrl, iosUrl, androidUrl, huaweiUrl, fallbackUrl, scheme, iosUniversalUrl, webhookUrl
        case createdAt, updatedAt
        case v = "__v"
        case adId
        case metaData
        case jid // ✅ Journey ID
    }

    /// Paylisher'a gönderilecek properties dictionary'sini oluşturur
    public func toPropertiesDictionary() -> [String: Any] {
        var props: [String: Any] = [:]

        // Tüm alanları ekle
        props["_id"] = id?.oid ?? ""
        props["teamId"] = teamId ?? ""
        props["projectId"] = projectId ?? ""
        props["sourceId"] = sourceId ?? ""
        props["type"] = type ?? ""
        props["title"] = title ?? ""
        props["keyName"] = keyName ?? ""
        props["webUrl"] = webUrl ?? ""
        props["iosUrl"] = iosUrl ?? ""
        props["androidUrl"] = androidUrl ?? ""
        props["huaweiUrl"] = huaweiUrl ?? ""
        props["fallbackUrl"] = fallbackUrl ?? ""
        props["scheme"] = scheme ?? ""
        props["iosUniversalUrl"] = iosUniversalUrl ?? ""
        props["webhookUrl"] = webhookUrl ?? ""
        props["createdAt"] = createdAt?.date ?? ""
        props["updatedAt"] = updatedAt?.date ?? ""
        props["__v"] = v ?? 0
        props["adId"] = adId?.oid ?? ""

        // ✅ Journey ID ekle (varsa)
        if let jid = jid {
            props["jid"] = jid
        }

        // MetaData'yı düzleştirerek ekle (nested structure yerine flat)
        if let meta = metaData {
            let metaDict = meta.mapValues { $0.toAny() }
            props["metaData"] = metaDict

            // MetaData içindeki her key'i ayrıca root seviyeye de ekle (kolay filtreleme için)
            for (key, value) in metaDict {
                props["meta_\(key)"] = value
            }
        } else {
            props["metaData"] = [String: Any]()
        }

        return props
    }
}
