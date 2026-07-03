import AppKit
import SwiftUI

@MainActor
final class WallpaperController: ObservableObject {
    static let shared = WallpaperController()

    static let currentWallpaperKey = "currentWallpaperPath"
    static let pausesOnBatteryKey = "pausesOnBattery"
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    @Published private(set) var library: [URL] = []
    @Published private(set) var activeWallpaper: URL?

    @Published var pausesOnBattery: Bool {
        didSet {
            guard pausesOnBattery != oldValue else { return }
            VideoWallpaperEngine.shared.pausesOnBattery = pausesOnBattery
            defaults.set(pausesOnBattery, forKey: Self.pausesOnBatteryKey)
        }
    }

    private let defaults = UserDefaults.standard

    private init() {
        if defaults.object(forKey: Self.pausesOnBatteryKey) != nil {
            pausesOnBattery = defaults.bool(forKey: Self.pausesOnBatteryKey)
        } else {
            pausesOnBattery = VideoWallpaperEngine.shared.pausesOnBattery
            defaults.set(pausesOnBattery, forKey: Self.pausesOnBatteryKey)
        }
        VideoWallpaperEngine.shared.pausesOnBattery = pausesOnBattery

        if let path = defaults.string(forKey: Self.currentWallpaperKey),
           FileManager.default.fileExists(atPath: path) {
            activeWallpaper = URL(fileURLWithPath: path)
        }

        refreshLibrary()

        NotificationCenter.default.addObserver(
            self, selector: #selector(libraryChanged),
            name: .liveWallLibraryChanged, object: nil)
    }

    var isRunning: Bool { VideoWallpaperEngine.shared.isRunning }

    // MARK: - Single apply path

    func applyWallpaper(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        if Self.videoExtensions.contains(ext) {
            VideoWallpaperEngine.shared.start(videoURL: url)
        } else {
            VideoWallpaperEngine.shared.stop()
            for screen in NSScreen.screens {
                try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            }
        }
        defaults.set(url.path, forKey: Self.currentWallpaperKey)
        activeWallpaper = url
        objectWillChange.send()
    }

    func stopLiveWallpaper() {
        VideoWallpaperEngine.shared.stop()
        objectWillChange.send()
    }

    func restoreLastWallpaper() {
        guard let path = defaults.string(forKey: Self.currentWallpaperKey),
              FileManager.default.fileExists(atPath: path) else { return }
        applyWallpaper(URL(fileURLWithPath: path))
    }

    // MARK: - Library

    @discardableResult
    func importFile(_ source: URL) -> URL {
        let stored = WallpaperLibrary.shared.add(source)
        refreshLibrary()
        return stored
    }

    func delete(_ url: URL) {
        let wasActive = (url == activeWallpaper)
        ThumbnailProvider.shared.invalidate(url)
        WallpaperLibrary.shared.delete(url)
        if wasActive {
            VideoWallpaperEngine.shared.stop()
            defaults.removeObject(forKey: Self.currentWallpaperKey)
            activeWallpaper = nil
        }
        refreshLibrary()
    }

    func refreshLibrary() {
        library = WallpaperLibrary.shared.all()
    }

    @objc private func libraryChanged() {
        refreshLibrary()
    }
}

enum WallpaperOpenPanel {
    static func present() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .image, .png, .jpeg, .heic]
        return panel.runModal() == .OK ? panel.url : nil
    }
}
