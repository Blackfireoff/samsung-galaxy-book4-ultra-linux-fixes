#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="${1:-"$script_dir/../build/libfprint-egismoc-sdcp"}"
build_dir="$repo_dir/builddir"
multiarch="$(gcc -print-multiarch 2>/dev/null || true)"
multiarch="${multiarch:-x86_64-linux-gnu}"

if [[ -d "$build_dir" ]] && command -v ninja >/dev/null 2>&1; then
  sudo ninja -C "$build_dir" uninstall || true
fi

sudo rm -f /usr/local/lib/"$multiarch"/libfprint-2.so \
  /usr/local/lib/"$multiarch"/libfprint-2.so.2 \
  /usr/local/lib/"$multiarch"/libfprint-2.so.2.0.0
sudo rm -f /usr/local/lib/"$multiarch"/pkgconfig/libfprint-2.pc
sudo rm -rf /usr/local/include/libfprint-2

sudo ldconfig
sudo systemctl restart fprintd.service

echo "Rollback complete. fprintd now resolves libfprint as:"
ldd /usr/libexec/fprintd | grep -E 'libfprint|not found' || true
