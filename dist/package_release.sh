#!/usr/bin/env bash
## Release packages — what a player unpacks and runs:
##   DynaMan-<version>-linux64.zip              Linux x86-64
##   DynaMan-<version>-steam-deck.zip           SteamOS (same binary, Deck launcher)
##   DynaMan-<version>-raspberry-pi5-arm64.zip  Raspberry Pi 5 / 64-bit ARM Linux
## plus SHA256SUMS, in build/release-<version>/. Exports the "Linux" and
## "Linux ARM64" presets with Godot 4.7, smoke-boots the x86-64 build in
## a throwaway profile, and writes the engine's own licence + third-party
## notices next to the game (Godot is MIT; this game is GPL-3.0-or-later).
## Usage: dist/package_release.sh   (override the engine with GODOT=/path)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot4 || command -v godot \
	|| ls "$ROOT"/../godot/Godot_v4*_linux.x86_64 2>/dev/null | tail -1 || true)}"
[ -n "$GODOT" ] && [ -x "$GODOT" ] || { echo "Godot 4.7 not found: set GODOT=/path" >&2; exit 1; }
VERSION="$(sed -n 's/^const VERSION := "v\(.*\)"$/\1/p' "$ROOT/scripts/ui/startup.gd")"
[ -n "$VERSION" ] || { echo "no VERSION in scripts/ui/startup.gd" >&2; exit 1; }
OUT="$ROOT/build/release-$VERSION"
EXP="$OUT/export"
rm -rf "${OUT:?}"
mkdir -p "$EXP"
# A throwaway profile: exporting, notices and the smoke boot must never
# touch the player's own settings.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
run_godot() { XDG_DATA_HOME="$SANDBOX/data" XDG_CONFIG_HOME="$SANDBOX/config" \
	XDG_CACHE_HOME="$SANDBOX/cache" "$GODOT" "$@"; }

echo "== DynaMan $VERSION — exporting with $("$GODOT" --version)"
# (Exports run in the normal profile: that is where the export templates
# live. The editor never runs the game's autoloads, so no save is touched.)
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" --export-release "Linux" "$EXP/DynaMan.x86_64" >"$OUT/export-linux64.log" 2>&1
"$GODOT" --headless --path "$ROOT" --export-release "Linux ARM64" "$EXP/DynaMan.arm64" >"$OUT/export-arm64.log" 2>&1
file "$EXP/DynaMan.x86_64" | grep -q "x86-64" || { echo "x86-64 export missing/wrong" >&2; exit 1; }
file "$EXP/DynaMan.arm64" | grep -q "aarch64" || { echo "arm64 export missing/wrong" >&2; exit 1; }
for b in DynaMan.x86_64 DynaMan.arm64; do
	[ "$(stat -c %s "$EXP/$b")" -gt 20000000 ] || { echo "$b too small — PCK not embedded?" >&2; exit 1; }
done

# The engine's licence + every bundled third-party component, from the
# very engine that exported the binaries.
run_godot --headless --path "$ROOT" --script res://dist/godot_notices.gd -- "$EXP/THIRD_PARTY_NOTICES.txt" >/dev/null 2>&1
[ -s "$EXP/THIRD_PARTY_NOTICES.txt" ] || { echo "notices not written" >&2; exit 1; }

# Smoke boot: alive after 8 s (exit 124 = still running = good).
set +e
XDG_DATA_HOME="$SANDBOX/data" XDG_CONFIG_HOME="$SANDBOX/config" \
	timeout 8 "$EXP/DynaMan.x86_64" --headless >"$OUT/smoke-linux64.log" 2>&1
rc=$?
set -e
[ "$rc" = 124 ] || { echo "x86-64 smoke boot failed (exit $rc), see $OUT/smoke-linux64.log" >&2; exit 1; }
if grep -qE "SCRIPT ERROR|^ERROR:" "$OUT/smoke-linux64.log"; then
	echo "x86-64 smoke boot logged errors, see $OUT/smoke-linux64.log" >&2; exit 1
fi

CONTROLS='CONTROLS
  Keyboard  P1 W A S D + Space   P2 arrows + Ctrl
            P3 I J K L + O       P4 numpad 8 4 5 6 + 0
            (rebind under OPTIONS > CONTROLS)
  Gamepads  pad N is player N: d-pad / left stick to move, A to bomb,
            START pause / resume, BACK quit to menu, Y rematch.
  Also      Esc pause, R rematch, Q quit to menu, F11 full screen,
            hold H for the quick help.
  Settings  ~/.local/share/godot/app_userdata/DynaMan/'

