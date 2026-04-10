#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="${1:-$(ls -t $ROOT/output/img/*.img 2>/dev/null | grep -v "^l" | head -1)}"

if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
  echo "ERROR: No image found. Run: make image"
  exit 1
fi

echo "[test-login] Testing login on: $IMG"
echo "[test-login] Starting QEMU, will auto-login as babu..."
echo "[test-login] If you see a shell prompt, login worked!"
echo "[test-login] Type 'exit' to quit"
echo ""

# Launch QEMU with serial console
qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -m 2048 \
  -smp 2 \
  -drive file="$IMG",format=raw,if=virtio \
  -nographic \
  -serial mon:stdio
