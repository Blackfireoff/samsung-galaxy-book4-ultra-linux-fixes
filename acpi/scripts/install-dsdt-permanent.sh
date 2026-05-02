#!/bin/sh
set -eu

KVER="${1:-$(uname -r)}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORK_DIR="${ACPI_WORKDIR:-$(pwd)}"
PATCHED_AML="${DSDT_AML:-${WORK_DIR}/dsdt-patched.aml}"
TABLE_DIR="/etc/acpi/samsung-bat1-dsdt"
TABLE_FILE="${TABLE_DIR}/DSDT.aml"
DRACUT_CONF="/etc/dracut.conf.d/99-samsung-bat1-dsdt.conf"
INITRD="/boot/initrd.img-${KVER}"
BACKUP_INITRD="/boot/initrd.img-${KVER}.pre-dsdt-bat1-permanent-backup"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo $0 ${KVER}" >&2
    exit 1
fi

if [ ! -r "$PATCHED_AML" ]; then
    echo "Missing patched AML: $PATCHED_AML" >&2
    exit 1
fi

if [ ! -r "$INITRD" ]; then
    echo "Base initrd is not readable: $INITRD" >&2
    exit 1
fi

if ! grep -q '^CONFIG_ACPI_TABLE_UPGRADE=y' "/boot/config-${KVER}"; then
    echo "Kernel ${KVER} does not advertise CONFIG_ACPI_TABLE_UPGRADE=y" >&2
    exit 1
fi

if [ ! -e "$BACKUP_INITRD" ]; then
    cp -a -- "$INITRD" "$BACKUP_INITRD"
    echo "Backup created: $BACKUP_INITRD"
else
    echo "Backup already exists: $BACKUP_INITRD"
fi

install -d -m 0755 "$TABLE_DIR"
install -m 0644 "$PATCHED_AML" "$TABLE_FILE"

cat > "$DRACUT_CONF" <<EOF
# Samsung Galaxy Book 960XGL BAT1 DSDT override.
# Created from ${PATCHED_AML}
# Remove this file and regenerate initramfs to disable the override.
acpi_override="yes"
acpi_table_dir="${TABLE_DIR}"
EOF

echo "Dracut ACPI override config installed: $DRACUT_CONF"
echo "ACPI table installed: $TABLE_FILE"
echo "Regenerating initrd: $INITRD"
update-initramfs -u -k "$KVER"

echo
echo "Checking generated initrd for ACPI override payload:"
if command -v lsinitrd >/dev/null 2>&1; then
    lsinitrd "$INITRD" | grep -E "early_cpio|kernel/firmware/acpi/DSDT\\.aml|DSDT\\.aml" || true
fi

echo
echo "Permanent DSDT override installed for kernel ${KVER}."
echo "Reboot normally without editing GRUB, then run:"
echo "  ${SCRIPT_DIR}/verify-bat1-after-boot.sh"
echo
echo "Rollback from a working boot:"
echo "  sudo ${SCRIPT_DIR}/uninstall-dsdt-permanent.sh ${KVER}"
echo
echo "Emergency rollback from GRUB:"
echo "  edit the Ubuntu entry and replace initrd.img-${KVER} with:"
echo "  initrd.img-${KVER}.pre-dsdt-bat1-permanent-backup"
