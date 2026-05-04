import Foundation

@objc(PaylisherEngageInAppConfig)
public class PaylisherEngageInAppConfig: NSObject {
    @objc public let fetchEndpoint: String
    @objc public let teamId: String
    @objc public let projectId: String
    @objc public let sourceId: String
    @objc public let sdkKey: String
    @objc public var autoFetchOnForeground: Bool = true
    @objc public var maxMessages: Int = 1
    @objc public var debugLogging: Bool = false

    /// Class name fragments (case-insensitive substring match) for view controllers
    /// where in-app banners should NOT be rendered (e.g. splash, login).
    /// The SDK queues messages and renders them when a non-excluded screen becomes active.
    @objc public var excludedActivities: [String] = ["Splash"]

    @objc(fetchEndpoint:teamId:projectId:sourceId:sdkKey:)
    public init(
        fetchEndpoint: String,
        teamId: String,
        projectId: String,
        sourceId: String,
        sdkKey: String
    ) {
        self.fetchEndpoint = fetchEndpoint
        self.teamId = teamId
        self.projectId = projectId
        self.sourceId = sourceId
        self.sdkKey = sdkKey
    }
}
