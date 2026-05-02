# ACPI BAT1 DSDT Override

Fix for a Samsung Galaxy Book / 960XGL where Linux only detects the internal battery if the laptop boots with the AC adapter plugged in.

## Problem

Booting Ubuntu without the charger:

```text
$ ls /sys/class/power_supply
ucsi-source-psy-USBC000:001  ucsi-source-psy-USBC000:002

$ cat /sys/bus/acpi/devices/PNP0C0A:00/status
31

$ cat /sys/bus/acpi/devices/PNP0C0A:00/path
\_SB_.PC00.LPCB.H_EC.BAT1
```

Booting Ubuntu with the charger:

```text
ADP1  BAT1  ucsi-source-psy-USBC000:001  ucsi-source-psy-USBC000:002
```

The ACPI battery object exists, but the kernel battery driver does not create `/sys/class/power_supply/BAT1`.

## Root Cause

In the tested firmware, `Device (BAT1)` has a `_STA` method that can return `Zero`:

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

Returning `Zero` from `_STA` tells ACPI that the device is absent/disabled. The patch removes only this battery-hiding branch.

The patch script also applies compile fixes needed by current `iasl` on this DSDT:

```text
Remove invalid External declarations for temporary XHCI method objects.
Qualify optional XHCI PS0X/PS3X calls to RHUB paths.
Bump DSDT OEM Revision by one so Linux accepts the table upgrade.
```

## Build

Install tools:

```sh
sudo apt install acpica-tools
```

Dump and decompile your own ACPI tables:

```sh
mkdir -p ~/acpi-battery-debug
cd ~/acpi-battery-debug
sudo acpidump -b
iasl -d dsdt.dat
```

Patch and compile:

```sh
python3 /path/to/repo/acpi/scripts/patch-dsdt-bat1.py dsdt.dsl dsdt-patched.dsl
iasl -tc dsdt-patched.dsl
```

Expected condition:

```text
Compilation successful. 0 Errors
AML Output: dsdt-patched.aml
```

Warnings and remarks from the vendor DSDT are expected; `0 Errors` is the important condition.

## One-Time Initrd Test

Use this before making the override permanent.

```sh
cd ~/acpi-battery-debug
sudo /path/to/repo/acpi/scripts/install-dsdt-test-initrd-v2.sh
```

This creates a separate initrd:

```text
/boot/initrd.img-$(uname -r)-dsdt-bat1-v2
```

It does not modify the normal initrd and does not modify GRUB.

Reboot, edit the GRUB entry once, and replace the normal initrd path with the test initrd. Boot without the charger connected, then verify:

```sh
cd ~/acpi-battery-debug
/path/to/repo/acpi/scripts/verify-bat1-after-boot.sh
```

Successful boot evidence:

```text
ACPI: Table Upgrade: override [DSDT-SECCSD-LH43STAR]
ACPI: battery: Slot [BAT1] (battery present)

$ ls /sys/class/power_supply
BAT1  ucsi-source-psy-USBC000:001  ucsi-source-psy-USBC000:002
```

## Permanent Install

Only do this after the one-time initrd test works.

This path expects `update-initramfs` to call `dracut`, because the permanent install uses dracut's `acpi_override="yes"` support.

```sh
cd ~/acpi-battery-debug
sudo /path/to/repo/acpi/scripts/install-dsdt-permanent.sh
```

This installs:

```text
/etc/acpi/samsung-bat1-dsdt/DSDT.aml
/etc/dracut.conf.d/99-samsung-bat1-dsdt.conf
```

Then it regenerates the normal initrd. Reboot normally without the charger connected, then run:

```sh
/path/to/repo/acpi/scripts/verify-bat1-after-boot.sh
```

## Rollback

Rollback from a working boot:

```sh
sudo /path/to/repo/acpi/scripts/uninstall-dsdt-permanent.sh
```

Emergency rollback from GRUB:

```text
Edit the Ubuntu entry.
Replace initrd.img-$(uname -r) with:
initrd.img-$(uname -r).pre-dsdt-bat1-permanent-backup
Boot with Ctrl+x or F10.
```

If needed from a live USB, mount the Ubuntu root filesystem and `/boot`, then restore or remove the DSDT-patched initrd/config manually.
