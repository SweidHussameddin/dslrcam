#!/bin/zsh
# install.sh — set up dslrcam on a Mac: deps, scripts, config, OBS profile/scene, obs-websocket, auto-start LaunchAgent.
# Safe to re-run (updates scripts/OBS config in place, keeps your ~/.config/dslrcam/config).
set -eu

REPO=${0:A:h}
BIN=~/.local/bin
CONF_DIR=~/.config/dslrcam
OBS_DIR=~/Library/Application\ Support/obs-studio
AGENT=local.dslrcam-watch
AGENT_PLIST=~/Library/LaunchAgents/$AGENT.plist

[[ $(uname) == Darwin ]] || { echo "macOS only"; exit 1; }
command -v brew >/dev/null || { echo "Homebrew required: https://brew.sh"; exit 1; }
command -v python3 >/dev/null || { echo "python3 required: brew install python (or xcode-select --install)"; exit 1; }

echo "==> dependencies"
command -v gphoto2 >/dev/null || brew install gphoto2
[[ -d /Applications/OBS.app ]] || brew install --cask obs

echo "==> stopping any running dslrcam / OBS (OBS rewrites its config on exit)"
[[ -x $BIN/dslrcam ]] && $BIN/dslrcam disable >/dev/null 2>&1 || true
pkill -x OBS 2>/dev/null && sleep 2 || true

echo "==> scripts → $BIN"
mkdir -p $BIN
install -m 755 $REPO/bin/dslrcam $REPO/bin/dslrcam-watch $REPO/bin/obs-vcam $BIN/

echo "==> config → $CONF_DIR/config"
mkdir -p $CONF_DIR
[[ -f $CONF_DIR/config ]] || cp $REPO/config.example $CONF_DIR/config

echo "==> OBS profile + scene collection 'dslrcam'"
mkdir -p "$OBS_DIR/basic/profiles/dslrcam" "$OBS_DIR/basic/scenes" "$OBS_DIR/plugin_config/obs-websocket"
cp $REPO/obs/basic.ini "$OBS_DIR/basic/profiles/dslrcam/basic.ini"
cp $REPO/obs/dslrcam.json "$OBS_DIR/basic/scenes/dslrcam.json"

# user.ini: skip the first-run wizard, and no quit confirmation (it blocks `dslrcam stop`).
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
  1. Plug in the camera (USB), switch it on (video mode) — dslrcam starts automatically within a few seconds.
     Check with: tail -f /tmp/dslrcam-watch.log /tmp/dslrcam.out
  2. First time only: macOS asks to approve the OBS camera extension →
     System Settings ▸ General ▸ Login Items & Extensions ▸ Camera Extensions ▸ enable "OBS Virtual Camera".
     Then run `dslrcam stop` (the watcher restarts it with the virtual camera active).
  3. In FaceTime/Zoom/Meet pick "OBS Virtual Camera".
Settings (camera model, vendor filter): ~/.config/dslrcam/config
EOF
