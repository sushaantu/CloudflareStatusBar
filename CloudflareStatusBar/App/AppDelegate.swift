import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: CloudflareViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = CloudflareViewModel()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "Cloudflare Status")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: viewModel))

        NotificationService.shared.requestPermission()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopAutoRefresh()
    }

    func popoverWillShow(_ notification: Notification) {
        viewModel.startAutoRefresh()
        viewModel.requestRefresh()
    }

    func popoverDidClose(_ notification: Notification) {
        viewModel.stopAutoRefresh()
    }
}
