#!/bin/zsh
# uninstall.sh — remove r50cam scripts, LaunchAgent and the OBS r50cam profile/scene.
# Leaves OBS, gphoto2 and the obs-websocket setting alone (they may be used elsewhere).
set -u

BIN=~/.local/bin
OBS_DIR=~/Library/Application\ Support/obs-studio
AGENT=local.r50cam-watch

[[ -x $BIN/r50cam ]] && $BIN/r50cam disable
launchctl bootout gui/$UID/$AGENT 2>/dev/null
rm -f ~/Library/LaunchAgents/$AGENT.plist
rm -f $BIN/r50cam $BIN/r50cam-watch $BIN/obs-vcam
rm -rf "$OBS_DIR/basic/profiles/r50cam"
rm -f "$OBS_DIR/basic/scenes/r50cam.json" "$OBS_DIR/basic/scenes/r50cam.json.bak"
rm -f /tmp/r50cam.log /tmp/r50cam.out /tmp/r50cam-watch.log

echo "r50cam removed. To also remove the tools: brew uninstall gphoto2 && brew uninstall --cask obs"
