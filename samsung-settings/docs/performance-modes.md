# Performance Modes

Linux exposes firmware performance profiles through:

```text
/sys/firmware/acpi/platform_profile
/sys/firmware/acpi/platform_profile_choices
```

`platform_profile` contains the active profile. `platform_profile_choices`
contains the list of profiles the kernel says are valid on the current machine.

The names are not guaranteed to match Samsung Settings for Windows. Samsung may
show labels such as high performance, optimized, or quiet, while Linux may expose
different names depending on the kernel, firmware, and drivers.

## Check Support

Run:

```sh
./samsung-settings/scripts/samsung-settings-detect
```

Or check manually:

```sh
cat /sys/firmware/acpi/platform_profile
cat /sys/firmware/acpi/platform_profile_choices
```

If either file is missing, the current kernel does not expose platform
performance profile control on this machine.

## List Modes

```sh
./samsung-settings/scripts/samsung-performance-mode list
```

Use only one of the modes printed by that command.

## Show Current Mode

```sh
./samsung-settings/scripts/samsung-performance-mode status
```

## Change Mode

```sh
sudo ./samsung-settings/scripts/samsung-performance-mode set <mode>
```

The script checks that `<mode>` is present in `platform_profile_choices` before
writing to `platform_profile`, and verifies the active value after writing.

## Limits Compared With Samsung Settings

The Windows labels are not treated as portable firmware API names. This tool does
not invent mappings such as:

- high performance
- optimized
- quiet

Those mappings can only be documented for a specific machine and kernel after
testing. If Linux exposes multiple profiles, fan behavior, power limits, and
thermal behavior may still differ from Samsung Settings for Windows.

This repository does not write to unknown vendor methods to force fan or thermal
modes.
