import Foundation
import UserNotifications
import AppKit

class NotificationService: NSObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    var accountId: String?

    private override init() {
        super.init()
        center.delegate = self
        setupNotificationCategories()
    }

    private func setupNotificationCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_DASHBOARD",
            title: "Open Dashboard",
            options: [.foreground]
        )

        let deploymentCategory = UNNotificationCategory(
            identifier: "DEPLOYMENT",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        let workerCategory = UNNotificationCategory(
            identifier: "WORKER",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([deploymentCategory, workerCategory])
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
        content.userInfo = ["projectName": projectName, "type": "pages"]

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
        content.userInfo = ["workerName": workerName, "type": "worker"]

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
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String

        // Open dashboard when notification is tapped or action is clicked
        if let accountId = accountId {
            var urlString: String?

            if type == "pages", let projectName = userInfo["projectName"] as? String {
                urlString = "https://dash.cloudflare.com/\(accountId)/pages/view/\(projectName)"
            } else if type == "worker", let workerName = userInfo["workerName"] as? String {
                urlString = "https://dash.cloudflare.com/\(accountId)/workers/services/view/\(workerName)/production"
            }

            if let urlString = urlString, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }

        completionHandler()
    }
}
