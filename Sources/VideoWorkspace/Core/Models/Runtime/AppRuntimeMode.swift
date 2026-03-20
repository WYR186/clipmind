import Foundation

public enum AppRuntimeMode: String, Codable, CaseIterable, Sendable {
    case debug
    case release

    public static var current: AppRuntimeMode {
        #if DEBUG
        return .debug
        #else
        return .release
        #endif
    }

    public var allowsMockFallback: Bool {
        self == .debug
    }

    public var allowsVerboseDiagnostics: Bool {
        self == .debug
    }
}
