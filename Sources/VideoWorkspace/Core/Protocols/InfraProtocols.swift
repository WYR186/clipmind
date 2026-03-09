import Foundation

public protocol AppLoggerProtocol: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func error(_ message: String)
}

public protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async
    func notify(_ message: AppNotificationMessage) async
}
