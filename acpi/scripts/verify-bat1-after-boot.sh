#!/bin/sh
set -eu

uname -r
PATCHED_AML="${DSDT_AML:-$(pwd)/dsdt-patched.aml}"
if command -v sudo >/dev/null 2>&1; then
    sudo sha256sum /sys/firmware/acpi/tables/DSDT "$PATCHED_AML" || true
    sudo dmesg | grep -iE "ACPI:.*override|table upgrade|DSDT|battery|BAT1|PNP0C0A" || true
else
    sha256sum /sys/firmware/acpi/tables/DSDT "$PATCHED_AML" || true
    dmesg | grep -iE "ACPI:.*override|table upgrade|DSDT|battery|BAT1|PNP0C0A" || true
fi
ls /sys/class/power_supply
upower -e
cat /sys/bus/acpi/devices/PNP0C0A:00/status
cat /sys/bus/acpi/devices/PNP0C0A:00/path
