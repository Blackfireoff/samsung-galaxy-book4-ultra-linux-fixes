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
acpi/         BAT1 battery DSDT override for boot-without-charger detection
fingerprint/  Egis/LighTuning 1c7a:05a1 fingerprint fix using libfprint SDCP
```

## Status

The ACPI BAT1 override was tested successfully: Linux loads the DSDT table from initrd, reports `ACPI: Table Upgrade`, and creates `/sys/class/power_supply/BAT1` when booting without the charger.

The fingerprint fix was tested successfully: `fprintd` resolves `/usr/local/lib/.../libfprint-2.so.2`, enrollment persists after `fprintd` restart, and two consecutive `fprintd-verify` calls return `verify-match`.

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
acpi/README.md
fingerprint/README.md
```
