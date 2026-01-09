import Foundation
import UserNotifications

class NotificationService: NSObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func sendDeploymentNotification(
        projectName: String,
        status: DeploymentStatus,
        environment: String?
    ) {
        let content = UNMutableNotificationContent()

        switch status {
        case .success:
            content.title = "Deployment Successful"
            content.body = "\(projectName) deployed successfully"
            if let env = environment {
                content.body += " to \(env)"
            }
            content.sound = .default

        case .failure:
            content.title = "Deployment Failed"
            content.body = "\(projectName) deployment failed"
            if let env = environment {
                content.body += " on \(env)"
            }
            content.sound = .defaultCritical

        case .active:
            content.title = "Deployment Started"
            content.body = "\(projectName) deployment in progress"
            content.sound = .default

        default:
            return
        }

        content.categoryIdentifier = "DEPLOYMENT"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }

    func sendWorkerNotification(workerName: String, event: String) {
        let content = UNMutableNotificationContent()
        content.title = "Worker Update"
        content.body = "\(workerName): \(event)"
        content.sound = .default
        content.categoryIdentifier = "WORKER"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap - could open Cloudflare dashboard
        completionHandler()
    }
}
