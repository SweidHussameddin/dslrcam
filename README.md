# r50cam

Use a **Canon EOS R50** as a macOS webcam over a single USB-C cable — no Canon EOS Webcam Utility, no capture card.
Starts automatically when the camera is plugged in and switched on; latency is unnoticeable in FaceTime.

```
R50 ──USB──▶ gphoto2 (PTP live view, MJPEG) ──nc──▶ OBS media source (tcp listen, scaled to 1080p) ──▶ OBS Virtual Camera ──▶ FaceTime / Zoom / Meet
```

## Install

```sh
git clone https://github.com/SweidHussameddin/r50cam.git ~/IdeaProjects/r50cam
~/IdeaProjects/r50cam/install.sh
```

The installer (re-runnable) does:

- `brew install gphoto2` and `brew install --cask obs` (if missing)
- copies `bin/r50cam`, `bin/r50cam-watch`, `bin/obs-vcam` to `~/.local/bin` (must be on `PATH`)
- writes an OBS profile + scene collection named `r50cam` (`obs/`)
- OBS `user.ini`: skips the first-run wizard, sets `ConfirmOnExit=false`
- enables **obs-websocket** with password auth (password generated if none; read at runtime by `obs-vcam`)
- installs + loads the LaunchAgent `local.r50cam-watch` (`launchd/`)

Then, **once**:

1. Plug in the R50 and switch it on → r50cam starts within ~3 s.
2. macOS asks to approve the OBS camera extension: **System Settings ▸ General ▸ Login Items & Extensions ▸ Camera Extensions ▸ OBS Virtual Camera** → on.
3. Run `r50cam stop` — the watcher restarts it, now with the virtual camera live.
4. In your call app, pick **OBS Virtual Camera**.

If Canon's EOS Webcam Utility is installed, uninstall it first (its background service grabs the camera).

## Usage

| Command | What it does |
|---|---|
| *(plug in + switch on)* | auto-starts; unplug / switch off → stops (incl. OBS) |
| `r50cam` | run in the foreground manually (Ctrl-C stops everything) |
| `r50cam stop` | stop once — the watcher restarts it while the camera is connected |
| `r50cam disable` | turn auto-start off and stop the stream |
| `r50cam enable` | turn auto-start back on (persists across reboots) |
| `obs-vcam start\|stop\|status` | control the OBS Virtual Camera via obs-websocket |

Logs: `/tmp/r50cam-watch.log` (plug/unplug events), `/tmp/r50cam.log` (gphoto2), `/tmp/r50cam.out`.

Uninstall: `./uninstall.sh` (leaves OBS and gphoto2 installed).

## Camera tips

- Mode dial on **video**, Wi-Fi/Bluetooth off.
- While connected the camera streams live view continuously → battery drains in ~1 h and the body warms up. Use a dummy battery (**DR-E18 + PD-E1**) for all-day use.
- The Mac controls the camera while connected. To shoot/record to the SD card normally, unplug or `r50cam disable`.

## Why it's built this way (findings)

- **The R50 has no UVC (webcam) mode** — no firmware adds it. Over USB it only exposes PTP (`bInterfaceClass 6`) + a Canon vendor interface, so macOS never lists it as a camera on its own.
- **USB live view tops out at 1024×576 MJPEG, ~23 fps** (gphoto2 `liveviewsize=Large`; Medium = 512×288). OBS upscales to 1080p with Lanczos. Linux setups (gphoto2 + v4l2loopback) get the same source resolution. Real 4K needs an HDMI capture card (camera's micro-HDMI, clean output) instead of USB.
- Canon's EOS Webcam Utility: Basic = 720p, Pro (subscription) = 1080p; it holds the camera exclusively.
- **Latency:** an earlier H.264/UDP (mpegts) pipeline into the OBS media source added ~1.2 s. Sending the camera's MJPEG frames untouched over local TCP (OBS listening, `input_format=mjpeg`, `fflags=nobuffer probesize=32 analyzeduration=0`) brings OBS-side lag to ~0.2 s with no drift.
- **`--startvirtualcam` is unreliable on macOS** (the camera extension activates asynchronously), so `r50cam` also starts it via obs-websocket (`obs-vcam start`, stdlib-only Python client).
- **AppleScript `quit app "OBS"` gets cancelled** when OBS is minimized to the tray / has a confirm dialog → OBS is stopped with SIGTERM. OBS also only honours launch flags on a fresh start, so r50cam always restarts it.
- macOS's `ptpcamerad` grabs PTP cameras on connect → r50cam kills it before every gphoto2 session.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Only the OBS logo in the call app | Virtual camera not started: `obs-vcam status` → `obs-vcam start`, or `r50cam stop` to restart. After first approving the extension, OBS must be restarted. |
| `Could not claim the USB device` in `/tmp/r50cam.log` | Something else holds the camera (EOS Webcam Utility, Image Capture, Photos). Quit/uninstall it. |
| `R50 not detected` | Camera off, cable is charge-only, or mode dial not on video. Check `gphoto2 --auto-detect`. |
| Black / frozen image | Camera went to sleep or overheated — power-cycle it; the watcher restarts the stream. |
| Ports | gphoto2 → OBS on `127.0.0.1:23050`; obs-websocket on `4455` (password protected). |
