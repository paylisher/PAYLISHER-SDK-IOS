# PaylisherNotificationServiceExtension.podspec
#
# Lightweight, extension-safe helper for an iOS Notification Service Extension:
# per-device push language localization. Add this pod to your NSE target ONLY —
# it does NOT pull in the main Paylisher SDK (no UIKit / Replay), so it stays
# well under the NSE memory budget and uses no app-only APIs.
#
#   target 'NotificationService' do   # your NSE target
#     pod 'PaylisherNotificationServiceExtension'
#   end
#
Pod::Spec.new do |s|
  s.name             = 'PaylisherNotificationServiceExtension'

  # Single-source the version from the main podspec so both release in lockstep
  # (bump Paylisher.podspec once; this reads it). Literal is only a fallback.
  main_podspec       = File.expand_path('Paylisher.podspec', __dir__)
  s.version          = (File.exist?(main_podspec) &&
                        File.read(main_podspec, encoding: 'UTF-8')[/s\.version\s*=\s*['"]([^'"]+)['"]/, 1]) || '1.8.8'

  s.summary          = 'Paylisher NSE helper — per-device push language localization for iOS.'
  s.description      = <<-DESC
Extension-safe helper for an iOS Notification Service Extension. Localizes a
Paylisher push's title/body to the device's language from the multi-language
maps the backend ships on the FCM data channel (device language → campaign
defaultLang → first available). Multi-SDK safe: static helpers that touch only
Paylisher pushes (source == "Paylisher") and no-op on everything else, so a
single NSE can also serve other push providers.
  DESC

  s.homepage         = 'https://github.com/paylisher/PAYLISHER-SDK-IOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Paylisher' => 'info@paylisher.com' }
  s.source           = { :git => 'https://github.com/paylisher/PAYLISHER-SDK-IOS.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_versions   = ['5.7', '5.8', '5.9']
  s.requires_arc     = true
  s.static_framework = true

  s.source_files     = 'PaylisherNotificationServiceExtension/Sources/**/*.swift'

  # Mark the pod as safe to link into an app extension.
  s.pod_target_xcconfig = { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
end
