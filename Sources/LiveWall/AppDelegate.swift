import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = WallpaperController.shared
    private let defaults = UserDefaults.standard

    private var galleryWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    private let releasesURL = URL(string: "https://github.com/lyndon050516/LiveWall/releases")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(systemSymbolName: "play.rectangle.on.rectangle", accessibilityDescription: "LiveWall")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        controller.restoreLastWallpaper()

        if !defaults.bool(forKey: WallpaperController.hasCompletedOnboardingKey) {
            showOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if defaults.bool(forKey: WallpaperController.hasCompletedOnboardingKey) {
            openGallery()
        }
        return true
    }

    // MARK: - Status item

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            showMenu()
        } else {
            openGallery()
        }
    }

    private func showMenu() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(makeItem("Open LiveWall", #selector(openGallery)))
        menu.addItem(makeItem("Choose Wallpaper…", #selector(chooseWallpaper)))

        let wallpapersItem = NSMenuItem(title: "Wallpapers", action: nil, keyEquivalent: "")
        wallpapersItem.submenu = buildWallpapersSubmenu()
        menu.addItem(wallpapersItem)

        menu.addItem(.separator())

        let pauseItem = makeItem("Pause on Battery", #selector(togglePauseOnBattery))
        pauseItem.state = controller.pausesOnBattery ? .on : .off
        menu.addItem(pauseItem)

        let loginItem = makeItem("Launch at Login", #selector(toggleLaunchAtLogin))
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)

        let stopItem = makeItem("Stop Live Wallpaper", #selector(stopLiveWallpaper))
        stopItem.isEnabled = controller.isRunning
        menu.addItem(stopItem)

        menu.addItem(.separator())

        menu.addItem(makeItem("About LiveWall", #selector(showAbout)))
        menu.addItem(makeItem("Check for Updates…", #selector(checkForUpdates)))
        menu.addItem(makeItem("Quit LiveWall", #selector(quit), key: "q"))

        return menu
    }

    private func buildWallpapersSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let library = controller.library
        if library.isEmpty {
            let empty = NSMenuItem(title: "(empty)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            let active = controller.activeWallpaper
            for url in library {
                let item = NSMenuItem(title: url.lastPathComponent, action: #selector(selectWallpaper(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                item.state = (url == active) ? .on : .off
                submenu.addItem(item)
            }
        }
        return submenu
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Menu actions

    @objc private func chooseWallpaper() {
        guard let source = WallpaperOpenPanel.present() else { return }
        let stored = controller.importFile(source)
        controller.applyWallpaper(stored)
    }

    @objc private func selectWallpaper(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        controller.applyWallpaper(url)
    }

    @objc private func togglePauseOnBattery() {
        controller.pausesOnBattery.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
    }

    @objc private func stopLiveWallpaper() {
        controller.stopLiveWallpaper()
    }

    @objc private func checkForUpdates() {
        NSWorkspace.shared.open(releasesURL)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Free & open source — github.com/lyndon050516/LiveWall",
            attributes: [.foregroundColor: NSColor.secondaryLabelColor,
                         .font: NSFont.systemFont(ofSize: 11)])
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "LiveWall",
            .applicationVersion: appVersion,
            .credits: credits
        ])
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    // MARK: - Windows

    @objc private func openGallery() {
        if galleryWindow == nil {
            let hosting = NSHostingController(rootView: GalleryView())
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.title = "LiveWall"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 900, height: 600))
            window.minSize = NSSize(width: 640, height: 420)
            window.appearance = NSAppearance(named: .darkAqua)
            window.center()
            galleryWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        galleryWindow?.makeKeyAndOrderFront(nil)
    }

    private func showOnboarding() {
        if onboardingWindow == nil {
            let hosting = NSHostingController(rootView: OnboardingView(onFinish: { [weak self] in
                self?.finishOnboarding()
            }))
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.title = "Welcome to LiveWall"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 560, height: 480))
            window.appearance = NSAppearance(named: .darkAqua)
            window.center()
            onboardingWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    private func finishOnboarding() {
        defaults.set(true, forKey: WallpaperController.hasCompletedOnboardingKey)
        onboardingWindow?.close()
        onboardingWindow = nil
        openGallery()
    }
}
