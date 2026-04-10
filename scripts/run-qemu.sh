#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="${1:-$(ls $ROOT/output/img/*.img 2>/dev/null | tail -1)}"

if [ -z "$IMG" ]; then
  echo "ERROR: No image found. Run: make image"
  exit 1
fi

echo "[run] Launching: $IMG"

# Detect KVM
ACCEL="tcg"
if [ -r /dev/kvm ]; then
  ACCEL="kvm"
  echo "[run] KVM enabled"
fi

qemu-system-x86_64 \
  -machine q35,accel=$ACCEL \
  -cpu host \
  -m 4096 \
  -smp 4 \
  -drive file="$IMG",format=raw,if=virtio \
  -device virtio-gpu-gl \
  -display gtk,gl=on \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device virtio-keyboard-pci \
  -device virtio-mouse-pci \
  -device virtio-tablet-pci \
  -audiodev pa,id=audio0 \
  -device virtio-sound-pci,audiodev=audio0 \
  -serial stdio \
  -usb \
  "$@"
