# Samsung Galaxy Book 960XGL BAT1 ACPI DSDT Override

Fix for a Samsung Galaxy Book 960XGL where Linux only detects the internal battery if the laptop boots with the AC adapter plugged in.

This repository documents and packages a tested ACPI DSDT override for one specific machine/firmware combination:

```text
Laptop: Samsung Galaxy Book / Samsung 960XGL
Model:  NP964XGL-XG3FR
BIOS:   P10ALX.470.260413.05, 2026-04-13
OS:     Ubuntu resolute
Kernel: 7.0.0-15-generic
```

Do not apply this blindly to another laptop, another BIOS revision, or another DSDT. A bad DSDT override can break boot or devices.

## Problem

When Ubuntu boots without the charger connected, Linux sees the ACPI battery device object, but no battery power supply is created:

```text
$ ls /sys/class/power_supply
ucsi-source-psy-USBC000:001  ucsi-source-psy-USBC000:002

$ cat /sys/bus/acpi/devices/PNP0C0A:00/status
31

$ cat /sys/bus/acpi/devices/PNP0C0A:00/path
\_SB_.PC00.LPCB.H_EC.BAT1
```

When Ubuntu boots with the charger connected, `BAT1` appears normally:

```text
ADP1  BAT1  ucsi-source-psy-USBC000:001  ucsi-source-psy-USBC000:002
```

## Root Cause

The DSDT contains `Device (BAT1)`. Its `_STA` method has Samsung-specific logic that can return `Zero`, which tells ACPI that the battery device is absent/disabled:

```asl
If ((LINX != One))
{
    If (((WDC0 == 0x81) && (ACEX != PWRS)))
    {
        WDC2 = 0x81
        Return (Zero)
    }
}
```

On affected boots, Linux sees the ACPI object but the battery driver never creates `/sys/class/power_supply/BAT1`.

## Fix

The patched DSDT removes only that battery-hiding branch from `BAT1._STA`, so the method continues to report the battery present when `B1EX == One`.

The patched table also includes compile-only fixes required by current `iasl`:

```text
Removed invalid External declarations for temporary XHCI method objects.
Qualified four optional XHCI PS0X/PS3X calls to their RHUB paths.
Bumped DSDT OEM Revision from 0x01072009 to 0x0107200A so Linux accepts the table upgrade.
```

Successful boot evidence:

```text
ACPI: Table Upgrade: override [DSDT-SECCSD-LH43STAR]
ACPI: DSDT ... (v02 SECCSD LH43STAR 0107200A INTL ...)
ACPI: battery: Slot [BAT1] (battery present)

$ ls /sys/class/power_supply
BAT1  ucsi-source-psy-USBC000:001  ucsi-source-psy-USBC000:002

$ upower -e
/org/freedesktop/UPower/devices/battery_BAT1
```

## Files

```text
dsdt-patched.dsl                 Patched DSDT source
install-dsdt-test-initrd-v2.sh   Creates a separate one-time test initrd
install-dsdt-permanent.sh        Installs the override through dracut
uninstall-dsdt-permanent.sh      Removes the permanent override
verify-bat1-after-boot.sh        Verifies DSDT override and BAT1 detection
DSDT-override-ubuntu.md          Detailed local procedure notes
```

Generated files such as `dsdt-patched.aml` and `acpi_override.cpio` are intentionally not required to be committed. Rebuild them locally.

## Build

Requirements:

```text
Linux kernel with CONFIG_ACPI_TABLE_UPGRADE=y
ACPICA tools for iasl
dracut-based update-initramfs for the permanent install script
```

Install ACPICA tools:

```sh
sudo apt install acpica-tools
```

Compile the patched table:

```sh
iasl -tc dsdt-patched.dsl
```

Expected result:

```text
Compilation successful. 0 Errors
AML Output: dsdt-patched.aml
```

Warnings and remarks are expected from the vendor DSDT dump; the important condition is `0 Errors`.

## One-Time Test

Use this before making the override permanent.

First compile the AML:

```sh
iasl -tc dsdt-patched.dsl
```

Then create the test initrd:

```sh
sudo ./install-dsdt-test-initrd-v2.sh
```

This creates a separate initrd:

```text
/boot/initrd.img-7.0.0-15-generic-dsdt-bat1-v2
```

It does not modify the normal initrd and does not modify GRUB.

Reboot, edit the GRUB entry once, and replace the normal initrd with:

```text
/boot/initrd.img-7.0.0-15-generic-dsdt-bat1-v2
```

Boot without the charger connected, then verify:

```sh
./verify-bat1-after-boot.sh
```

The two DSDT hashes must match:

```text
sha256(/sys/firmware/acpi/tables/DSDT) == sha256(dsdt-patched.aml)
```

`BAT1` should appear in `/sys/class/power_supply` and `upower -e`.

## Permanent Install

This path expects `update-initramfs` to call `dracut`, because the permanent install uses dracut's built-in `acpi_override="yes"` support.

After the one-time test is confirmed:

```sh
iasl -tc dsdt-patched.dsl
```

```sh
sudo ./install-dsdt-permanent.sh
```

This installs:

```text
/etc/acpi/samsung-bat1-dsdt/DSDT.aml
/etc/dracut.conf.d/99-samsung-bat1-dsdt.conf
```

Then it regenerates the normal initrd:

```text
/boot/initrd.img-7.0.0-15-generic
```

Reboot normally without editing GRUB, preferably without the charger connected, then run:

```sh
./verify-bat1-after-boot.sh
```

## Rollback

Rollback from a working boot:

```sh
sudo ./uninstall-dsdt-permanent.sh
```

Emergency rollback from GRUB:

```text
Edit the Ubuntu entry.
Replace initrd.img-7.0.0-15-generic with:
initrd.img-7.0.0-15-generic.pre-dsdt-bat1-permanent-backup
Boot with Ctrl+x or F10.
```

If needed from a live USB, mount the Ubuntu root filesystem and `/boot`, then restore or remove the DSDT-patched initrd/config manually.

## Public Repository Safety

Do not publish raw ACPI dumps from your own machine without reviewing them first.

Important: `msdm.dat` can contain the embedded Windows OEM product key. Other ACPI dump files may also be machine-specific. This repository should publish the patched source and scripts, not the full raw dump set.

Recommended before pushing:

```sh
git status --short
git rm --cached --ignore-unmatch *.dat *.hex *.aml *.cpio ssdt*.dsl dsdt.dsl dsdt-patched-before-*.dsl bat1-block.txt
git add README.md .gitignore DSDT-override-ubuntu.md dsdt-patched.dsl install-dsdt-test-initrd-v2.sh install-dsdt-permanent.sh uninstall-dsdt-permanent.sh verify-bat1-after-boot.sh
```

Review the staged diff before making the repository public.

## Scope

This is a pragmatic workaround for a firmware behavior on a specific Samsung laptop. It is not an upstream kernel fix and it is not guaranteed to be safe for other models.

For a general solution, the right long-term path would be a kernel-side quirk or a firmware update from Samsung.
