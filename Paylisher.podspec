Pod::Spec.new do |s|
  s.name             = 'Paylisher'
  s.version          = '1.9.0.1'
  s.summary          = 'Paylisher Analytics, Replay & Deep Link SDK'
  s.description      = <<-DESC
Paylisher is a comprehensive mobile SDK providing event tracking, session replay, secure data collection, and advanced deep linking capabilities including deferred deep links for install attribution.
  DESC

  s.homepage         = 'https://github.com/paylisher/PAYLISHER-SDK-IOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Paylisher' => 'info@paylisher.com' }
  s.source           = { :git => 'https://github.com/paylisher/PAYLISHER-SDK-IOS.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.static_framework = true

  # `pod 'Paylisher'` gives you Core only — no advertising-identifier code at all.
  s.default_subspec = 'Core'

  # ---------------------------------------------------------------------------
  # Core — the default. Contains NO AdSupport / AppTrackingTransparency symbols.
  # ---------------------------------------------------------------------------
  s.subspec 'Core' do |core|
    core.source_files = 'Paylisher/**/*.{swift,h,m}'
    # MUST stay excluded: the ATT add-on lives under the same source root, and letting it
    # compile into Core would put the AdSupport/AppTrackingTransparency symbols back into
    # every consumer's binary — exactly what App Review's ATT scan rejects (Guideline 2.5.1),
    # and something no runtime flag can undo.
    core.exclude_files = 'Paylisher/PaylisherATT/**/*'

    # The privacy manifest was previously shipped to NOBODY on this channel:
    # `source_files` globs only .swift/.h/.m, and there was no resources key, so CocoaPods
    # consumers received no PrivacyInfo.xcprivacy at all. A resource bundle is Apple's
    # supported way to ship one from a static framework.
    core.resource_bundles = {
      'Paylisher_Privacy' => ['Paylisher/Resources/PrivacyInfo.xcprivacy']
    }
  end

  # ---------------------------------------------------------------------------
  # ATT — OPTIONAL. `pod 'Paylisher/ATT'`
  #
  # Opt in only if your app genuinely wants the IDFA. Linking this subspec means:
  #   * your binary references AppTrackingTransparency, so your app MUST present the
  #     permission prompt (call PaylisherATT.requestAuthorization) or Apple rejects it
  #     under Guideline 2.1;
  #   * Info.plist MUST contain NSUserTrackingUsageDescription;
  #   * your App Store nutrition label must declare "Data Used to Track You" — this
  #     subspec ships its own manifest with NSPrivacyTracking=true.
  # Not linking it leaves your app with none of those obligations.
  # ---------------------------------------------------------------------------
  s.subspec 'ATT' do |att|
    att.dependency 'Paylisher/Core'
    att.source_files = 'Paylisher/PaylisherATT/**/*.swift'

    # AppTrackingTransparency.framework only exists from iOS 14. The pod's floor is 13.0, and
    # a HARD `-framework AppTrackingTransparency` against a 13.0 target risks a dyld
    # "Library not loaded" crash at launch on iOS 13 — the Swift-side `#if canImport` and
    # `if #available(iOS 14, *)` guards gate the calls, not the load command. Two belts:
    # raise this subspec's floor, and declare the framework weak.
    att.ios.deployment_target = '14.0'
    att.frameworks = 'AdSupport'
    att.weak_frameworks = 'AppTrackingTransparency'
    att.resource_bundles = {
      'PaylisherATT_Privacy' => ['Paylisher/PaylisherATT/Resources/PrivacyInfo.xcprivacy']
    }
  end

  # Eğer XCFramework kullanırsan burayı açacaksın:
  # s.vendored_frameworks = 'PaylisherFramework/PaylisherFramework.xcframework'

  # NOT: Paylisher SDK'sı Firebase'i KULLANMAZ. Push (FCM) token'ı tüketici uygulama
  # Firebase'den alıp setFCMToken(_:) ile düz String olarak verir. Bu yüzden Firebase
  # bağımlılığı YOK — push isteyen uygulama Firebase'i kendi entegre eder.
  # (Kanal tutarlılığı: XCFramework dağıtımı da Firebase içermiyor.)

  s.swift_versions = ['5.7', '5.8', '5.9']
  s.requires_arc = true

  # SSL public key pinning is compiled in by default. To produce a build with pinning fully
  # excluded (for example the pentest package), drop PAYLISHER_SSL_PINNING from this condition.
  # The decision is taken at COMPILE time and cannot be reversed at runtime.
  s.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) PAYLISHER_SSL_PINNING'
  }
end
