# Camera: OV02C10 / IPU6 libcamera Fix

Webcam notes for the Samsung 960XGL / Galaxy Book4 Ultra internal MIPI camera:

```text
Sensor: OV02C10 / OVTI02C1
Path:   \_SB_.PC00.LNK0
Stack:  IVSC -> OV02C10 -> Intel IPU6 ISYS -> libcamera Simple pipeline -> camera-relay
```

## Credits

This camera fix comes from [@Andycodeman](https://github.com/Andycodeman)'s
work in [Andycodeman/samsung-galaxy-book-linux-fixes](https://github.com/Andycodeman/samsung-galaxy-book-linux-fixes).

This repository only documents the tested method and the color tuning used on
the tested 960XGL machine. Use the upstream repository for the actual webcam
installer and future fixes.

## Install

Clone the upstream repository:

```sh
mkdir -p ~/Git
cd ~/Git
git clone https://github.com/Andycodeman/samsung-galaxy-book-linux-fixes.git
cd samsung-galaxy-book-linux-fixes
```

For the issue #45 fix, use the branch that hardens the `libcamerasrc` fallback:

```sh
git fetch origin
git checkout fix-issue-45-libcamerasrc-fallback
```

If that branch has already been merged upstream, use `main` instead:

```sh
git checkout main
git pull
```

Run the libcamera webcam installer:

```sh
cd ~/Git/samsung-galaxy-book-linux-fixes/webcam-fix-libcamera
./install.sh
```

Restart the relay after install:

```sh
systemctl --user enable --now camera-relay
systemctl --user status camera-relay --no-pager
```

Verify that libcamera and GStreamer see the camera:

```sh
cam -l
gst-inspect-1.0 libcamerasrc | head -20
```

Expected signs of a good install:

```text
Available cameras:
1: Internal front camera (\_SB_.PC00.LNK0)

Filename /usr/local/lib/x86_64-linux-gnu/gstreamer-1.0/libgstlibcamera.so
```

The relay exposes the camera to standard V4L2 apps as:

```text
/dev/video0: Camera Relay
```

## Color Tuning

The upstream installer ships an `ov02c10.yaml` tuning file. On the tested
machine, the default color correction matrix made the image too purple/dim in
low light. The best result was:

```text
[1/18] No CCM (raw baseline)
No color correction - raw debayer + AWB only. Very desaturated.
```

Use the upstream tuning helper:

```sh
cd ~/Git/samsung-galaxy-book-linux-fixes/webcam-fix-book5
./tune-ccm.sh ov02c10
```

Even though the helper lives under `webcam-fix-book5`, it supports `ov02c10`.
Close OBS, Discord, Brave, Firefox, and any other camera app before tuning.
After selecting a preset, restart the relay:

```sh
systemctl --user restart camera-relay
```

If OBS keeps showing old colors, remove and re-add the video capture source or
restart OBS. OBS can keep the old V4L2 stream open while the tuning file changes.

## Manual No-CCM Tuning

If the tuning helper is unavailable, install the No-CCM baseline manually:

```sh
sudo tee /usr/local/share/libcamera/ipa/simple/ov02c10.yaml >/dev/null <<'EOF'
# SPDX-License-Identifier: CC0-1.0
%YAML 1.1
---
version: 1
algorithms:
  - BlackLevel:
  - Awb:
  - Adjust:
  - Agc:
...
EOF

sudo cp /usr/local/share/libcamera/ipa/simple/ov02c10.yaml \
  /usr/share/libcamera/ipa/simple/ov02c10.yaml

rm -rf ~/.cache/gstreamer-1.0
systemctl --user restart camera-relay
```

## Diagnostics

Check that the source-built libcamera path is being used:

```sh
gst-inspect-1.0 libcamerasrc | grep -E 'Filename|Version'
strings /usr/local/lib/x86_64-linux-gnu/libcamera/ipa/ipa_soft_simple.so | grep -i CameraSensorHelperOv02c10
journalctl --user -u camera-relay -n 120 --no-pager
```

Good relay logs should include:

```text
libcamera v0.7.0+dirty
Using tuning file /usr/local/share/libcamera/ipa/simple/ov02c10.yaml
IPASoft: Exposure ..., gain ...
```

If `gst-inspect-1.0 libcamerasrc` cannot find the plugin after install, clear
the GStreamer registry cache and restart the relay:

```sh
rm -rf ~/.cache/gstreamer-1.0
systemctl --user restart camera-relay
```
