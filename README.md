# Samsung Galaxy Book4 Ultra Linux Fixes

Linux fixes tested on a Samsung Galaxy Book / 960XGL class machine.

Tested system:

```text
Laptop: Samsung Galaxy Book / Samsung 960XGL
Model:  NP964XGL-XG3FR
BIOS:   P10ALX.470.260413.05, 2026-04-13
OS:     Ubuntu resolute
Kernel: 7.0.0-15-generic
```

This repository is intentionally split by subsystem:

```text
acpi/              BAT1 battery DSDT override for boot-without-charger detection
camera/            OV02C10/IPU6 webcam notes, upstream install, and color tuning
fingerprint/       Egis/LighTuning 1c7a:05a1 fingerprint fix using libfprint SDCP
samsung-settings/  Safe Linux controls for Samsung Settings-like features when exposed by the kernel
```

See `HARDWARE_STATUS.md` for the tested hardware matrix, known limitations,
and the diagnostics to include when opening a new issue.

## Status

The ACPI BAT1 override was tested successfully: Linux loads the DSDT table from initrd, reports `ACPI: Table Upgrade`, and creates `/sys/class/power_supply/BAT1` when booting without the charger.

The fingerprint fix was tested successfully: `fprintd` resolves `/usr/local/lib/.../libfprint-2.so.2`, enrollment persists after `fprintd` restart, and two consecutive `fprintd-verify` calls return `verify-match`.

The camera fix was tested successfully using [@Andycodeman](https://github.com/Andycodeman)'s
[samsung-galaxy-book-linux-fixes](https://github.com/Andycodeman/samsung-galaxy-book-linux-fixes)
repository: libcamera detects the internal OV02C10 camera, `camera-relay`
exposes it as a standard V4L2 device, and the preferred color tuning on this
machine is the `No CCM (raw baseline)` preset.

## Safety

Do not install another person's prebuilt `DSDT.aml`. Generate and patch your own DSDT from your own BIOS.

Raw ACPI dumps are intentionally ignored because they are machine-specific and may contain sensitive data. In particular, `msdm.dat` can expose a Windows OEM product key.

Both fixes include rollback scripts. Use the one-time ACPI initrd test before making the DSDT override permanent, and do not enable fingerprint PAM login until `fprintd-verify` works after a `fprintd` restart.

The fingerprint reader stores enrolled prints in the device itself. Windows Hello
and Linux may overwrite or invalidate each other's enrollments, so dual-boot
fingerprint use is not reliable on the tested machine. Keep password login
available.

## Quick Links

Start with the subsystem README:

```text
HARDWARE_STATUS.md
acpi/README.md
camera/README.md
fingerprint/README.md
samsung-settings/README.md
```
