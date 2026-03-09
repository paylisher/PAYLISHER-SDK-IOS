Pod::Spec.new do |s|
  s.name             = 'Paylisher'
  s.version          = '1.7.1'
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
  s.source_files = 'Paylisher/**/*.{swift,h,m}'

  # Eğer XCFramework kullanırsan burayı açacaksın:
  # s.vendored_frameworks = 'PaylisherFramework/PaylisherFramework.xcframework'

  s.dependency 'FirebaseCore', '~> 11.0'
  s.dependency 'FirebaseAuth', '~> 11.0'
  s.dependency 'FirebaseDatabase', '~> 11.0'
  s.dependency 'FirebaseFirestore', '~> 11.0'
  s.dependency 'FirebaseAnalytics', '~> 11.0'

  s.swift_versions = ['5.7', '5.8', '5.9']
  s.requires_arc = true
end
