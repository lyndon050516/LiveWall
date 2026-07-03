#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/LiveWall.app"
DIST="$ROOT/dist"
DMG="$DIST/LiveWall-1.0.0.dmg"

if [[ ! -d "$APP" ]]; then
    echo "LiveWall.app not found; building it first."
    "$ROOT/scripts/build-app.sh"
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/LiveWall.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$DIST"
rm -f "$DMG"

hdiutil create \
    -volname "LiveWall" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG"

echo "Created $DMG"
echo "Size: $(du -h "$DMG" | cut -f1)"
