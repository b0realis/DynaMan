#!/usr/bin/env bash
## DynaMan test ritual (v4.5, bot probe v4.6, dir-snapshot v7.6): the logic
## suite plus every behaviour probe, with the player's ENTIRE user-data dir
## backed up first and restored no matter what — probes mutate live Settings
## AND touch npcs.cfg / story.cfg / worlds/, and a crashed (or leaky) probe
## must never leak its test data into someone's save.
## v11.7: single-run lock, verified backup, and a trap that stops the
## running probe before restoring (signals used to leave it writing).
## Usage: tests/run_all.sh   (override the engine with GODOT=/path)
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The engine: $GODOT if set, else a Godot 4 on PATH, else a godot/ folder
# next to the project (Godot_v4*_linux.x86_64).
GODOT="${GODOT:-$(command -v godot4 || command -v godot \
	|| ls "$DIR"/../godot/Godot_v4*_linux.x86_64 2>/dev/null | tail -1 || true)}"
GODOT="${GODOT:-godot}"
DATADIR="$HOME/.local/share/godot/app_userdata/DynaMan"
# One run at a time (v11.7): a second run would back up the first
# run's half-mutated data and "restore" THAT as the player's save.
exec 9>"${TMPDIR:-/tmp}/dynaman_tests.lock"
if ! flock -n 9; then
	echo "another DynaMan test run is in progress — not starting"
	exit 2
fi
BAKDIR="$(mktemp -d)" || { echo "mktemp failed — not starting"; exit 2; }
HADDATA=0
if [ -d "$DATADIR" ]; then
	HADDATA=1
	# A partial backup must never be the thing we restore over the
	# real save — refuse to run instead (the trap isn't armed yet).
	if ! cp -a "$DATADIR/." "$BAKDIR/"; then
		echo "could not back up $DATADIR — not starting"
		rm -rf "$BAKDIR"
		exit 2
	fi
fi
echo "(user data backed up in $BAKDIR until the run ends)"
CHILD=""
restore() {
	trap '' INT TERM HUP   # a second Ctrl-C must not abort a half-restore
	# A probe still running would write into the restored save (its
	# debounced/exit-time Settings save, npcs.cfg): stop it FIRST.
	if [ -n "$CHILD" ]; then
		kill "$CHILD" 2>/dev/null
		wait "$CHILD" 2>/dev/null
	fi
	rm -rf "$DATADIR"
	if [ "$HADDATA" = "1" ]; then
		mkdir -p "$DATADIR"
		if cp -a "$BAKDIR/." "$DATADIR/"; then
			rm -rf "$BAKDIR"
		else
			echo "RESTORE FAILED — your data is safe in $BAKDIR"
		fi
	else
		rm -rf "$BAKDIR"
	fi
}
trap restore EXIT
# Ctrl-C / kill: `timeout` runs Godot in its own process group, so the
# signal never reaches the probe — exit through the trap, which stops it.
trap 'exit 130' INT TERM HUP

fail=0
check() {  # check <timeout-seconds> <label> <godot-args...>
	local t="$1" label="$2" rc
	shift 2
	timeout "$t" "$GODOT" --headless --path "$DIR" "$@" >/dev/null 2>&1 &
	CHILD=$!
	wait "$CHILD"
	rc=$?
	CHILD=""
	if [ "$rc" = "0" ]; then
		echo "ok    $label"
	else
		echo "FAIL  $label (exit $rc)"
		fail=1
	fi
}

check 120 logic_test           --script tests/logic_test.gd
check 90  enemy_probe          res://tests/enemy_probe.tscn
check 90  portal_probe         res://tests/portal_probe.tscn
check 150 portal_punish_probe  res://tests/portal_punish_probe.tscn
check 240 ai_probe             res://tests/ai_probe.tscn
check 120 bot_probe            res://tests/bot_probe.tscn
check 90  fill_bots_probe      res://tests/fill_bots_probe.tscn
check 120 menagerie_probe      res://tests/menagerie_probe.tscn
check 120 series_probe         res://tests/series_probe.tscn
check 60  feel_probe           res://tests/feel_probe.tscn
check 60  smooth_probe         res://tests/smooth_probe.tscn
check 60  arena_probe          res://tests/arena_probe.tscn
check 60  controls_probe       res://tests/controls_probe.tscn
check 90  pad_probe            res://tests/pad_probe.tscn
check 90  party_probe          res://tests/party_probe.tscn
exit $fail
