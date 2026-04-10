#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/rootfs/build"
OVERLAY="$ROOT/rootfs/overlay"
PKG_LIST="$ROOT/packages/packages.list"
MIRROR="http://deb.debian.org/debian"
SUITE="bookworm"

echo "[rootfs] Building Debian $SUITE rootfs..."

# Require root
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: rootfs build requires root (use sudo)"
  exit 1
fi

# Clean previous build
rm -rf "$BUILD"
mkdir -p "$BUILD"

# Bootstrap minimal Debian
echo "[rootfs] Running debootstrap..."
debootstrap \
  --arch=amd64 \
  --variant=minbase \
  --include=systemd,systemd-sysv,dbus,sudo,curl,ca-certificates \
  "$SUITE" \
  "$BUILD" \
  "$MIRROR"

# Install package list into chroot
echo "[rootfs] Installing packages from packages.list..."
PACKAGES=$(grep -v '^#' "$PKG_LIST" | grep -v '^$' | tr '\n' ' ')

chroot "$BUILD" /bin/bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends $PACKAGES
  apt-get clean
  rm -rf /var/lib/apt/lists/*
"

# Install kernel modules
if [ -d "$ROOT/rootfs/modules" ]; then
  echo "[rootfs] Installing kernel modules..."
  cp -a "$ROOT/rootfs/modules/lib/modules" "$BUILD/lib/"
fi

# Apply overlay (branding, config, custom files)
echo "[rootfs] Applying overlay..."
cp -a "$OVERLAY/." "$BUILD/"

# Configure systemd services
chroot "$BUILD" /bin/bash -c "
  systemctl enable systemd-networkd
  systemctl enable systemd-resolved
  systemctl enable seatd
  systemctl enable ssh 2>/dev/null || true
"

# Create user babu
chroot "$BUILD" /bin/bash -c "
  useradd -m -s /usr/local/bin/qsh -G sudo,audio,video,input,_seatd babu 2>/dev/null || true
  HASH=\$(openssl passwd -6 qosx)
  sed -i \"s|^babu:[^:]*|babu:\$HASH|\" /etc/shadow
  sed -i \"s|^root:[^:]*|root:\$HASH|\" /etc/shadow
"

# Set hostname
echo "qosx" > "$BUILD/etc/hostname"

# Symlink resolv.conf for systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf "$BUILD/etc/resolv.conf"

echo "[rootfs] Done. Build at: rootfs/build"
