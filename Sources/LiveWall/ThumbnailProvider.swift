import AppKit
import AVFoundation
import CoreMedia
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    private static let maxPixelSize: CGFloat = 640

    private var memory: [String: NSImage] = [:]

    private var directory: URL { WallpaperLibrary.shared.thumbnailsDirectory }

    func cached(for url: URL) -> NSImage? {
        memory[url.lastPathComponent]
    }

    func invalidate(_ url: URL) {
        memory[url.lastPathComponent] = nil
    }

    func thumbnail(for url: URL) async -> NSImage? {
        let key = url.lastPathComponent
        if let image = memory[key] { return image }

        let diskURL = directory.appendingPathComponent(key).appendingPathExtension("png")
        if let image = NSImage(contentsOf: diskURL) {
            memory[key] = image
            return image
        }

        let isVideo = Self.videoExtensions.contains(url.pathExtension.lowercased())
        var cgImage: CGImage?

        if isVideo {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: Self.maxPixelSize, height: Self.maxPixelSize)
            generator.requestedTimeToleranceBefore = .positiveInfinity
            generator.requestedTimeToleranceAfter = .positiveInfinity
            let time = CMTime(seconds: 1, preferredTimescale: 600)
            cgImage = try? await generator.image(at: time).image
        } else {
            let maxPixel = Self.maxPixelSize
            cgImage = await Task.detached(priority: .userInitiated) {
                Self.downsample(url: url, maxPixel: maxPixel)
            }.value
        }

        guard let cgImage else { return nil }
        guard let data = Self.encodePNG(cgImage) else { return nil }
        try? data.write(to: diskURL)

        guard let image = NSImage(data: data) else { return nil }
        memory[key] = image
        return image
    }

    private nonisolated static func downsample(url: URL, maxPixel: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private nonisolated static func encodePNG(_ cgImage: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}
