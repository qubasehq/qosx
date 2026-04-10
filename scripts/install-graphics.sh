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

chroot "$BUILD" /bin/bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    libdrm2 libdrm-common \
    libgl1-mesa-dri libgles2-mesa mesa-vulkan-drivers \
    libwayland-client0 libwayland-server0 libwayland-egl1 \
    libinput10 libxkbcommon0 libxkbcommon-x11-0 \
    xkb-data \
    sway swaybg swayidle swaylock \
    foot \
    grim slurp wl-clipboard \
    mako-notifier waybar \
    seatd \
    pipewire pipewire-pulse wireplumber \
    fonts-noto-core fonts-noto-mono fonts-noto-color-emoji
  apt-get clean
  rm -rf /var/lib/apt/lists/*
  systemctl enable seatd
"

echo "[graphics] Done."
