#!/usr/bin/env bash
set -euo pipefail

echo "Disabling libpam-fprintd through pam-auth-update..."
sudo DEBIAN_FRONTEND=noninteractive pam-auth-update --disable fprintd

echo
if grep -n 'pam_fprintd' /etc/pam.d/common-auth; then
  echo "pam_fprintd is still present in /etc/pam.d/common-auth" >&2
  exit 1
fi

echo "Fingerprint PAM authentication disabled."
