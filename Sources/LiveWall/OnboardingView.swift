import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @ObservedObject private var controller = WallpaperController.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            hero
            VStack(alignment: .leading, spacing: 18) {
                benefits
                Divider().opacity(0.4)
                toggles
                Spacer(minLength: 0)
                actions
            }
            .padding(28)
        }
        .frame(width: 560, height: 480)
        .background(Brand.windowBackground)
    }

    private var hero: some View {
        ZStack {
            Brand.gradient
            VStack(spacing: 8) {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
                Text("LiveWall")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Text("Live 4K wallpapers for your Mac.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.top, 12)
        }
        .frame(height: 176)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            BenefitRow(
                icon: "film.stack",
                text: "Any video or photo becomes your wallpaper.")
            BenefitRow(
                icon: "battery.75percent",
                text: "Battery-smart — auto-pauses on lock, sleep, battery, and Low Power Mode.")
            BenefitRow(
                icon: "menubar.rectangle",
                text: "Lives quietly in your menu bar.")
        }
    }

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    LaunchAtLogin.setEnabled(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }))
            Toggle("Pause on Battery", isOn: $controller.pausesOnBattery)
        }
        .toggleStyle(.switch)
        .font(.system(size: 13))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Skip for Now") { onFinish() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Choose Your First Wallpaper") {
                guard let source = WallpaperOpenPanel.present() else { return }
                let stored = controller.importFile(source)
                controller.applyWallpaper(stored)
                onFinish()
            }
            .buttonStyle(PrimaryGradientButton(size: .system(size: 14, weight: .semibold)))
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Brand.gradient)
                .frame(width: 28)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
