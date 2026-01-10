import Foundation
import AppKit

struct GitHubRelease: Decodable {
    let tagName: String
    let name: String
    let htmlUrl: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

@MainActor
class UpdateService: ObservableObject {
    static let shared = UpdateService()

    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadURL: URL?
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0

    private let repoOwner = "sushaantu"
    private let repoName = "CloudflareStatusBar"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() async {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"

        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            self.latestVersion = latestVersion

            if isNewerVersion(latestVersion, than: currentVersion) {
                self.updateAvailable = true
                // Find the zip asset
                if let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) {
                    self.downloadURL = URL(string: zipAsset.browserDownloadUrl)
                }
            } else {
                self.updateAvailable = false
            }
        } catch {
            print("Failed to check for updates: \(error)")
        }
    }

    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newParts.count, currentParts.count) {
            let newPart = i < newParts.count ? newParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0

            if newPart > currentPart { return true }
            if newPart < currentPart { return false }
        }
        return false
    }

    func downloadAndInstall() async {
        guard let downloadURL = downloadURL else { return }

        isDownloading = true
        downloadProgress = 0

        do {
            // Download to temp directory
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)

            // Move to Downloads folder
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let destinationURL = downloadsURL.appendingPathComponent("CloudflareStatusBar.zip")

            // Remove existing file if present
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            // Unzip
            let unzipDestination = downloadsURL.appendingPathComponent("CloudflareStatusBar_Update")
            try? FileManager.default.removeItem(at: unzipDestination)

            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzipProcess.arguments = ["-o", destinationURL.path, "-d", unzipDestination.path]
            try unzipProcess.run()
            unzipProcess.waitUntilExit()

            // Get the app path
            let newAppURL = unzipDestination.appendingPathComponent("CloudflareStatusBar.app")
            let applicationsURL = URL(fileURLWithPath: "/Applications/CloudflareStatusBar.app")

            // Create update script that runs after app quits
            let scriptContent = """
            #!/bin/bash
            sleep 1
            rm -rf "\(applicationsURL.path)"
            mv "\(newAppURL.path)" "\(applicationsURL.path)"
            open "\(applicationsURL.path)"
            rm -rf "\(unzipDestination.path)"
            rm "\(destinationURL.path)"
            """

            let scriptURL = downloadsURL.appendingPathComponent("cloudflare_update.sh")
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

            // Make executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            // Run script in background and quit app
            let script = Process()
            script.executableURL = URL(fileURLWithPath: "/bin/bash")
            script.arguments = [scriptURL.path]
            try script.run()

            // Quit the app
            NSApplication.shared.terminate(nil)

        } catch {
            print("Update failed: \(error)")
            isDownloading = false

            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Update Failed"
            alert.informativeText = "Failed to download update: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func showUpdateAlert() {
        guard let latestVersion = latestVersion else { return }

        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Version \(latestVersion) is available. You have version \(currentVersion).\n\nWould you like to download and install the update?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Update Now")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            Task {
                await downloadAndInstall()
            }
        }
    }
}
