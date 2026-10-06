#!/usr/bin/env bash
# Install the DynaMan icon set + desktop entry for the current user.
# Linux binaries can't embed icons (that's a Windows thing) — the icon
# comes from the hicolor theme + a .desktop entry pointing at the
# binary. Run this once (and again if the repo ever moves):
#   bash dist/install_desktop_entry.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$(dirname "$HERE")/build/dynaman.x86_64"
[ -x "$BIN" ] || { echo "build first: $BIN not found"; exit 1; }

for s in 16 24 32 48 64 128 256 512; do
    dest="$HOME/.local/share/icons/hicolor/${s}x${s}/apps"
    mkdir -p "$dest"
    cp "$HERE/icons/dynaman_${s}.png" "$dest/dynaman.png"
done

apps="$HOME/.local/share/applications"
mkdir -p "$apps"
sed "s|__EXEC__|$BIN|" "$HERE/dynaman.desktop" > "$apps/dynaman.desktop"
chmod +x "$apps/dynaman.desktop"

gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
update-desktop-database "$apps" 2>/dev/null || true
echo "installed: icon set (16-512px) + $apps/dynaman.desktop -> $BIN"
