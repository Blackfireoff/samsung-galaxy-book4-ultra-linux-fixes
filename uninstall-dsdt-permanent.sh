#!/bin/sh
set -eu

KVER="${1:-$(uname -r)}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TABLE_DIR="/etc/acpi/samsung-bat1-dsdt"
DRACUT_CONF="/etc/dracut.conf.d/99-samsung-bat1-dsdt.conf"
INITRD="/boot/initrd.img-${KVER}"
CURRENT_BACKUP="/boot/initrd.img-${KVER}.with-dsdt-bat1-backup"
ORIGINAL_BACKUP="/boot/initrd.img-${KVER}.pre-dsdt-bat1-permanent-backup"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo $0 ${KVER}" >&2
    exit 1
fi

if [ -r "$INITRD" ] && [ ! -e "$CURRENT_BACKUP" ]; then
    cp -a -- "$INITRD" "$CURRENT_BACKUP"
    echo "Current DSDT initrd backup created: $CURRENT_BACKUP"
fi

rm -f -- "$DRACUT_CONF"
rm -rf -- "$TABLE_DIR"

echo "Removed: $DRACUT_CONF"
echo "Removed: $TABLE_DIR"

if [ -r "$ORIGINAL_BACKUP" ]; then
    cp -a -- "$ORIGINAL_BACKUP" "$INITRD"
    echo "Restored original initrd from: $ORIGINAL_BACKUP"
else
    echo "Original backup not found; regenerating initrd without DSDT override."
    update-initramfs -u -k "$KVER"
fi

echo
echo "Permanent DSDT override removed for kernel ${KVER}."
echo "Reboot normally, then verify BAT1 behavior if needed:"
echo "  ${SCRIPT_DIR}/verify-bat1-after-boot.sh"
