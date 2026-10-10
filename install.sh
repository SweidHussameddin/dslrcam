#!/bin/zsh
# install.sh — set up r50cam on a Mac: deps, scripts, OBS profile/scene, obs-websocket, auto-start LaunchAgent.
# Safe to re-run (updates scripts/config in place).
set -eu

REPO=${0:A:h}
BIN=~/.local/bin
OBS_DIR=~/Library/Application\ Support/obs-studio
AGENT=local.r50cam-watch
AGENT_PLIST=~/Library/LaunchAgents/$AGENT.plist

[[ $(uname) == Darwin ]] || { echo "macOS only"; exit 1; }
command -v brew >/dev/null || { echo "Homebrew required: https://brew.sh"; exit 1; }
command -v python3 >/dev/null || { echo "python3 required: brew install python (or xcode-select --install)"; exit 1; }

echo "==> dependencies"
command -v gphoto2 >/dev/null || brew install gphoto2
[[ -d /Applications/OBS.app ]] || brew install --cask obs

echo "==> stopping any running r50cam / OBS (OBS rewrites its config on exit)"
[[ -x $BIN/r50cam ]] && $BIN/r50cam disable >/dev/null 2>&1 || true
pkill -x OBS 2>/dev/null && sleep 2 || true

echo "==> scripts → $BIN"
mkdir -p $BIN
install -m 755 $REPO/bin/r50cam $REPO/bin/r50cam-watch $REPO/bin/obs-vcam $BIN/

echo "==> OBS profile + scene collection 'r50cam'"
mkdir -p "$OBS_DIR/basic/profiles/r50cam" "$OBS_DIR/basic/scenes" "$OBS_DIR/plugin_config/obs-websocket"
cp $REPO/obs/basic.ini "$OBS_DIR/basic/profiles/r50cam/basic.ini"
cp $REPO/obs/r50cam.json "$OBS_DIR/basic/scenes/r50cam.json"

# user.ini: skip the first-run wizard, and no quit confirmation (it blocks r50cam stop).
# obs-websocket: enable with password auth (obs-vcam reads the password from this file).
python3 -I - "$OBS_DIR" <<'PY'
import configparser, json, os, secrets, sys
obs = sys.argv[1]

ini_path = os.path.join(obs, "user.ini")
ini = configparser.ConfigParser(interpolation=None)
ini.optionxform = str
ini.read(ini_path, encoding="utf-8-sig")
if not ini.has_section("General"):
    ini.add_section("General")
ini["General"].setdefault("FirstRun", "true")
ini["General"]["ConfirmOnExit"] = "false"
with open(ini_path, "w") as f:
    ini.write(f, space_around_delimiters=False)

ws_path = os.path.join(obs, "plugin_config", "obs-websocket", "config.json")
ws = json.load(open(ws_path)) if os.path.exists(ws_path) else {}
ws.setdefault("server_port", 4455)
ws["server_enabled"] = True
ws["auth_required"] = True
ws["alerts_enabled"] = False
ws["first_load"] = False
if not ws.get("server_password"):
    ws["server_password"] = secrets.token_urlsafe(16)
with open(ws_path, "w") as f:
    json.dump(ws, f, indent=2)
PY

echo "==> LaunchAgent $AGENT (auto-start on camera plug-in)"
mkdir -p ~/Library/LaunchAgents
sed "s|__HOME__|$HOME|g" $REPO/launchd/$AGENT.plist > $AGENT_PLIST
plutil -lint $AGENT_PLIST >/dev/null
launchctl bootout gui/$UID/$AGENT 2>/dev/null || true
launchctl bootstrap gui/$UID $AGENT_PLIST

[[ :$PATH: == *:$BIN:* ]] || echo "note: add $BIN to your PATH (e.g. in ~/.zshrc)"

cat <<'EOF'

Done. Next:
  1. Plug in the R50 (USB-C) and switch it on — r50cam starts automatically within ~3 s.
  2. First time only: macOS asks to approve the OBS camera extension →
     System Settings ▸ General ▸ Login Items & Extensions ▸ Camera Extensions ▸ enable "OBS Virtual Camera".
     Then run `r50cam stop` (the watcher restarts it with the virtual camera active).
  3. In FaceTime/Zoom/Meet pick "OBS Virtual Camera".
EOF
