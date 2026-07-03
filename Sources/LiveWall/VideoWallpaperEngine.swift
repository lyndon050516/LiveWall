import AppKit
import AVFoundation

@MainActor
final class VideoWallpaperEngine {
    static let shared = VideoWallpaperEngine()

    private(set) var isRunning = false

    var pausesOnBattery = true {
        didSet {
            guard pausesOnBattery != oldValue else { return }
            reevaluate()
        }
    }

    private let policy = PlaybackPolicy()

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var windows: [NSWindow] = []
    private var currentURL: URL?

    private init() {
        policy.onChange = { [weak self] in self?.reevaluate() }

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(occlusionChanged),
            name: NSWindow.didChangeOcclusionStateNotification, object: nil)
    }

    func start(videoURL: URL) {
        currentURL = videoURL

        let item = AVPlayerItem(url: videoURL)
        if let player {
            looper = nil
            player.removeAllItems()
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.preventsDisplaySleepDuringVideoPlayback = false
            queue.automaticallyWaitsToMinimizeStalling = false
            looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
        }

        rebuildWindows()
        isRunning = true
        reevaluate()
    }

    func stop() {
        player?.pause()
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        looper = nil
        player = nil
        currentURL = nil
        isRunning = false
    }

    private func rebuildWindows() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()

        guard let player else { return }

        let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen)
            window.ignoresMouseEvents = true
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.level = level
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

            let contentView = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            contentView.wantsLayer = true

            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.frame = contentView.bounds
            playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            contentView.layer?.addSublayer(playerLayer)

            window.contentView = contentView
            window.orderBack(nil)

            windows.append(window)
        }
    }

    private func reevaluate() {
        guard isRunning, let player else { return }

        let anyVisible = windows.contains { $0.occlusionState.contains(.visible) }

        let shouldPause =
            policy.isLocked ||
            policy.displaysAsleep ||
            !anyVisible ||
            (pausesOnBattery && policy.isOnBattery) ||
            policy.isLowPowerMode

        if shouldPause {
            player.pause()
        } else {
            player.play()
        }
    }

    @objc private func screenParametersChanged() {
        guard isRunning else { return }
        rebuildWindows()
        reevaluate()
    }

    @objc private func occlusionChanged() {
        reevaluate()
    }
}
