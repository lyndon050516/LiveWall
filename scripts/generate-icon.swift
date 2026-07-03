#!/usr/bin/env swift
import AppKit
import CoreGraphics

// LiveWall app icon generator.
// Draws a macOS Big-Sur-style squircle tile with an indigo -> cyan gradient
// and a white play-triangle emerging from a minimal mountain silhouette.
// Redraws crisply at every iconset pixel size, then packs an .icns.

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let resources = root.appendingPathComponent("Resources")
let iconset = resources.appendingPathComponent("AppIcon.iconset")
let icns = resources.appendingPathComponent("AppIcon.icns")

let colorSpace = CGColorSpaceCreateDeviceRGB()

func hex(_ value: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: alpha
    )
}

// Rounded polygon path from ordered points using tangent arcs.
func roundedPolygon(_ points: [CGPoint], radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let count = points.count
    let start = CGPoint(
        x: (points[count - 1].x + points[0].x) / 2,
        y: (points[count - 1].y + points[0].y) / 2
    )
    path.move(to: start)
    for i in 0..<count {
        let current = points[i]
        let next = points[(i + 1) % count]
        path.addArc(tangent1End: current, tangent2End: next, radius: radius)
    }
    path.closeSubpath()
    return path
}

// Design coordinates are authored on a 1024x1024 canvas (origin bottom-left)
// and scaled to the requested pixel size so edges stay crisp at any size.
func draw(size: Int) -> CGImage {
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let f = CGFloat(size) / 1024.0
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Tile geometry.
    let inset: CGFloat = 100 * f
    let cornerRadius: CGFloat = 185 * f
    let tile = CGRect(
        x: inset,
        y: inset,
        width: CGFloat(size) - inset * 2,
        height: CGFloat(size) - inset * 2
    )
    let tilePath = CGPath(
        roundedRect: tile,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    // Base diagonal gradient: deep indigo (bottom-left) -> cyan (top-right).
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let baseColors = [hex(0x3D3DBF), hex(0x5B5BE6), hex(0x6FE7DD)] as CFArray
    let baseStops: [CGFloat] = [0.0, 0.5, 1.0]
    let baseGradient = CGGradient(colorsSpace: colorSpace, colors: baseColors, locations: baseStops)!
    ctx.drawLinearGradient(
        baseGradient,
        start: CGPoint(x: tile.minX, y: tile.minY),
        end: CGPoint(x: tile.maxX, y: tile.maxY),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Bottom vignette for depth.
    let vignetteColors = [hex(0x000000, 0.28), hex(0x000000, 0.0)] as CFArray
    let vignetteStops: [CGFloat] = [0.0, 1.0]
    let vignette = CGGradient(colorsSpace: colorSpace, colors: vignetteColors, locations: vignetteStops)!
    ctx.drawLinearGradient(
        vignette,
        start: CGPoint(x: tile.midX, y: tile.minY),
        end: CGPoint(x: tile.midX, y: tile.minY + tile.height * 0.42),
        options: []
    )

    // Faint diagonal sheen band (low-alpha white) running bottom-left to top-right.
    let sheenColors = [
        hex(0xFFFFFF, 0.0),
        hex(0xFFFFFF, 0.0),
        hex(0xFFFFFF, 0.12),
        hex(0xFFFFFF, 0.0),
        hex(0xFFFFFF, 0.0)
    ] as CFArray
    let sheenStops: [CGFloat] = [0.0, 0.42, 0.5, 0.58, 1.0]
    let sheen = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: sheenStops)!
    ctx.drawLinearGradient(
        sheen,
        start: CGPoint(x: tile.minX, y: tile.maxY),
        end: CGPoint(x: tile.maxX, y: tile.minY),
        options: []
    )
    ctx.restoreGState()

    // Mountain-and-horizon silhouette (white, ~92% alpha), lower third of tile.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let horizonY: CGFloat = 360 * f
    let mountainColor = hex(0xFFFFFF, 0.92)

    // Thin horizon line.
    let horizonRect = CGRect(
        x: 235 * f,
        y: horizonY - 5 * f,
        width: (789 - 235) * f,
        height: 10 * f
    )
    ctx.addPath(CGPath(roundedRect: horizonRect, cornerWidth: 5 * f, cornerHeight: 5 * f, transform: nil))
    ctx.setFillColor(mountainColor)
    ctx.fillPath()

    // Two overlapping mountain triangles sitting on the horizon.
    let mountainA = roundedPolygon([
        CGPoint(x: 250 * f, y: horizonY),
        CGPoint(x: 388 * f, y: 512 * f),
        CGPoint(x: 526 * f, y: horizonY)
    ], radius: 24 * f)
    let mountainB = roundedPolygon([
        CGPoint(x: 470 * f, y: horizonY),
        CGPoint(x: 612 * f, y: 556 * f),
        CGPoint(x: 774 * f, y: horizonY)
    ], radius: 24 * f)
    ctx.setFillColor(mountainColor)
    ctx.addPath(mountainA)
    ctx.fillPath()
    ctx.addPath(mountainB)
    ctx.fillPath()
    ctx.restoreGState()

    // Play triangle (pure white, rounded corners, soft drop shadow), centered
    // and overlapping the mountain peaks so it appears to emerge from them.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let play = roundedPolygon([
        CGPoint(x: 430 * f, y: 668 * f),
        CGPoint(x: 430 * f, y: 412 * f),
        CGPoint(x: 700 * f, y: 540 * f)
    ], radius: 34 * f)
    ctx.setShadow(
        offset: CGSize(width: 0, height: -8 * f),
        blur: 26 * f,
        color: hex(0x000000, 0.35)
    )
    ctx.setFillColor(hex(0xFFFFFF, 1.0))
    ctx.addPath(play)
    ctx.fillPath()
    ctx.restoreGState()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("Failed to encode PNG for \(url.lastPathComponent)\n".utf8))
        exit(1)
    }
    try! data.write(to: url)
}

let fm = FileManager.default
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: resources, withIntermediateDirectories: true)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

// (base point size, scale factor, filename) for a standard iconset.
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    let image = draw(size: variant.pixels)
    writePNG(image, to: iconset.appendingPathComponent(variant.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed with status \(process.terminationStatus)\n".utf8))
    exit(1)
}

try fm.removeItem(at: iconset)
print("Wrote \(icns.path)")
