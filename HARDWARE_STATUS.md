# Hardware Status: Samsung 960XGL / Galaxy Book4 Ultra

This file tracks what has actually been checked on the tested Samsung machine,
what needed a patch, what works without a repo patch, and what is still only a
known limitation.

If you find a different problem on the same laptop family, please open an issue
with diagnostics instead of assuming it is covered by the existing fixes.

## Tested Machine

```text
Laptop: Samsung Galaxy Book / Samsung 960XGL class
Model:  NP964XGL-XG3FR
DMI:    SAMSUNG ELECTRONICS CO., LTD. 960XGL/NP964XGL-XG3FR
BIOS:   P10ALX.470.260413.05, 2026-04-13
CPU:    Intel Core Ultra 9 185H
OS:     Ubuntu resolute
Kernel: 7.0.0-15-generic
```

## Status Matrix

| Area | Hardware / stack | Status | Repo action |
| --- | --- | --- | --- |
| Battery | ACPI `BAT1`, path `\_SB_.PC00.LPCB.H_EC.BAT1` | Patched and tested | `acpi/` DSDT override |
| Camera | OV02C10 / OVTI02C1, Intel IPU6, libcamera | Patched through upstream installer and tested | `camera/` documents install and tuning |
| Fingerprint | Egis/LighTuning `1c7a:05a1` ETU905A80-E | Patched and tested | `fingerprint/` libfprint SDCP fork installer |
| Fingerprint storage | Same Egis/LighTuning Match-on-Chip reader | Known limitation | No safe repo patch available |
| GNOME keyring after fingerprint login | GNOME keyring / PAM behavior | Expected behavior | No repo patch needed |
| GStreamer camera plugin cache | Per-user GStreamer registry cache | Known failure mode, workaround documented | Covered by camera notes |
| Fan / thermal policy | ACPI fan, Intel thermal zones, `platform_profile` | Patch added, needs reboot test | `acpi/` DSDT `FAN0._FST` fix |

## Patched And Tested

### ACPI Battery Detection

Problem: when booting without the AC adapter, Linux sometimes did not create
`/sys/class/power_supply/BAT1` even though the battery ACPI device existed.

Root cause found on the tested firmware: `Device (BAT1)` could return `Zero`
from `_STA`, which tells Linux the battery device is absent/disabled.

Patch status:

```text
Patched: yes
Location: acpi/
Install type: DSDT override in initrd
Test result: successful
```

Validated signs:

```text
ACPI: Table Upgrade: override [DSDT-SECCSD-LH43STAR]
ACPI: battery: Slot [BAT1] (battery present)
/sys/class/power_supply/BAT1 exists after booting without the charger
```

### Internal Webcam

Problem: the internal OV02C10/IPU6 camera needed the libcamera/IPU6 userspace
workaround and a V4L2 relay before normal apps such as OBS could use it.

