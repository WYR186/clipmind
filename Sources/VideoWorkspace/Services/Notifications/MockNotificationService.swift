import Foundation

struct MockNotificationService: NotificationServiceProtocol {
    private let logger: any AppLoggerProtocol

    init(logger: any AppLoggerProtocol) {
        self.logger = logger
    }

    func requestAuthorization() async {
        logger.debug("Mock notification authorization granted")
    }

    func notify(_ message: AppNotificationMessage) async {
        logger.info("Notification: \(message.title) - \(message.body)")
    }
}
