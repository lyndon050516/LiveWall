import SwiftUI
import UniformTypeIdentifiers

struct GalleryView: View {
    @ObservedObject private var controller = WallpaperController.shared
    @State private var showingSettings = false
    @State private var isDropTargeted = false

    private let columns = [GridItem(.adaptive(minimum: 210, maximum: 300), spacing: 20)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            content
        }
        .frame(minWidth: 640, minHeight: 420)
        .background(Brand.windowBackground)
        .overlay(dropHighlight)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("LiveWall")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Button(action: addWallpaper) {
                Label("Add Wallpaper", systemImage: "plus")
            }
            .buttonStyle(PrimaryGradientButton())

            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                SettingsPopover()
            }
        }
        .padding(.leading, 80)
        .padding(.trailing, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if controller.library.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(controller.library, id: \.self) { url in
                        WallpaperCell(
                            url: url,
                            isActive: url == controller.activeWallpaper,
                            onApply: { controller.applyWallpaper(url) },
                            onReveal: { NSWorkspace.shared.activateFileViewerSelecting([url]) },
                            onDelete: { controller.delete(url) })
                    }
                }
                .padding(24)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(Brand.gradient)
            Text("No wallpapers yet")
                .font(.system(size: 20, weight: .semibold))
            Text("Add a video or photo to bring your desktop to life.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button("Add Your First Wallpaper", action: addWallpaper)
                .buttonStyle(PrimaryGradientButton(size: .system(size: 14, weight: .semibold)))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dropHighlight: some View {
        RoundedRectangle(cornerRadius: 0)
            .strokeBorder(Brand.gradient, lineWidth: 3)
            .opacity(isDropTargeted ? 1 : 0)
            .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func addWallpaper() {
        guard let source = WallpaperOpenPanel.present() else { return }
        let stored = controller.importFile(source)
        controller.applyWallpaper(stored)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var resolved: URL?
            if let data = item as? Data {
                resolved = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                resolved = url
            }
            guard let url = resolved else { return }

            let allowed: Set<String> = ["mp4", "mov", "m4v", "png", "jpg", "jpeg", "heic", "heif", "gif", "bmp", "tiff"]
            guard allowed.contains(url.pathExtension.lowercased()) else { return }

            Task { @MainActor in
                let stored = WallpaperController.shared.importFile(url)
                WallpaperController.shared.applyWallpaper(stored)
            }
        }
        return true
    }
}

// MARK: - Cell

private struct WallpaperCell: View {
    let url: URL
    let isActive: Bool
    let onApply: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void

    @State private var thumbnail: NSImage?
    @State private var hovering = false

    private var isVideo: Bool {
        ThumbnailProvider.videoExtensions.contains(url.pathExtension.lowercased())
    }

    private var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnailView
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if isVideo { liveBadge.padding(8) }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isActive ? AnyShapeStyle(Brand.gradient)
                                     : AnyShapeStyle(Color.white.opacity(hovering ? 0.22 : 0.08)),
                            lineWidth: isActive ? 3 : 1))
                .shadow(color: .black.opacity(hovering ? 0.35 : 0.15),
                        radius: hovering ? 12 : 6, y: 4)

            Text(displayName)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .scaleEffect(hovering ? 1.02 : 1)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onApply)
        .contextMenu {
            Button("Reveal in Finder", action: onReveal)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .task(id: url) {
            thumbnail = await ThumbnailProvider.shared.thumbnail(for: url)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color.white.opacity(0.05))
                ProgressView().controlSize(.small)
            }
        }
    }

    private var liveBadge: some View {
        Text("LIVE")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Brand.gradient)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

// MARK: - Settings popover

private struct SettingsPopover: View {
    @ObservedObject private var controller = WallpaperController.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Pause on Battery", isOn: $controller.pausesOnBattery)
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    LaunchAtLogin.setEnabled(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }))
        }
        .toggleStyle(.switch)
        .padding(16)
        .frame(width: 240)
    }
}