The working method comes from
[@Andycodeman](https://github.com/Andycodeman)'s
[samsung-galaxy-book-linux-fixes](https://github.com/Andycodeman/samsung-galaxy-book-linux-fixes)
repository. This repo documents the tested install path and the color tuning
that worked best on this machine.

Patch status:

```text
Patched: yes, via upstream webcam installer
Location: camera/
Install type: source-built libcamera + GStreamer plugin + camera-relay
Test result: successful
```

Validated signs:

```text
cam -l shows Internal front camera (\_SB_.PC00.LNK0)
gst-inspect-1.0 libcamerasrc loads from /usr/local
camera-relay exposes /dev/video0: Camera Relay
OBS can open the camera through the relay
```

Color tuning status:

```text
Preferred preset on tested machine:
[1/18] No CCM (raw baseline)
```

This preset was chosen because the default OV02C10 CCM produced a purple/dim
image in the tested room lighting.

### Fingerprint Reader

Problem: Ubuntu's stock libfprint path detected the Egis/LighTuning reader but
did not persist/use enrollments correctly on the tested machine.

Patch status:

```text
Patched: yes
Location: fingerprint/
Device: 1c7a:05a1 LighTuning Technology Inc. ETU905A80-E
Install type: /usr/local libfprint override using TenSeventy7/libfprint-egismoc-sdcp
Test result: successful
```

Validated signs:

```text
ldd /usr/libexec/fprintd | grep fprint
libfprint-2.so.2 => /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2

fprintd-list $USER
Egis Technology (LighTuning) Match-on-Chip (press)

Two consecutive fprintd-verify checks return verify-match
```

## Works Or Expected Without A Repo Patch

### GNOME Keyring Prompt After Fingerprint Login

If you log in with fingerprint instead of typing your password, GNOME may show:

```text
The login keyring did not get unlocked when you logged into your computer.
```

This is expected: the login keyring is normally unlocked with the account
password. A fingerprint match does not provide that password to GNOME Keyring.

Repo status:

```text
Patch needed here: no
Reason: expected GNOME/PAM behavior, not a Samsung firmware bug
```

Use password login when you need the keyring unlocked automatically. Avoid
weakening the keyring unless you understand the security tradeoff.

### fprintd Service

`fprintd.service` is D-Bus activated. It does not need to be manually enabled
with `systemctl enable`.

Repo status:

```text
Patch needed here: no
Reason: service activation is normal
```

## Known Limitations

### Fan / Thermal Policy

Linux exposes the expected thermal stack on the tested machine:

```text
platform_profile choices: quiet balanced performance
current platform_profile: balanced
powerprofilesctl: uses intel_pstate + platform_profile
thermald.service: active, started with --adaptive
CPU driver: intel_pstate active
CPU governor: powersave on all CPUs
```

Thermal zones and cooling devices are present:

```text
thermal_zone: acpitz, SNS1/SNS2/SNS3, INT3400 Thermal, TCPU, TCPU_PCI, iwlwifi, x86_pkg_temp
cooling_device: Processor, intel_powerclamp, PCIe link-speed devices, Fan
ACPI fan: PNP0C0B at \_SB_.PC00.LPCB.FAN0
```

What worked during verification:

```text
powerprofilesctl reports balanced/performance/power-saver profiles
platform_profile reports quiet/balanced/performance choices
idle thermal check showed no new package throttling over 10 seconds
```

Known issue found:

```text
ACPI Error: Aborting method \_SB.PC00.LPCB.FAN0._FST due to previous error (AE_AML_OPERAND_TYPE)
acpi-fan PNP0C0B:00: Error retrieving current fan status: -5
```

The DSDT contains a `FAN0._FST` method that reads `H_EC.FANS`, indexes `FANT`,
and then does arithmetic on the returned value. The kernel reports the failure
while resolving the `Add` operation in `_FST`. As a result, Linux exposes the
fan cooling device, but fan status/RPM telemetry is unreliable:

```text
/sys/bus/acpi/devices/PNP0C0B:00/fan_speed_rpm is empty
/sys/class/hwmon/.../fan1_input reports 0
```

This does not prove that the physical fan is broken. It means Linux cannot
reliably read the ACPI fan status through `_FST` on the tested firmware. The
actual fan may still be controlled by firmware/EC thermal policy.

Repo status:

```text
Patch available: yes, added to the ACPI DSDT patch script
Test requirement: rebuild AML, boot through one-time initrd first, then check kernel logs
```

### Windows Hello And Linux Fingerprint Enrollments

The tested fingerprint reader is Match-on-Chip. Enrolled prints are stored in
the fingerprint device itself, not only in Windows or Linux user files.

Windows Hello and Linux can overwrite or invalidate each other's enrollments on
the tested machine.

Repo status:

```text
Patch available: no reliable patch
Workaround: keep password login available and re-enroll after switching OS
```

### Match-on-Host Fingerprint Storage

We checked whether the Egis/LighTuning reader could be used as a raw image
sensor so Linux could store/process fingerprints on the host instead of in the
device.

Result: no raw image capture path is exposed by the current `egismoc` driver.
The driver is explicitly Match-on-Chip, implements enroll/verify/identify/list,
and does not implement the libfprint capture feature.

Repo status:

```text
Patch available: no
Reason: would require USB/firmware reverse engineering, not a normal driver tweak
```

The commands named `capture` in the driver are part of the device-side
enrollment flow. They report success/retry states, not a host-readable
fingerprint image.

## Not Verified Yet

The following areas are not documented as fixed or fully verified by this repo.
If you see a bug here, open a new issue with logs.

```text
Audio speakers / microphone array
Bluetooth
Wi-Fi stability
NVIDIA dGPU power management
External displays / USB-C DisplayPort
Thunderbolt / USB4 hotplug
Suspend / resume battery drain
Keyboard backlight / hotkeys
Touchpad gestures
SD card reader, if present
```

Do not read this list as "broken". It only means this repo has not shipped a
specific tested fix for those areas.

## Opening A Useful Issue

Please include the exact model and kernel:

```sh
sudo dmidecode -s system-manufacturer
sudo dmidecode -s system-product-name
sudo dmidecode -s bios-version
uname -a
```

For battery issues:

```sh
ls /sys/class/power_supply
cat /sys/bus/acpi/devices/PNP0C0A:00/status 2>/dev/null
cat /sys/bus/acpi/devices/PNP0C0A:00/path 2>/dev/null
journalctl -b --no-pager | grep -iE 'ACPI: Table Upgrade|ACPI: battery|BAT1|PNP0C0A'
```

For camera issues:

```sh
cam -l
gst-inspect-1.0 libcamerasrc | grep -E 'Filename|Version'
v4l2-ctl --list-devices 2>/dev/null
journalctl --user -u camera-relay -n 200 --no-pager
```

For fingerprint issues:

```sh
lsusb | grep -iE '1c7a|egis|lightuning'
ldd /usr/libexec/fprintd | grep fprint
fprintd-list "$USER"
journalctl -u fprintd -n 200 --no-pager
```

For fan or thermal policy issues:

```sh
cat /sys/firmware/acpi/platform_profile 2>/dev/null
cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null
powerprofilesctl list
systemctl status thermald power-profiles-daemon --no-pager

for z in /sys/class/thermal/thermal_zone*; do
  [ -d "$z" ] || continue
  echo "$z type=$(cat "$z/type" 2>/dev/null) temp=$(cat "$z/temp" 2>/dev/null)"
done

for c in /sys/class/thermal/cooling_device*; do
  [ -d "$c" ] || continue
  echo "$c type=$(cat "$c/type" 2>/dev/null) cur=$(cat "$c/cur_state" 2>/dev/null) max=$(cat "$c/max_state" 2>/dev/null)"
done

for h in /sys/class/hwmon/hwmon*; do
  [ -d "$h" ] || continue
  echo "$h name=$(cat "$h/name" 2>/dev/null)"
  grep -H . "$h"/fan*_input "$h"/temp*_input 2>/dev/null
done

journalctl -k -b --no-pager | grep -iE 'thermal|thermald|int340|dptf|fan|cooling|throttl|temperature'
```

Do not upload raw ACPI dumps, full DSDT files, serial numbers, Windows product
keys, or private fingerprint debug data unless you have reviewed and redacted
them first.
