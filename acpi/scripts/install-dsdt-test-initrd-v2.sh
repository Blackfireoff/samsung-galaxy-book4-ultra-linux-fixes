#!/bin/sh
set -eu

KVER="${1:-$(uname -r)}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORK_DIR="${ACPI_WORKDIR:-$(pwd)}"
BASE_INITRD="/boot/initrd.img-${KVER}"
TEST_INITRD="${TEST_INITRD:-/boot/initrd.img-${KVER}-dsdt-bat1-v2}"
BACKUP_INITRD="/boot/initrd.img-${KVER}.pre-dsdt-bat1-backup"
OVERRIDE_CPIO="${WORK_DIR}/acpi_override.cpio"
PATCHED_AML="${DSDT_AML:-${WORK_DIR}/dsdt-patched.aml}"
OVERRIDE_DIR="${WORK_DIR}/acpi-override"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo $0 ${KVER}" >&2
    exit 1
fi

if [ ! -r "$BASE_INITRD" ]; then
    echo "Base initrd is not readable: $BASE_INITRD" >&2
    exit 1
fi

if [ ! -r "$PATCHED_AML" ]; then
    echo "Missing compiled DSDT AML: $PATCHED_AML" >&2
    echo "Build it first with: iasl -tc dsdt-patched.dsl" >&2
    echo "Or set DSDT_AML=/path/to/dsdt-patched.aml" >&2
    exit 1
fi

if [ ! -r "$OVERRIDE_CPIO" ] || [ "$PATCHED_AML" -nt "$OVERRIDE_CPIO" ]; then
    echo "Building ACPI override archive: $OVERRIDE_CPIO"
    rm -rf -- "$OVERRIDE_DIR"
    install -d -m 0755 "$OVERRIDE_DIR/kernel/firmware/acpi"
    install -m 0644 "$PATCHED_AML" "$OVERRIDE_DIR/kernel/firmware/acpi/DSDT.aml"
    ( cd "$OVERRIDE_DIR" && find kernel | cpio -H newc --create --quiet > "$OVERRIDE_CPIO" )
fi

if [ -e "$TEST_INITRD" ]; then
    echo "Refusing to overwrite existing test initrd: $TEST_INITRD" >&2
    exit 1
fi

if [ ! -e "$BACKUP_INITRD" ]; then
    cp -a -- "$BASE_INITRD" "$BACKUP_INITRD"
    echo "Backup created: $BACKUP_INITRD"
else
    echo "Backup already exists: $BACKUP_INITRD"
fi

cat "$OVERRIDE_CPIO" "$BASE_INITRD" > "$TEST_INITRD"
chmod --reference="$BASE_INITRD" "$TEST_INITRD" 2>/dev/null || chmod 0600 "$TEST_INITRD"
chown --reference="$BASE_INITRD" "$TEST_INITRD" 2>/dev/null || true

echo "Test initrd created: $TEST_INITRD"
echo
echo "No GRUB config was changed."
echo "For a one-time test, edit the GRUB entry and replace the existing initrd path with:"
echo "  ${TEST_INITRD}"
