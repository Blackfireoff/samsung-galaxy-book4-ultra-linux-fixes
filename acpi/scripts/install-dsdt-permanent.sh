#!/bin/sh
set -eu

KVER="${1:-$(uname -r)}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORK_DIR="${ACPI_WORKDIR:-$(pwd)}"
PATCHED_AML="${DSDT_AML:-${WORK_DIR}/dsdt-patched.aml}"
TABLE_DIR="/etc/acpi/samsung-bat1-dsdt"
TABLE_FILE="${TABLE_DIR}/DSDT.aml"
DRACUT_CONF="/etc/dracut.conf.d/99-samsung-bat1-dsdt.conf"
INITRAMFS_HOOK="/etc/initramfs-tools/hooks/samsung-bat1-dsdt"
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

if [ ! -r "/boot/config-${KVER}" ]; then
    echo "Missing kernel config: /boot/config-${KVER}" >&2
    exit 1
fi

if ! grep -q '^CONFIG_ACPI_TABLE_UPGRADE=y' "/boot/config-${KVER}"; then
    echo "Kernel ${KVER} does not advertise CONFIG_ACPI_TABLE_UPGRADE=y" >&2
    exit 1
fi

detect_initramfs_backend() {
    if command -v dracut >/dev/null 2>&1; then
        echo "dracut"
        return 0
    fi

    if command -v update-initramfs >/dev/null 2>&1; then
        echo "initramfs-tools"
        return 0
    fi

    echo "none"
    return 1
}

BACKEND="$(detect_initramfs_backend)" || {
    echo "Neither dracut nor initramfs-tools was found." >&2
    exit 1
}

echo "Detected initramfs backend: ${BACKEND}"

if [ ! -e "$BACKUP_INITRD" ]; then
    cp -a -- "$INITRD" "$BACKUP_INITRD"
    echo "Backup created: $BACKUP_INITRD"
else
    echo "Backup already exists: $BACKUP_INITRD"
fi

install -d -m 0755 "$TABLE_DIR"
install -m 0644 "$PATCHED_AML" "$TABLE_FILE"

case "$BACKEND" in
    dracut)
        install -d -m 0755 /etc/dracut.conf.d

        cat > "$DRACUT_CONF" <<EOF
# Samsung Galaxy Book 960XGL BAT1 DSDT override.
# Created from ${PATCHED_AML}
# Remove this file and regenerate initramfs to disable the override.
acpi_override="yes"
acpi_table_dir="${TABLE_DIR}"
EOF

        echo "Dracut ACPI override config installed: $DRACUT_CONF"
        echo "ACPI table installed: $TABLE_FILE"
        echo "Regenerating initrd for kernel ${KVER} with dracut"

        dracut --force "/boot/initrd.img-${KVER}" "$KVER"
        ;;

    initramfs-tools)
        install -d -m 0755 /etc/initramfs-tools/hooks

        cat > "$INITRAMFS_HOOK" <<EOF
#!/bin/sh
set -e

PREREQ=""

prereqs() {
    echo "\$PREREQ"
}

case "\$1" in
    prereqs)
        prereqs
        exit 0
        ;;
esac

. /usr/share/initramfs-tools/hook-functions

# Samsung Galaxy Book 960XGL BAT1 DSDT override.
# Created from ${PATCHED_AML}
#
# The Linux kernel expects ACPI override tables in the early initramfs at:
# /kernel/firmware/acpi/DSDT.aml

mkdir -p "\${DESTDIR}/kernel/firmware/acpi"
cp -p "${TABLE_FILE}" "\${DESTDIR}/kernel/firmware/acpi/DSDT.aml"

exit 0
EOF

        chmod 0755 "$INITRAMFS_HOOK"

        echo "initramfs-tools hook installed: $INITRAMFS_HOOK"
        echo "ACPI table installed: $TABLE_FILE"
        echo "Regenerating initrd for kernel ${KVER} with initramfs-tools"

        update-initramfs -u -k "$KVER"
        ;;

    *)
        echo "Unsupported initramfs backend: $BACKEND" >&2
        exit 1
        ;;
esac

echo
echo "Checking generated initrd for ACPI override payload:"

if command -v lsinitrd >/dev/null 2>&1; then
    lsinitrd "$INITRD" | grep -E "early_cpio|kernel/firmware/acpi/DSDT\\.aml|DSDT\\.aml" || true
elif command -v lsinitramfs >/dev/null 2>&1; then
    lsinitramfs "$INITRD" | grep -E "kernel/firmware/acpi/DSDT\\.aml|DSDT\\.aml" || true
else
    echo "No initrd inspection tool found: lsinitrd or lsinitramfs"
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