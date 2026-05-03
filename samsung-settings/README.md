# Samsung Settings Linux Controls

This directory provides partial Linux controls for Samsung Galaxy Book settings
when the relevant feature is exposed by the kernel.

It is not a complete reimplementation of Samsung Settings for Windows. On
Windows, the UI likely talks to Samsung services and drivers, which then talk to
Samsung-specific ACPI, WMI, EC, or firmware interfaces. On Linux, this repository
only controls interfaces that are exposed by the kernel or that can be validated
cleanly without unsafe firmware writes.

The safety model is the same as the rest of this repository:

- prefer diagnostics before changes
- write only to known kernel interfaces documented here
- verify writes after applying them
- provide rollback instructions
- never write to unknown ACPI, EC, or WMI methods
- never publish raw ACPI dumps or machine-specific firmware data

## Feature Status

| Feature | Linux interface | Status |
| --- | --- | --- |
| Battery protection / 80% limit | `/sys/class/power_supply/BAT*/charge_control_end_threshold` | Supported if present |
| Performance mode | `/sys/firmware/acpi/platform_profile` | Supported if present |
| USB charging while off | Unknown Samsung-specific ACPI/EC method | Research needed |
| Display color modes | ICC profiles / compositor support | Partial alternative only |
| HDR+ | Samsung/Windows-specific | Unsupported |
| Fan / thermal modes | `platform_profile` or vendor-specific interface | Partial / research needed |

## Scripts

Run the read-only capability detector first:

```sh
./scripts/samsung-settings-detect
```

Battery protection:

```sh
./scripts/samsung-battery-protection status
sudo ./scripts/samsung-battery-protection on
sudo ./scripts/samsung-battery-protection off
sudo ./scripts/samsung-battery-protection set 80
```

The `on` command writes `80`, and `off` writes `100`. Custom values are limited
to `50..100`.

Performance mode:

```sh
./scripts/samsung-performance-mode status
./scripts/samsung-performance-mode list
sudo ./scripts/samsung-performance-mode set <mode>
```

Do not assume mode names. Use `list` and select one of the modes exposed by the
kernel on your machine.

## Install Battery Protection Service

The service reapplies the 80% charge limit at boot using
`/usr/local/bin/samsung-battery-protection on`.

```sh
sudo install -m 755 samsung-settings/scripts/samsung-battery-protection /usr/local/bin/
sudo cp samsung-settings/systemd/samsung-battery-protection.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now samsung-battery-protection.service
```

Rollback:

```sh
sudo systemctl disable --now samsung-battery-protection.service
sudo rm /etc/systemd/system/samsung-battery-protection.service
sudo systemctl daemon-reload
```

Optionally disable the charge limit before uninstalling:

```sh
sudo /usr/local/bin/samsung-battery-protection off
```

## Research Checklist

These commands are read-only diagnostics. They are useful when investigating
future Samsung Settings features, but they must not be followed by writes to
unknown ACPI, EC, or WMI interfaces.

```sh
find /sys/bus/wmi -maxdepth 3 -type f -print
find /sys/firmware/acpi -maxdepth 2 -type f -print
grep -R . /sys/firmware/acpi/platform_profile* 2>/dev/null
```

## Detailed Notes

- [Battery protection](docs/battery-protection.md)
- [Performance modes](docs/performance-modes.md)
- [Unsupported Windows settings](docs/unsupported-windows-settings.md)
