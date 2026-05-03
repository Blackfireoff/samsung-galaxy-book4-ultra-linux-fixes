# Battery Protection

Samsung Settings for Windows can enable battery protection, commonly shown as an
80% charge limit. The goal is to reduce time spent at a very high state of
charge, which can reduce long-term battery wear for machines that are often left
plugged in.

Linux can support the same kind of limit only when the kernel exposes a standard
power-supply threshold file:

```text
/sys/class/power_supply/BAT*/charge_control_end_threshold
```

This repository does not write to Samsung-specific ACPI, EC, or WMI methods for
battery protection.

## Check Support

Run the detector:

```sh
./samsung-settings/scripts/samsung-settings-detect
```

Or check manually:

```sh
find /sys/class/power_supply -path '*/charge_control_end_threshold' -print
```

If the file is missing, the current kernel does not expose battery charge
threshold control on this machine.

## Commands

Show the current value:

```sh
./samsung-settings/scripts/samsung-battery-protection status
```

Enable the 80% limit:

```sh
sudo ./samsung-settings/scripts/samsung-battery-protection on
```

Disable the limit by setting 100%:

```sh
sudo ./samsung-settings/scripts/samsung-battery-protection off
```

Set a custom value from 50 to 100:

```sh
sudo ./samsung-settings/scripts/samsung-battery-protection set 80
```

The script searches for `BAT*/charge_control_end_threshold`, so it works with
`BAT0`, `BAT1`, or another kernel battery index matching that pattern.

## systemd Service

The threshold may reset after reboot. Install the oneshot service to reapply the
80% limit at boot:

```sh
sudo install -m 755 samsung-settings/scripts/samsung-battery-protection /usr/local/bin/
sudo cp samsung-settings/systemd/samsung-battery-protection.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now samsung-battery-protection.service
```

Check the service:

```sh
systemctl status samsung-battery-protection.service
./samsung-settings/scripts/samsung-battery-protection status
```

## Rollback

Disable the threshold:

```sh
sudo /usr/local/bin/samsung-battery-protection off
```

Remove the service:

```sh
sudo systemctl disable --now samsung-battery-protection.service
sudo rm /etc/systemd/system/samsung-battery-protection.service
sudo systemctl daemon-reload
```

## Limits

- Support depends on the kernel exposing `charge_control_end_threshold`.
- The value may not survive reboot without the systemd service.
- The script only accepts values from 50 to 100.
- The script verifies the value after writing it.
- No unknown ACPI, EC, or WMI battery methods are used.
