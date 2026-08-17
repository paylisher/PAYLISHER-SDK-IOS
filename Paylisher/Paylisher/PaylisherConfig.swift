//
//  PaylisherConfig.swift
//  Paylisher
//
//  Created by Ben White on 07.02.23.
//
import Foundation
import UIKit

@objc(PaylisherConfig) public class PaylisherConfig: NSObject {
    @objc(PaylisherDataMode) public enum PaylisherDataMode: Int {
        case wifi
        case cellular
        case any
    }

    @objc public let host: URL
    @objc public let apiKey: String
    @objc public var flushAt: Int = 20
    @objc public var maxQueueSize: Int = 1000
    @objc public var maxBatchSize: Int = 50
    @objc public var flushIntervalSeconds: TimeInterval = 30
    @objc public var dataMode: PaylisherDataMode = .any
    @objc public var sendFeatureFlagEvent: Bool = true
    @objc public var preloadFeatureFlags: Bool = true
    @objc public var captureApplicationLifecycleEvents: Bool = true
    @objc public var captureScreenViews: Bool = true
    @objc public var debug: Bool = false
    @objc public var optOut: Bool = false
    @objc public var getAnonymousId: ((UUID) -> UUID) = { uuid in uuid }
    
    @objc public var windowScene: UIWindowScene? = nil
    
    /// Hook that allows to sanitize the event properties
    /// The hook is called before the event is cached or sent over the wire
    @objc public var propertiesSanitizer: PaylisherPropertiesSanitizer?
    /// Determines the behavior for processing user profiles.
    @objc public var personProfiles: PaylisherPersonProfiles = .identifiedOnly
    /// Controls what happens when `identify()` is called again with the same distinctId
    /// after the user is already identified on this device.
    /// Defaults to `.ignore` for backward compatibility.
    @objc public var repeatedIdentifyBehavior: PaylisherRepeatedIdentifyBehavior = .ignore

    /// The identifier of the App Group that should be used to store shared analytics data.
    /// Paylisher will try to get the physical location of the App Group’s shared container, otherwise fallback to the default location
    /// Default: nil
    @objc public var appGroupIdentifier: String?

    /// Internal
    /// Do not modify it, this flag is read and updated by the SDK via feature flags
    @objc public var snapshotEndpoint: String = "/s/"

    // MARK: - Heartbeat / Silent Push
    
    /// Enable silent push heartbeat for uninstall detection.
    /// When enabled, SDK will respond to silent heartbeat pushes with an alive signal.
    /// Default: true
    @objc public var enableHeartbeat: Bool = true
    
    /// Backend endpoint path for heartbeat acknowledgment.
    /// Default: "/heartbeat"
    @objc public var heartbeatEndpoint: String = "/heartbeat"
    
    /// Deferred Deep Link Configuration
    /// Enable this to track install attribution via deferred deep links
    /// Default: nil (disabled)
    public var deferredDeepLinkConfig: PaylisherDeferredDeepLinkConfig?

    /// Engage-served in-app message pull configuration.
    /// When set, SDK can fetch in-app campaigns directly from the Engage service without FCM delivery.
    public var engageInAppConfig: PaylisherEngageInAppConfig?

    /// Gelen Paylisher IN-APP push'larını SDK'nın kendisi yakalasın mı.
    ///
    /// Açıkken SDK, host uygulamanın `UIApplicationDelegate` sınıfına çalışma
    /// zamanında kancalanır ve sessiz push ile gelen in-app'i kendisi çizer —
    /// host'un `didReceiveRemoteNotification` yazmasına gerek kalmaz. Önceki
    /// implementasyon her hâlükârda çağrılır, yani Firebase'in ve host'un kendi
    /// işleyişi bozulmaz.
    ///
    /// Host ZATEN `customInAppFunction`'ı kendisi çağırıyorsa çift gösterimi
    /// önlemek için bunu kapatın.
    ///
    /// NOT: uygulamanın **Background Modes → Remote notifications** yetkisi
    /// kapalıysa iOS bu callback'i hiç çağırmaz; o yetki SDK'dan açılamaz.
    @objc public var autoHandleRemoteNotifications: Bool = true

