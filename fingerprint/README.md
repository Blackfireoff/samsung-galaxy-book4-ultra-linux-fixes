# Fingerprint: Egis/LighTuning 1c7a:05a1

Fix for the Egis/LighTuning fingerprint reader used by the tested Samsung 960XGL:

```text
Bus ... Device ...: ID 1c7a:05a1 LighTuning Technology Inc. ETU905A80-E
```

## Warning: Dual-Boot Fingerprint Storage

This fingerprint reader stores enrolled prints in the device itself. Windows Hello
and Linux `fprintd`/`libfprint` use the same device-side storage, not two fully
independent per-OS databases.

If you enroll or reset fingerprints in Windows, the Linux enrollments may be
deleted or made unusable. If you enroll or reset fingerprints in Linux, Windows
Hello may also need to be set up again. On the tested machine, dual-boot
coexistence is not reliable.

Before enabling fingerprint login or sudo on Linux, make sure you are willing to
re-enroll fingerprints after switching back to Windows Hello. Keep password login
available at all times.

## Problem

Ubuntu detects the device through `fprintd`, but the stock driver behaves incorrectly:

```text
Enroll result: enroll-completed
Verify result: verify-no-match
ListEnrolledFingers failed: NoEnrolledPrints: Failed to discover prints
```

The log shows:

```text
Device reported an error during verify: Print was not found on the devices storage.
Deleted stored finger 7 for user ... as it is unknown to device.
```

This is not a PAM/GDM issue. The fingerprint template is not persisted correctly by the stock `egismoc` path.

## Fix

Use the SDCP-enabled `egismoc` libfprint fork:

```text
https://github.com/TenSeventy7/libfprint-egismoc-sdcp
```

The install script clones that fork at a tested commit, applies a small Meson patch so `egismoc` links against OpenSSL, builds only the `egismoc` driver, and installs `libfprint-2.so.2` into `/usr/local/lib/...`.

It does not overwrite the Ubuntu package files in `/usr/lib`.

## Install

Install build dependencies:

```sh
sudo apt update
sudo apt install -y git meson ninja-build build-essential pkg-config \
  libglib2.0-dev libgusb-dev libssl-dev libudev-dev libusb-1.0-0-dev
```

Build and install the patched libfprint:

```sh
/path/to/repo/fingerprint/scripts/install-egismoc-sdcp-libfprint.sh
```

Confirm `fprintd` resolves `/usr/local`:

```sh
ldd /usr/libexec/fprintd | grep fprint
```

Expected:

```text
libfprint-2.so.2 => /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2
```

## Test

Do not enable login/PAM until this test works.

```sh
/path/to/repo/fingerprint/scripts/test-egismoc-sdcp-fingerprint.sh
```

Validated behavior:

```text
Verification 1:
Verify result: verify-match (done)

Verification 2, after a fresh fprintd restart:
Verify result: verify-match (done)
```

## Enable Login And Sudo

Only after two successful `fprintd-verify` checks:

```sh
/path/to/repo/fingerprint/scripts/enable-fingerprint-auth.sh
```

Test order:

```text
1. Lock the current GNOME session and unlock with fingerprint.
2. Test sudo in a new terminal.
3. Reboot only after both tests work.
```

`fprintd.service` is D-Bus activated; it does not need to be enabled manually.

## Rollback

Disable PAM fingerprint auth:

```sh
/path/to/repo/fingerprint/scripts/disable-fingerprint-auth.sh
```

Remove the `/usr/local` libfprint override and return to Ubuntu's packaged libfprint:

```sh
/path/to/repo/fingerprint/scripts/rollback-egismoc-sdcp-libfprint.sh
```
