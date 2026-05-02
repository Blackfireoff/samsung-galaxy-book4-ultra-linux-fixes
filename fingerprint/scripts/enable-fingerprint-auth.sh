#!/usr/bin/env bash
set -euo pipefail

backup_dir="/var/backups/fprintd-pam-$(date +%Y%m%d-%H%M%S)"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "Checking that fprintd uses the patched libfprint..."
if ! ldd /usr/libexec/fprintd | grep -q '/usr/local/lib/.*/libfprint-2.so.2'; then
  echo "fprintd is not using /usr/local libfprint. Refusing to enable PAM." >&2
  ldd /usr/libexec/fprintd | grep fprint >&2 || true
  exit 1
fi

echo "Checking enrolled fingerprint..."
if ! fprintd-list "$USER" | grep -q 'right-index-finger'; then
  echo "No right-index-finger enrollment found for $USER. Refusing to enable PAM." >&2
  exit 1
fi

echo "Creating PAM backup in $backup_dir"
sudo install -d -m 0755 "$backup_dir"
sudo cp -a /etc/pam.d/common-* "$backup_dir"/

echo "Enabling libpam-fprintd through pam-auth-update..."
sudo DEBIAN_FRONTEND=noninteractive pam-auth-update --enable fprintd

echo
echo "Current common-auth fprintd line:"
grep -n 'pam_fprintd' /etc/pam.d/common-auth || {
  echo "pam_fprintd was not added to /etc/pam.d/common-auth" >&2
  exit 1
}

echo
echo "Enabled. Test order:"
echo "  1. Lock the current GNOME session and unlock with fingerprint."
echo "  2. Test sudo in a new terminal."
echo "  3. Reboot only after both tests work."
echo
echo "Rollback:"
echo "  $script_dir/disable-fingerprint-auth.sh"
echo "Manual backup restore:"
echo "  sudo cp -a $backup_dir/common-* /etc/pam.d/"