    /// SKAdNetwork (Apple privacy-preserving install attribution) configuration.
    ///
    /// Default: nil — SKAdNetwork is OFF and no StoreKit call is ever made. Assign a
    /// `PaylisherSKAdNetworkConfig` to switch it on; set `enabled = false` on that object, or
    /// put this back to nil, to switch it off again.
    ///
    /// This reads no identifier and needs no ATT permission, so it is safe to enable in
    /// privacy-sensitive apps. See `PaylisherSKAdNetworkConfig` for what it does and does not
    /// deliver on its own.
    public var skAdNetworkConfig: PaylisherSKAdNetworkConfig?

    /// Apple Ads (Apple Search Ads) install attribution via the AdServices framework.
    ///
    /// Default: true. On the first launches after install the SDK asks AdServices for an
    /// attribution token (iOS 14.3+) and posts it to the Paylisher campaign service, which
    /// resolves it with Apple. Nothing is shown to the user, no identifier is read and no ATT
    /// prompt is involved — this is Apple's own privacy-preserving mechanism, and it is what
    /// makes Apple Ads installs appear as attributed installs in the dashboard. Set to false to
    /// never call AdServices.
    @objc public var appleAdsAttributionEnabled: Bool = true

    /// Campaign service origin the attribution token is posted to (e.g. "https://link.example.com").
    ///
    /// Default: nil — derived from `deferredDeepLinkConfig.deferredDeepLinkAPIHost` when set,
    /// otherwise the SaaS default. Only on-prem deployments need this.
    @objc public var appleAdsAttributionHost: String?

    /// How many days after install the SDK keeps re-sending the token when the backend has not
    /// given a final answer yet. Default 30.
    @objc public var appleAdsAttributionMaxAgeDays: Int = 30

    /// or EU Host: 'https://eu.i.paylisher.com'
    public static let defaultHost: String = "https://us.i.paylisher.com"

    #if os(iOS)
        /// Enable Recording of Session Replays for iOS
        /// Experimental support
        /// Default: false
        @objc public var sessionReplay: Bool = false
        /// Session Replay configuration
        /// Experimental support
        @objc public let sessionReplayConfig: PaylisherSessionReplayConfig = .init()
    #endif

    /// SSL public key (SPKI) pinning for the connection to `host`.
    ///
    /// When this array is empty (the default) the SDK behaves exactly as before and validates the
    /// server against the system trust store only. When it is filled, the server certificate must
    /// additionally carry a public key whose SHA-256 hash matches one of these pins, otherwise the
    /// connection is refused. That blocks man-in-the-middle interception even when a foreign CA is
    /// installed in the device trust store.
    ///
    /// Each entry is the base64 encoded SHA-256 hash of the server SubjectPublicKeyInfo, for
    /// example "sha256/+uSln0BfQmiK4sXbgI/fK/o8xCAaDJDKTET7SdYg+qM=". A bare base64 value without
    /// the "sha256/" prefix is accepted as well and treated as SHA-256.
    ///
    /// The value is produced from the server certificate, for example:
    ///
    ///     openssl s_client -connect HOST:443 -servername HOST </dev/null 2>/dev/null \
    ///       | openssl x509 -pubkey -noout \
    ///       | openssl pkey -pubin -outform der \
    ///       | openssl dgst -sha256 -binary \
    ///       | openssl enc -base64
    ///
    /// Always configure at least one backup pin that belongs to a spare key kept offline. Pins
    /// ship inside the app, so rotating the server key without an already published backup pin
    /// leaves every installed app unable to connect until it ships a new release.
    ///
    /// Defaults to no pinning.
    @objc public var certificatePins: [String] = []

    // only internal
    var disableReachabilityForTesting: Bool = false
    var disableQueueTimerForTesting: Bool = false
    // internal
    public var storageManager: PaylisherStorageManager?

    @objc(apiKey:)
    public init(
        apiKey: String
    ) {
        self.apiKey = apiKey
        host = URL(string: PaylisherConfig.defaultHost)!
    }

    @objc(apiKey:host:)
    public init(
        apiKey: String,
        host: String = defaultHost
    ) {
        self.apiKey = apiKey
        self.host = URL(string: host) ?? URL(string: PaylisherConfig.defaultHost)!
    }
}
