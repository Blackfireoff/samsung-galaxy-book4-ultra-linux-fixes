# DSDT BAT1 Override Test

This is a reversible test path for Ubuntu kernel `7.0.0-15-generic`. It leaves the normal initrd unchanged and creates a separate test initrd.

```sh
/boot/initrd.img-7.0.0-15-generic-dsdt-bat1-v2
```

## Current Artifacts

`dsdt-patched.dsl` compiles with:

```sh
iasl -tc dsdt-patched.dsl
```

The generated files are:

```sh
dsdt-patched.aml
acpi_override.cpio
acpi-override/kernel/firmware/acpi/DSDT.aml
```

`/boot/config-7.0.0-15-generic` has:

```text
CONFIG_ACPI_TABLE_UPGRADE=y
```

## Install Test Initrd

Run from this directory:

```sh
sudo ./install-dsdt-test-initrd-v2.sh
```

The script creates a backup if missing:

```sh
/boot/initrd.img-7.0.0-15-generic.pre-dsdt-bat1-backup
```

It does not change GRUB config and refuses to overwrite an existing test initrd.

## One-Time GRUB Boot

Boot without the charger only for the actual validation.

1. Reboot and show the GRUB menu.
2. Highlight the normal Ubuntu entry for `7.0.0-15-generic`.
3. Press `e`.
4. Find the line beginning with `initrd`.
5. Replace only the initrd filename with the test initrd filename:

```text
initrd /boot/initrd.img-7.0.0-15-generic-dsdt-bat1-v2
```

If the existing line does not include `/boot/`, keep the same style and only add `-dsdt-bat1` to the filename.

6. Boot with `Ctrl+x` or `F10`.

## Rollback

If the test boot fails, reboot and use the normal GRUB entry without editing it. The normal initrd is unchanged.

From a working boot, remove the test file with:

```sh
sudo rm -f /boot/initrd.img-7.0.0-15-generic-dsdt-bat1-v2
```

If recovery from a live USB is needed:

1. Mount the Ubuntu root filesystem.
2. If `/boot` is separate, mount it too.
3. Delete only:

```sh
/boot/initrd.img-7.0.0-15-generic-dsdt-bat1-v2
```

No BIOS change is involved.

## Validate After Boot Without Charger

Run:

```sh
./verify-bat1-after-boot.sh
```

Expected signs of success:

```text
BAT1 appears in /sys/class/power_supply
/org/freedesktop/UPower/devices/battery_BAT1 appears in upower -e
dmesg mentions an ACPI table upgrade/override for DSDT
```

## Permanent Install

After the one-time GRUB test is validated, install permanently through dracut:

```sh
sudo ./install-dsdt-permanent.sh
```

This installs:

```sh
/etc/acpi/samsung-bat1-dsdt/DSDT.aml
/etc/dracut.conf.d/99-samsung-bat1-dsdt.conf
```

Then it regenerates the normal initrd:

```sh
/boot/initrd.img-7.0.0-15-generic
```

Rollback from a working boot:

```sh
sudo ./uninstall-dsdt-permanent.sh
```

Emergency rollback from GRUB: edit the normal Ubuntu entry and replace:

```text
initrd.img-7.0.0-15-generic
```

with:

```text
initrd.img-7.0.0-15-generic.pre-dsdt-bat1-permanent-backup
```
