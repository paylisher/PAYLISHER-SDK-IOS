//
//  PaylisherVersion.swift
//  Paylisher
//
//  Created by Manoel Aranda Neto on 13.10.23.
//

import Foundation

// TEK KAYNAK (single source of truth): SDK sürümü SADECE burada tutulur.
// Buradan beslenir: $lib_version, $sdk_package_version (PaylisherSDK.sdkVersion() bunu döndürür),
// User-Agent ve sdk_version header'ı. Sürümü elle değiştirme — `scripts/bump-version.sh <ver>` kullan;
// o hem bu satırı hem Paylisher.podspec'i günceller ve sonucu DOĞRULAR.
// This property is internal only
public var paylisherVersion = "1.8.7"

// This property is internal only
public var paylisherSdkName = "paylisher-ios"
