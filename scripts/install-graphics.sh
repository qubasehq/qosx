#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/rootfs/build"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: requires root"
  exit 1
fi

if [ ! -d "$BUILD" ]; then
  echo "ERROR: rootfs not built. Run: make rootfs"
  exit 1
fi

echo "[graphics] Installing graphics stack into rootfs..."

# Cleanup on exit
cleanup_graphics() {
  echo "[graphics] Cleaning up mounts..."
  umount -lf "$BUILD/proc"    2>/dev/null || true
  umount -lf "$BUILD/sys"     2>/dev/null || true
  umount -lf "$BUILD/dev/pts" 2>/dev/null || true
  umount -lf "$BUILD/dev"     2>/dev/null || true
  umount -lf "$BUILD/run"     2>/dev/null || true
  # Restore resolv.conf symlink
  rm -f "$BUILD/etc/resolv.conf" 2>/dev/null || true
  ln -sf /run/systemd/resolve/stub-resolv.conf "$BUILD/etc/resolv.conf" 2>/dev/null || true
}
trap cleanup_graphics EXIT

# Bind mount proc/sys/dev for chroot — needed by package postinst scripts
mount --bind /proc    "$BUILD/proc"
mount --bind /sys     "$BUILD/sys"
mount --bind /dev     "$BUILD/dev"
mount --bind /dev/pts "$BUILD/dev/pts"
mkdir -p "$BUILD/run"
mount --bind /run     "$BUILD/run"

# Copy host DNS into chroot
rm -f "$BUILD/etc/resolv.conf"
cp /etc/resolv.conf "$BUILD/etc/resolv.conf"

chroot "$BUILD" /bin/bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    xserver-xorg xserver-xorg-video-all xserver-xorg-input-all \
    libdrm2 libdrm-common \
    libgl1-mesa-dri libgles2 mesa-vulkan-drivers \
    xkb-data \
    gnome-core gdm3 gnome-shell-extension-dashtodock \
    gnome-tweaks gnome-control-center gnome-terminal nautilus \
    adwaita-icon-theme-full arc-theme papirus-icon-theme \
    seatd \
    pipewire pipewire-pulse wireplumber \
    fonts-noto-core fonts-noto-mono
  apt-get clean
  rm -rf /var/lib/apt/lists/*
  systemctl enable seatd
  systemctl enable gdm3
"

echo "[graphics] Done."
