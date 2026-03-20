import Foundation
import UserNotifications

actor MacOSNotificationService: NotificationServiceProtocol {
    private let logger: any AppLoggerProtocol
    private let center: UNUserNotificationCenter

    init(
        logger: any AppLoggerProtocol,
        center: UNUserNotificationCenter = .current()
    ) {
        self.logger = logger
        self.center = center
    }

    static func isSupportedInCurrentProcess(bundle: Bundle = .main) -> Bool {
        let hasBundleIdentifier = !(bundle.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let isAppBundle = bundle.bundleURL.pathExtension.lowercased() == "app"
        return hasBundleIdentifier && isAppBundle
    }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            logger.info("Notification authorization status: \(granted ? "granted" : "denied")")
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription)")
        }
    }

    func authorizationStatus() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .unknown
        }
    }

    func notify(_ message: AppNotificationMessage) async {
        let granted = await authorizationStatus() == .authorized
        guard granted else {
            logger.info("Notifications disabled: \(message.title) - \(message.body)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            logger.error("Notification delivery failed: \(error.localizedDescription)")
        }
    }
}
