import Foundation

public enum RecoverySuggestion: String, Codable, CaseIterable, Sendable {
    case retry = "Retry the operation"
    case verifyNetwork = "Check your network connection"
    case verifyURL = "Check whether the URL is valid"
    case installExternalTools = "Install required external tools"
    case installViaHomebrew = "Install tools via Homebrew (brew install ffmpeg yt-dlp)"
    case configureAPIKey = "Configure API key in Settings > Providers"
    case switchProvider = "Try another summary provider"
    case startLocalService = "Start your local model service and retry"
    case chooseWritableDirectory = "Choose a writable output directory"
    case freeDiskSpace = "Free up disk space and retry"
    case checkPermissions = "Grant file access permission"
    case enableNotificationsInSystemSettings = "Enable notifications in macOS System Settings"

    public var message: String {
        rawValue
    }
}
