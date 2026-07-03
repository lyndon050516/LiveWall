import Foundation

extension Notification.Name {
    static let liveWallLibraryChanged = Notification.Name("LiveWallLibraryChanged")
}

final class WallpaperLibrary {
    static let shared = WallpaperLibrary()

    let directory: URL
    let thumbnailsDirectory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("LiveWall/Wallpapers", isDirectory: true)
        thumbnailsDirectory = base.appendingPathComponent("LiveWall/Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    func add(_ url: URL) -> URL {
        let destination = uniqueDestination(for: url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: destination)
        NotificationCenter.default.post(name: .liveWallLibraryChanged, object: nil)
        return destination
    }

    func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        let thumbnail = thumbnailsDirectory
            .appendingPathComponent(url.lastPathComponent)
            .appendingPathExtension("png")
        try? FileManager.default.removeItem(at: thumbnail)
        NotificationCenter.default.post(name: .liveWallLibraryChanged, object: nil)
    }

    func all() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func uniqueDestination(for name: String) -> URL {
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        var candidate = directory.appendingPathComponent(name)
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            index += 1
        }
        return candidate
    }
}
