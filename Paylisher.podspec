Pod::Spec.new do |s|
  s.name             = 'Paylisher'
  s.version          = '1.0.0'
  s.summary          = 'Paylisher Analytics & Replay SDK'
  s.description      = <<-DESC
Paylisher is a custom analytics and session replay SDK providing event tracking, screen analytics, and secure data collection for mobile apps.
  DESC

  s.homepage         = 'https://github.com/paylisher/PAYLISHER-SDK-IOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Paylisher' => 'info@paylisher.com' }
  s.source           = { :git => 'https://github.com/paylisher/PAYLISHER-SDK-IOS.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  
  s.source_files = 'PaylisherSDK/**/*.{swift,h,m}'

  # Eğer XCFramework kullanırsan burayı açacaksın:
  # s.vendored_frameworks = 'PaylisherFramework/PaylisherFramework.xcframework'

  s.dependency 'FirebaseCore'
  s.dependency 'FirebaseAuth'
  s.dependency 'FirebaseDatabase'
  s.dependency 'FirebaseFirestore'
  s.dependency 'FirebaseAnalytics'

  s.swift_versions = ['5.7', '5.8', '5.9']
  s.requires_arc = true
end
