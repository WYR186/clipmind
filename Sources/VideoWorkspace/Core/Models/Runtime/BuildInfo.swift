import Foundation

public struct BuildInfo: Codable, Hashable, Sendable {
    public let appName: String
    public let version: String
    public let buildNumber: String
    public let runtimeMode: AppRuntimeMode

    public init(
        appName: String,
        version: String,
        buildNumber: String,
        runtimeMode: AppRuntimeMode
    ) {
        self.appName = appName
        self.version = version
        self.buildNumber = buildNumber
        self.runtimeMode = runtimeMode
    }

    public static func current(
        bundle: Bundle = .main,
        runtimeMode: AppRuntimeMode = .current
    ) -> BuildInfo {
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "VideoWorkspace"
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "dev"
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            ?? "0"

        return BuildInfo(
            appName: name,
            version: version,
            buildNumber: build,
            runtimeMode: runtimeMode
        )
    }
}
