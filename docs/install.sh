#!/bin/bash
# LiveWall installer: downloads the latest release, installs it to
# /Applications, and clears the Gatekeeper quarantine flag.
set -euo pipefail

REPO="lyndon050516/LiveWall"
APP="/Applications/LiveWall.app"
TMPDIR_INSTALL="$(mktemp -d)"
MOUNT_POINT="$TMPDIR_INSTALL/mnt"

cleanup() {
  if [ -d "$MOUNT_POINT" ]; then
    hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$TMPDIR_INSTALL"
}
trap cleanup EXIT

echo "Finding the latest LiveWall release..."
DMG_URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*"' \
  | head -n 1 \
  | sed 's/.*"\(https[^"]*\)".*/\1/')"

if [ -z "$DMG_URL" ]; then
  echo "Error: could not find a download URL for the latest release." >&2
  echo "You can download it manually from https://github.com/$REPO/releases/latest" >&2
  exit 1
fi

echo "Downloading $DMG_URL ..."
DMG_PATH="$TMPDIR_INSTALL/LiveWall.dmg"
if ! curl -fL --progress-bar -o "$DMG_PATH" "$DMG_URL"; then
  echo "Error: download failed. Check your internet connection and try again." >&2
  exit 1
fi

echo "Quitting LiveWall if it is running..."
pkill -x LiveWall || true

echo "Mounting the disk image..."
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_PATH" -nobrowse -quiet -mountpoint "$MOUNT_POINT"

echo "Copying LiveWall to /Applications..."
rm -rf "$APP"
if ! cp -R "$MOUNT_POINT/LiveWall.app" "$APP"; then
  echo "Error: could not copy LiveWall.app to /Applications." >&2
  exit 1
fi

echo "Removing the Gatekeeper quarantine flag..."
xattr -dr com.apple.quarantine "$APP"

echo "Launching LiveWall..."
open "$APP"

echo "LiveWall installed successfully. Look for its icon in the menu bar."