package() {  # package <platform> <binary> <start-text> <run.sh body>
	local plat="$1" bin="$2" start="$3" launch="$4"
	local name="DynaMan-$VERSION-$plat"
	local stage="$OUT/$name"
	mkdir -p "$stage"
	cp -p "$EXP/$bin" "$stage/$bin"
	chmod +x "$stage/$bin"
	cp "$ROOT/LICENSE" "$stage/LICENSE"
	cp "$EXP/THIRD_PARTY_NOTICES.txt" "$stage/THIRD_PARTY_NOTICES.txt"
	cp "$ROOT/dist/icons/dynaman_256.png" "$stage/icon.png"
	printf '%s\n' "$launch" >"$stage/run.sh"
	chmod +x "$stage/run.sh"
	cat >"$stage/shortcut.sh" <<'SHORTCUT'
#!/bin/sh
# Put DynaMan in your application menu, pointing at this folder:
#   ./shortcut.sh            # write ~/.local/share/applications/dynaman.desktop
#   ./shortcut.sh --remove   # delete it again
set -eu
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ENTRY="${XDG_DATA_HOME:-$HOME/.local/share}/applications/dynaman.desktop"
if [ "${1:-}" = "--remove" ]; then
	rm -f "$ENTRY"
	echo "removed $ENTRY"
	exit 0
fi
mkdir -p "$(dirname "$ENTRY")"
cat >"$ENTRY" <<EOF
[Desktop Entry]
Type=Application
Name=DynaMan
Comment=Last bomber standing — a Dynablaster-style battle game
Exec="$HERE/run.sh"
Path=$HERE
Icon=$HERE/icon.png
Terminal=false
Categories=Game;ArcadeGame;
StartupWMClass=DynaMan
EOF
chmod +x "$ENTRY"
echo "wrote $ENTRY — DynaMan is in your menu (./shortcut.sh --remove undoes it)"
SHORTCUT
	chmod +x "$stage/shortcut.sh"
	cat >"$stage/README.txt" <<README
DynaMan $VERSION — $plat
Last bomber standing: a lean, from-scratch Dynablaster-style battle game
for 1-4 players and bots.
Source code: https://github.com/b0realis/DynaMan

START
$start

$CONTROLS

LICENCE
  DynaMan is free software under the GNU General Public License v3.0 or
  later (LICENSE); its source is at the address above. It runs on the
  Godot Engine (MIT): the engine's licence and its third-party notices are
  in THIRD_PARTY_NOTICES.txt. Dynablaster and Bomberman are trademarks of
  their respective owners; DynaMan is a fan-made homage, not affiliated
  with or endorsed by them.
README
	(cd "$OUT" && zip -qr -X "$name.zip" "$name")
	echo "ok: $name.zip ($(du -h "$OUT/$name.zip" | cut -f1))"
}

package linux64 DynaMan.x86_64 \
'  Linux x86-64. Extract the folder anywhere and run ./run.sh (or
  DynaMan.x86_64 directly). ./shortcut.sh adds DynaMan to your application
  menu. Needs OpenGL 3.3 or OpenGL ES 3.0 graphics drivers.' \
'#!/bin/sh
# DynaMan launcher (Linux x86-64).
set -eu
cd -- "$(dirname -- "$0")"
exec ./DynaMan.x86_64 "$@"'

package steam-deck DynaMan.x86_64 \
'  Steam Deck / SteamOS: native Linux x86-64, no Proton needed.
  In Desktop Mode, extract the folder (for example to ~/Games/). In Steam:
  Games > Add a Non-Steam Game > Browse..., pick run.sh, add it. It starts
  full screen (switch it in OPTIONS) at the Deck'"'"'s 1280x800.
  The built-in controls are Player 1 (use the Gamepad layout in Steam
  Input): d-pad / left stick + A to bomb, the Menu button (START) pauses,
  the View button (BACK) quits to the menu, Y is rematch. Extra
  controllers are players 2-4. Not Steam Deck Verified; tested as a Linux
  build, not yet on a Deck in hand.' \
'#!/bin/sh
# Steam Deck / SteamOS launcher: full screen unless OPTIONS says
# otherwise (DYNAMAN_HANDHELD), the Deck'"'"'s 1280x800 panel, 60 fps.
set -eu
cd -- "$(dirname -- "$0")"
export DYNAMAN_HANDHELD=steam-deck
exec ./DynaMan.x86_64 --resolution 1280x800 --max-fps 60 "$@"'

package raspberry-pi5-arm64 DynaMan.arm64 \
'  Raspberry Pi 5 (or newer 64-bit ARM Linux): use a 64-bit desktop OS
  such as Raspberry Pi OS (64-bit) with its standard graphics drivers.
  Extract the folder and run ./run.sh from the desktop session — it runs
  on OpenGL ES 3. If needed: chmod +x run.sh DynaMan.arm64
  Not a 32-bit build. Built and checked as an ARM64 export; not yet
  played on a Pi in hand, so performance needs on-device testing.' \
'#!/bin/sh
# Raspberry Pi 5 launcher: OpenGL ES 3 (the Pi 5 offers desktop OpenGL
# 3.1, below the 3.3 Godot asks for first), 60 fps.
set -eu
cd -- "$(dirname -- "$0")"
exec ./DynaMan.arm64 --rendering-driver opengl3_es --max-fps 60 "$@"'

# The Deck launcher boots too (headless: it only proves run.sh is sound).
set +e
XDG_DATA_HOME="$SANDBOX/data" XDG_CONFIG_HOME="$SANDBOX/config" \
	timeout 8 "$OUT/DynaMan-$VERSION-steam-deck/run.sh" --headless >"$OUT/smoke-steam-deck.log" 2>&1
rc=$?
set -e
[ "$rc" = 124 ] || { echo "steam-deck run.sh failed (exit $rc)" >&2; exit 1; }

(cd "$OUT" && sha256sum DynaMan-"$VERSION"-*.zip >SHA256SUMS)
echo "== done: $OUT"
cat "$OUT/SHA256SUMS"
