# Unsupported Windows Settings

Samsung Settings for Windows can expose controls that rely on Samsung-specific
drivers, services, ACPI methods, WMI methods, EC commands, or firmware behavior.
Most of those controls are not documented as stable Linux interfaces.

This repository does not write to unknown ACPI, EC, or WMI methods. Future work
should start with read-only diagnostics, then add write support only after the
interface is understood, bounded, and reversible.

## Display Color Modes

Samsung Settings may offer modes such as:

- Auto
- AMOLED native
- sRGB
- Adobe RGB
- DCI-P3

Linux alternatives are partial. Depending on the desktop environment and display
stack, ICC profiles and compositor color management may provide a practical
alternative for some workflows, but they are not the same as Samsung's Windows
implementation.

## HDR+

HDR+ is treated as Samsung/Windows-specific here. No safe Linux control is
implemented.

## USB Charging While Off

Charging external USB devices while the PC is powered off, suspended, or in
hibernation may depend on firmware and embedded-controller behavior. The Linux
interface is not known for this machine.

This remains research only until a safe, documented, or well-validated interface
is found.

## Proprietary Firmware Settings

Some Samsung Settings toggles may be backed by proprietary firmware methods.
They should not be changed by guessing method names or writing arbitrary values
to ACPI, EC, WMI, or debugfs interfaces.

Safe future research can include read-only inventory commands such as:

```sh
find /sys/bus/wmi -maxdepth 3 -type f -print
find /sys/firmware/acpi -maxdepth 2 -type f -print
grep -R . /sys/firmware/acpi/platform_profile* 2>/dev/null
```

Do not publish raw ACPI dumps from your own machine without reviewing them for
machine-specific or sensitive data.
