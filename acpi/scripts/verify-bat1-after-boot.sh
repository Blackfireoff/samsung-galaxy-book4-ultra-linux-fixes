#!/bin/sh
set -eu

uname -r
PATCHED_AML="${DSDT_AML:-$(pwd)/dsdt-patched.aml}"
if command -v sudo >/dev/null 2>&1; then
    sudo sha256sum /sys/firmware/acpi/tables/DSDT "$PATCHED_AML" || true
    sudo dmesg | grep -iE "ACPI:.*override|table upgrade|DSDT|battery|BAT1|PNP0C0A|FAN0|_FST|acpi-fan|AE_AML_OPERAND_TYPE" || true
else
    sha256sum /sys/firmware/acpi/tables/DSDT "$PATCHED_AML" || true
    dmesg | grep -iE "ACPI:.*override|table upgrade|DSDT|battery|BAT1|PNP0C0A|FAN0|_FST|acpi-fan|AE_AML_OPERAND_TYPE" || true
fi
ls /sys/class/power_supply
upower -e
cat /sys/bus/acpi/devices/PNP0C0A:00/status
cat /sys/bus/acpi/devices/PNP0C0A:00/path

echo
echo "Fan / thermal checks:"
cat /sys/firmware/acpi/platform_profile 2>/dev/null || true
cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null || true
cat /sys/bus/acpi/devices/PNP0C0B:00/path 2>/dev/null || true
cat /sys/bus/acpi/devices/PNP0C0B:00/fan_speed_rpm 2>/dev/null || true
for hwmon in /sys/class/hwmon/hwmon*; do
    [ -d "$hwmon" ] || continue
    [ "$(cat "$hwmon/name" 2>/dev/null)" = "acpi_fan" ] || continue
    echo "acpi_fan hwmon: $hwmon"
    cat "$hwmon/fan1_input" 2>/dev/null || true
done
