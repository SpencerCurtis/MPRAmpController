#!/usr/bin/env bash
#
# Build MPRAmpController on this (modern Swift) machine and ship it to the
# Catalina x86_64 Mac mini. async/await back-deploys to macOS 10.15, but the
# 5.5+ compiler that understands it only runs on macOS 11+, so we build here
# and cross-compile, bundling the Swift concurrency back-deployment dylib that
# Catalina's /usr/lib/swift does not have.
#
# Usage: scripts/deploy-to-mini.sh [debug|release]
#
set -euo pipefail

MINI="${MINI:-spencercurtis@Spencers-Mac-mini.local}"
REMOTE_DIR="${REMOTE_DIR:-/tmp/mprampcontroller}"
CONFIG="${1:-debug}"

echo "==> Building Run for x86_64-apple-macosx10.15 ($CONFIG)"
swift build --arch x86_64 -c "$CONFIG"

BIN=".build/x86_64-apple-macosx/$CONFIG/Run"
[ -x "$BIN" ] || { echo "error: build did not produce $BIN" >&2; exit 1; }

TOOLCHAIN="$(dirname "$(dirname "$(xcrun -f swiftc)")")"
CONC="$TOOLCHAIN/lib/swift-5.5/macosx/libswift_Concurrency.dylib"
[ -f "$CONC" ] || { echo "error: concurrency dylib not found at $CONC" >&2; exit 1; }

SHIP="$(mktemp -d)"
trap 'rm -rf "$SHIP"' EXIT
cp "$BIN" "$SHIP/Run"
cp "$CONC" "$SHIP/"
# The binary's baked-in rpaths point at this machine's Xcode toolchain, which
# does not exist on the mini; make it also look next to itself for the dylib.
install_name_tool -add_rpath @executable_path "$SHIP/Run" 2>/dev/null || true

LABEL=com.spencercurtis.mprampcontroller

echo "==> Shipping to ${MINI}:${REMOTE_DIR}"
ssh "$MINI" "mkdir -p '$REMOTE_DIR'"
# Stop the managed agent (or any stray instance) so the running binary isn't busy.
ssh "$MINI" "launchctl bootout gui/\$(id -u)/$LABEL 2>/dev/null; pkill -9 -x Run 2>/dev/null; true"
scp -q "$SHIP/Run" "$SHIP/libswift_Concurrency.dylib" "$MINI:$REMOTE_DIR/"
# Ship the web UI (served from Public/ relative to the working directory).
[ -d Public ] && scp -q -r Public "$MINI:$REMOTE_DIR/"
# Restart the LaunchAgent if it's installed.
ssh "$MINI" "test -f ~/Library/LaunchAgents/$LABEL.plist && launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/$LABEL.plist 2>/dev/null; true"

echo "==> Done."
echo "    Run it:   ssh $MINI 'cd $REMOTE_DIR && ./Run'"
echo "    Stop it:  ssh $MINI 'pkill -9 -f $REMOTE_DIR/Run'   (do not 'wait' on it; RunLoop.main never returns)"
