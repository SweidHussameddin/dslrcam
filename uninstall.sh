#!/bin/zsh
# uninstall.sh — remove dslrcam scripts, config, LaunchAgent and the OBS dslrcam profile/scene.
# Leaves OBS, gphoto2 and the obs-websocket setting alone (they may be used elsewhere).
set -u

BIN=~/.local/bin
OBS_DIR=~/Library/Application\ Support/obs-studio
AGENT=local.dslrcam-watch

[[ -x $BIN/dslrcam ]] && $BIN/dslrcam disable
launchctl bootout gui/$UID/$AGENT 2>/dev/null
rm -f ~/Library/LaunchAgents/$AGENT.plist
rm -f $BIN/dslrcam $BIN/dslrcam-watch $BIN/obs-vcam
rm -rf ~/.config/dslrcam
rm -rf "$OBS_DIR/basic/profiles/dslrcam"
rm -f "$OBS_DIR/basic/scenes/dslrcam.json" "$OBS_DIR/basic/scenes/dslrcam.json.bak"
rm -f /tmp/dslrcam.log /tmp/dslrcam.out /tmp/dslrcam-watch.log

echo "dslrcam removed. To also remove the tools: brew uninstall gphoto2 && brew uninstall --cask obs"
