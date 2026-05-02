#!/usr/bin/env bash
set -euo pipefail

echo "USB fingerprint device:"
lsusb | grep -iE '1c7a:05a1|LighTuning|Egis' || true

echo
echo "libfprint used by fprintd:"
ldd /usr/libexec/fprintd | grep -E 'libfprint|not found' || true

echo
echo "Installed fprint packages:"
dpkg -l | grep -E 'fprint|libfprint' || true

echo
echo "Restarting fprintd..."
sudo systemctl restart fprintd.service

echo
echo "Deleting stale prints for $USER..."
fprintd-delete "$USER" || true

echo
echo "Enroll right index finger. Do not touch the sensor until prompted."
read -r -p "Press Enter to start enrollment..."
fprintd-enroll -f right-index-finger "$USER"

echo
echo "Listing enrolled prints:"
fprintd-list "$USER"

echo
echo "Verification 1. Touch the sensor only when prompted."
fprintd-verify "$USER"

echo
echo "Verification 2, after a fresh fprintd restart."
sudo systemctl restart fprintd.service
fprintd-list "$USER"
fprintd-verify "$USER"

echo
echo "Recent fprintd log:"
journalctl -u fprintd -b --no-pager | tail -n 120
