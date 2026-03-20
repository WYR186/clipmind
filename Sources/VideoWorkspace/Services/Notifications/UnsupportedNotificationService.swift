import Foundation

struct UnsupportedNotificationService: NotificationServiceProtocol {
    private let logger: any AppLoggerProtocol
    private let reason: String

    init(logger: any AppLoggerProtocol, reason: String) {
        self.logger = logger
        self.reason = reason
    }

    func requestAuthorization() async {
        logger.info("Notifications unavailable in current process: \(reason)")
    }

    func authorizationStatus() async -> NotificationAuthorizationState {
        .unknown
    }

    func notify(_ message: AppNotificationMessage) async {
        logger.info("Notification suppressed: \(message.title) - \(message.body)")
    }
}
