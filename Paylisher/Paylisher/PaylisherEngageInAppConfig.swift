import Foundation

/// Optional configuration for fetching in-app campaigns directly from Engage.
///
/// All identification fields (teamId, projectId, sourceId, sdkKey, fetchEndpoint)
/// are optional. When they are nil, the SDK resolves them from its top-level
/// config: sdkKey defaults to the SDK apiKey, fetchEndpoint defaults to
/// `\(host)/v1/push/inapp/fetch`. Engage reverse-resolves teamId/projectId/sourceId
/// server-side from the public sdkKey, so apps don't need to embed them.
///
/// Mirrors paylisher-android `PaylisherEngageInAppConfig` 1:1.
@objc(PaylisherEngageInAppConfig)
public class PaylisherEngageInAppConfig: NSObject {
    @objc public var fetchEndpoint: String?
    @objc public var teamId: String?
    @objc public var projectId: String?
    @objc public var sourceId: String?
    @objc public var sdkKey: String?
    @objc public var autoFetchOnForeground: Bool = true
    @objc public var maxMessages: Int = 1
    @objc public var debugLogging: Bool = false

    /// Class name fragments (case-insensitive substring match) for view controllers
    /// where in-app banners should NOT be rendered (e.g. splash, login).
    /// The SDK queues messages and renders them when a non-excluded screen becomes active.
    @objc public var excludedActivities: [String] = ["Splash"]

    @objc override public init() {
        super.init()
    }

    /// Swift convenience initializer. Every field is optional; omit what you
    /// don't need and the SDK derives sensible defaults (see class docs).
    public convenience init(
        fetchEndpoint: String? = nil,
        teamId: String? = nil,
        projectId: String? = nil,
        sourceId: String? = nil,
        sdkKey: String? = nil,
        autoFetchOnForeground: Bool = true,
        maxMessages: Int = 1,
        debugLogging: Bool = false,
        excludedActivities: [String] = ["Splash"]
    ) {
        self.init()
        self.fetchEndpoint = fetchEndpoint
        self.teamId = teamId
        self.projectId = projectId
        self.sourceId = sourceId
        self.sdkKey = sdkKey
        self.autoFetchOnForeground = autoFetchOnForeground
        self.maxMessages = maxMessages
        self.debugLogging = debugLogging
        self.excludedActivities = excludedActivities
    }
}
