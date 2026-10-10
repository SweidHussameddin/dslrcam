# dslrcam

Use your **DSLR / mirrorless camera as a macOS webcam over a single USB cable** — no vendor webcam app
(Canon EOS Webcam Utility, Nikon Webcam Utility, Sony Imaging Edge Webcam…), no capture card, no subscription.

- **Plug-and-play:** starts automatically when the camera is plugged in and switched on, stops when it's unplugged.
- **Low latency:** camera frames go into OBS untouched — no visible delay in FaceTime.
- Works in any app that takes a webcam (FaceTime, Zoom, Meet, Teams, Slack, browser) via **OBS Virtual Camera**.

```
camera ──USB──▶ gphoto2 (PTP live view, MJPEG) ──nc──▶ OBS media source (local TCP, scaled to 1080p) ──▶ OBS Virtual Camera ──▶ your call app
```

> Not affiliated with Canon, Nikon, Sony or OBS Project. Camera names are trademarks of their owners.

## Compatibility

Any camera whose **USB live view** works with [libgphoto2](http://www.gphoto.org/proj/libgphoto2/support.php) should work.
Check yours before installing (quit any vendor app first):

```sh
brew install gphoto2
gphoto2 --auto-detect                                   # camera listed?
gphoto2 --capture-movie=3s --stdout > /tmp/test.mjpg    # non-empty file = live view works
```

| Camera | Status | Live view resolution | Notes |
|---|---|---|---|
| Canon EOS R50 | ✅ tested (macOS 27, Apple Silicon, OBS 32) | 1024×576 @ ~23 fps | `LIVEVIEW_SIZE=Large` |

Tried another camera? Please open an issue or PR with the result so this table grows.

**About resolution:** over USB, cameras only send their live-view preview, not the full sensor video. On the EOS R50
that is 1024×576, which OBS upscales to 1080p (Lanczos) — it looks clean, but it is not true 1080p/4K.
Vendor apps hit the same limit (Canon's free tier outputs 720p, the paid tier 1080p). For real 4K, use the camera's
HDMI output with a UVC capture card instead — macOS treats that as a normal webcam, no software needed.

## Install

Requires macOS, [Homebrew](https://brew.sh) and Python 3.

```sh
git clone https://github.com/SweidHussameddin/dslrcam.git
cd dslrcam && ./install.sh
```

The installer (safe to re-run) does:

- `brew install gphoto2` and `brew install --cask obs` (if missing)
- copies `bin/dslrcam`, `bin/dslrcam-watch`, `bin/obs-vcam` to `~/.local/bin` (must be on your `PATH`)
- creates `~/.config/dslrcam/config` from [`config.example`](config.example) (kept on re-install)
- writes an OBS profile + scene collection named `dslrcam` (`obs/`)
- OBS `user.ini`: skips the first-run wizard, sets `ConfirmOnExit=false`
- enables **obs-websocket** with password auth (see [Security](#security))
- installs and loads the LaunchAgent `local.dslrcam-watch` (`launchd/`)

Then, **once**:

1. Plug in the camera, switch it on (video mode) → dslrcam starts within a few seconds.
2. macOS asks to approve the OBS camera extension: **System Settings ▸ General ▸ Login Items & Extensions ▸ Camera Extensions ▸ OBS Virtual Camera** → on.
3. Run `dslrcam stop` — the watcher restarts it, now with the virtual camera live.
4. In your call app, pick **OBS Virtual Camera**.

If a vendor webcam utility is installed, uninstall it first — its background service grabs the camera.

## Usage

| Command | What it does |
|---|---|
| *(plug in + switch on)* | auto-starts; unplug / switch off → stops (incl. OBS) |
| `dslrcam` | run in the foreground manually (Ctrl-C stops everything) |
| `dslrcam detect` | show which camera would be used |
| `dslrcam stop` | stop once — the watcher restarts it while the camera is connected |
| `dslrcam disable` | turn auto-start off and stop the stream |
| `dslrcam enable` | turn auto-start back on (persists across reboots) |
| `obs-vcam start\|stop\|status` | control the OBS Virtual Camera via obs-websocket |

Settings in `~/.config/dslrcam/config`:

| Setting | Default | Meaning |
|---|---|---|
| `CAMERA_MODEL` | *(empty = first camera)* | substring of the model name from `gphoto2 --auto-detect` |
| `LIVEVIEW_SIZE` | `Large` | Canon EOS live view size; ignored by other cameras |
| `USB_VENDOR_IDS` | *(empty = any)* | only auto-start for these USB vendor IDs, e.g. `04a9` (Canon) |

Logs: `/tmp/dslrcam-watch.log` (plug/unplug events), `/tmp/dslrcam.out` (dslrcam output), `/tmp/dslrcam.log` (gphoto2).

Uninstall: `./uninstall.sh` (leaves OBS and gphoto2 installed).

## Camera tips

- Mode dial on **video**, Wi-Fi/Bluetooth off, auto power-off disabled.
- While connected the camera streams live view continuously → battery drains fast and the body warms up.
  Use a **dummy battery / USB-PD power adapter** for long sessions.
- The Mac controls the camera while connected. To shoot or record to the card normally, unplug or `dslrcam disable`.

## How it works / design notes

- Most cameras have **no UVC (webcam) mode** over USB — they expose PTP (USB class 6) for photo transfer and remote
  control. `gphoto2 --capture-movie --stdout` pulls the live-view preview as an MJPEG stream.
- **Latency:** an H.264/UDP (mpegts) pipeline into the OBS media source added ~1.2 s. Sending the camera's MJPEG
  frames untouched over local TCP (OBS listening, `input_format=mjpeg`, `fflags=nobuffer probesize=32
  analyzeduration=0`) brings the OBS-side lag to ~0.2 s, with no drift.
- **`--startvirtualcam` is unreliable on macOS** (the camera extension activates asynchronously), so dslrcam also
  starts it through obs-websocket (`obs-vcam`, a stdlib-only Python client).
- **AppleScript `quit app "OBS"` gets cancelled** when OBS is minimized to the tray or shows a confirm dialog, so OBS
  is stopped with SIGTERM. OBS only honours launch flags on a fresh start, so dslrcam always restarts it.
- macOS's `ptpcamerad` claims PTP cameras on connect → dslrcam kills it before every gphoto2 session.
- The watcher polls `ioreg` every 3 s for a USB interface of class 6 (Still Image) from a non-Apple vendor, so iPhones
  don't trigger it. Before launching OBS, dslrcam checks that the camera actually delivers live view; if not, it
  ignores the device until it's reconnected.

## Security

The installer enables OBS's **obs-websocket** server (port 4455, password protected, password generated at install
time and stored in OBS's own config). It listens on all network interfaces, so anyone on your network who knows the
password could control OBS. If that matters to you, block incoming connections to OBS in the macOS firewall. The
camera stream itself only uses `127.0.0.1:23050`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Only the OBS logo in the call app | Virtual camera not started: `obs-vcam status` → `obs-vcam start`, or `dslrcam stop` to restart. After approving the extension for the first time, OBS must be restarted. |
| `Could not claim the USB device` in `/tmp/dslrcam.log` | Another app holds the camera (vendor webcam utility, Image Capture, Photos). Quit or uninstall it. |
| `no camera detected` | Camera off, charge-only cable, or wrong `CAMERA_MODEL`. Check `gphoto2 --auto-detect`. |
| `no live view over USB … not supported` | Your camera/firmware doesn't support gphoto2 live view. Try another USB mode in the camera menu (e.g. "PC Remote"), or use HDMI capture. |
| Black / frozen image | Camera went to sleep or overheated — power-cycle it; the watcher restarts the stream. |

## License

[MIT](LICENSE)
