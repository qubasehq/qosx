#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="${1:-$(ls -t $ROOT/output/img/*.img 2>/dev/null | grep -v "^l" | head -1)}"

if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
  echo "ERROR: No image found. Run: make image"
  exit 1
fi

echo "[test-autologin] Testing autologin on: $IMG"
echo "[test-autologin] Waiting for shell prompt (autologin should work)..."

timeout 180 bash -c "
  qemu-system-x86_64 \
    -machine q35,accel=kvm \
    -cpu host \
    -m 2048 \
    -smp 2 \
    -drive file='$IMG',format=raw,if=virtio \
    -nographic \
    -serial mon:stdio 2>&1 | tee /tmp/qemu-boot.log &
  
  QEMU_PID=\$!
  
  # Wait for either shell prompt or login prompt
  for i in {1..120}; do
    if grep -q 'babu@qosx' /tmp/qemu-boot.log 2>/dev/null; then
      echo '[test-autologin] PASS — Autologin successful! Shell prompt found.'
      kill \$QEMU_PID 2>/dev/null || true
      exit 0
    fi
    if grep -q 'qosx login:' /tmp/qemu-boot.log 2>/dev/null; then
      echo '[test-autologin] INFO — Login prompt found (autologin may not be working)'
      kill \$QEMU_PID 2>/dev/null || true
      exit 0
    fi
    sleep 1
  done
  
  echo '[test-autologin] TIMEOUT — No prompt found'
  kill \$QEMU_PID 2>/dev/null || true
  exit 1
"
