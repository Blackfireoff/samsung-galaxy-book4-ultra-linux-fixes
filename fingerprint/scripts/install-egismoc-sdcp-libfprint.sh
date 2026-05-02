#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_url="${LIBFPRINT_EGISMOC_SDCP_REPO_URL:-https://github.com/TenSeventy7/libfprint-egismoc-sdcp.git}"
repo_ref="${LIBFPRINT_EGISMOC_SDCP_REF:-4d128d4f6f0b46182572126e84df88a73ac27859}"
repo_dir="${1:-"$script_dir/../build/libfprint-egismoc-sdcp"}"
patch_file="$script_dir/../patches/libfprint-egismoc-sdcp-openssl-helper.patch"
build_dir="$repo_dir/builddir"
multiarch="$(gcc -print-multiarch 2>/dev/null || true)"
multiarch="${multiarch:-x86_64-linux-gnu}"

missing=()
for cmd in git meson ninja gcc pkg-config; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done

for dep in glib-2.0 gio-unix-2.0 gobject-2.0 gusb openssl libudev; do
  if ! pkg-config --exists "$dep"; then
    missing+=("$dep")
  fi
done

if ((${#missing[@]})); then
  printf 'Missing build dependencies: %s\n\n' "${missing[*]}" >&2
  cat >&2 <<'EOF'
Install the required Ubuntu packages first:

sudo apt update
sudo apt install -y git meson ninja-build build-essential pkg-config \
  libglib2.0-dev libgusb-dev libssl-dev libudev-dev libusb-1.0-0-dev

Then re-run this script.
EOF
  exit 1
fi

if [[ ! -d "$repo_dir/.git" ]]; then
  mkdir -p "$(dirname -- "$repo_dir")"
  git clone "$repo_url" "$repo_dir"
fi

dirty_status="$(git -C "$repo_dir" status --porcelain -- . ":(exclude)builddir")"
if [[ -n "$dirty_status" ]]; then
  if [[ "$dirty_status" != " M meson.build" ]] ||
    ! grep -q "'egismoc' : \\[ 'openssl' \\]" "$repo_dir/meson.build"; then
    echo "Refusing to modify dirty libfprint tree: $repo_dir" >&2
    git -C "$repo_dir" status --short >&2
    exit 1
  fi
else
  git -C "$repo_dir" fetch --quiet origin
  git -C "$repo_dir" checkout --quiet "$repo_ref"
fi

if ! grep -q "'egismoc' : \\[ 'openssl' \\]" "$repo_dir/meson.build"; then
  git -C "$repo_dir" apply "$patch_file"
fi

# A manual clock change can leave cloned files dated in the future, and Meson
# aborts with "Clock skew detected". Normalize mtimes inside this build clone.
find "$repo_dir" -exec touch -h -c {} +

if ! lsusb | grep -qi '1c7a:05a1'; then
  echo "Warning: USB device 1c7a:05a1 was not found in lsusb output." >&2
fi

meson_setup_args=(
  --prefix=/usr/local
  --libdir="lib/$multiarch"
  -Ddrivers=egismoc
  -Dintrospection=false
  -Ddoc=false
  -Dinstalled-tests=false
  -Dudev_rules=disabled
  -Dudev_hwdb=disabled
)

if [[ -f "$build_dir/meson-private/coredata.dat" ]]; then
  meson setup "$build_dir" "$repo_dir" --wipe "${meson_setup_args[@]}"
else
  rm -rf "$build_dir"
  meson setup "$build_dir" "$repo_dir" "${meson_setup_args[@]}"
fi

meson compile -C "$build_dir"

backup_dir="/usr/local/lib/$multiarch/libfprint-backup-$(date +%Y%m%d-%H%M%S)"
if compgen -G "/usr/local/lib/$multiarch/libfprint-2.so*" >/dev/null; then
  sudo install -d "$backup_dir"
  sudo cp -a /usr/local/lib/"$multiarch"/libfprint-2.so* "$backup_dir"/
  echo "Existing /usr/local libfprint backup: $backup_dir"
fi

sudo meson install -C "$build_dir"
sudo ldconfig
sudo systemctl restart fprintd.service

echo
echo "fprintd now resolves libfprint as:"
ldd /usr/libexec/fprintd | grep -E 'libfprint|not found' || true

echo
echo "Next test:"
echo "  $script_dir/test-egismoc-sdcp-fingerprint.sh"
