#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(git describe --tags --always --dirty 2>/dev/null || echo "dev")}"

# Find the most recent image if exact version doesn't exist
if [ ! -f "$ROOT/output/img/qosx-$VERSION.img" ]; then
  IMG=$(ls -t $ROOT/output/img/qosx-*.img 2>/dev/null | head -1)
  if [ -z "$IMG" ]; then
    echo "[test] ERROR: No image found in output/img/"
    exit 1
  fi
  echo "[test] Using most recent image: $(basename "$IMG")"
else
  IMG="$ROOT/output/img/qosx-$VERSION.img"
fi

TIMEOUT=120
SUCCESS_STRING="qosx login:"
LOG="/tmp/qosx-boot-test.log"

echo "[test] Boot testing: $IMG"
echo "[test] Waiting for: '$SUCCESS_STRING' (timeout: ${TIMEOUT}s)"

# Detect KVM — don't hardcode, CI runners may not have it
ACCEL="tcg"
CPU_FLAG="-cpu max"
if [ -r /dev/kvm ]; then
  ACCEL="kvm"
  CPU_FLAG="-cpu host"
  echo "[test] KVM enabled"
else
  echo "[test] KVM not available, using TCG (slower)"
fi

# Clean stale log
rm -f "$LOG"

OVERLAY="/tmp/qosx-test.qcow2"
rm -f "$OVERLAY"
qemu-img create -f qcow2 -b "$(realpath "$IMG")" -F raw "$OVERLAY" >/dev/null

# Launch QEMU headless with serial output to log
timeout "$TIMEOUT" qemu-system-x86_64 \
  -machine q35,accel=$ACCEL \
  $CPU_FLAG \
  -m 2048 \
  -smp 2 \
  -drive file="$OVERLAY",format=qcow2,if=virtio \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -nographic \
  -serial file:"$LOG" \
  -no-reboot \
  & QEMU_PID=$!

# Poll log for success string
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  if [ -f "$LOG" ] && grep -q "$SUCCESS_STRING" "$LOG" 2>/dev/null; then
    echo "[test] PASS — '$SUCCESS_STRING' found at ${ELAPSED}s"
    kill $QEMU_PID 2>/dev/null || true
    exit 0
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

echo "[test] FAIL — '$SUCCESS_STRING' not found within ${TIMEOUT}s"
echo "[test] Last 20 lines of serial output:"
tail -20 "$LOG" 2>/dev/null || echo "(no log)"
kill $QEMU_PID 2>/dev/null || true
exit 1
