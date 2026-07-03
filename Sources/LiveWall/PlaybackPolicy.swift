import AppKit
import IOKit.ps

@MainActor
final class PlaybackPolicy {
    var onChange: (() -> Void)?

    private(set) var isLocked = false
    private(set) var displaysAsleep = false

    private var powerSource: CFRunLoopSource?

    init() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(screenLocked), name: .init("com.apple.screenIsLocked"), object: nil)
        dnc.addObserver(self, selector: #selector(screenUnlocked), name: .init("com.apple.screenIsUnlocked"), object: nil)

        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        wsnc.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(powerStateChanged), name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let policy = Unmanaged<PlaybackPolicy>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in policy.onChange?() }
        }, context)?.takeRetainedValue() {
            powerSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode)
        }
    }

    var isOnBattery: Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return false }
        guard let type = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as String? else { return false }
        return type != kIOPMACPowerKey
    }

    var isLowPowerMode: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    @objc private func screenLocked() { isLocked = true; onChange?() }
    @objc private func screenUnlocked() { isLocked = false; onChange?() }
    @objc private func screensSlept() { displaysAsleep = true; onChange?() }
    @objc private func screensWoke() { displaysAsleep = false; onChange?() }

    @objc private func powerStateChanged() {
        Task { @MainActor in self.onChange?() }
    }
}
