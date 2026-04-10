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

# Mount DNS resolution into chroot
mount --bind /etc/resolv.conf "$BUILD/etc/resolv.conf"

chroot "$BUILD" /bin/bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    libdrm2 libdrm-common \
    libgl1-mesa-dri libgles2-mesa mesa-vulkan-drivers \
    libwayland-client0 libwayland-server0 libwayland-egl1 \
    libinput10 libxkbcommon0 \
    xkb-data \
    sway swaybg swayidle swaylock \
    foot \
    grim slurp wl-clipboard \
    mako-notifier waybar \
    seatd \
    pipewire pipewire-pulse wireplumber \
    fonts-noto-core fonts-noto-mono
  apt-get clean
  rm -rf /var/lib/apt/lists/*
  systemctl enable seatd
"

# Unmount DNS resolution
umount "$BUILD/etc/resolv.conf" 2>/dev/null || true

echo "[graphics] Done."
