#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_VERSION="6.6.30"
KERNEL_SRC="$ROOT/kernel/linux-$KERNEL_VERSION"
KERNEL_TAR="$ROOT/kernel/linux-$KERNEL_VERSION.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz"
OUTPUT="$ROOT/output"

# Ensure build directories exist
mkdir -p "$ROOT/kernel" "$OUTPUT"

# Ensure SOURCE_DATE_EPOCH is a valid integer (Unix timestamp)
if ! [[ "${SOURCE_DATE_EPOCH:-}" =~ ^[0-9]+$ ]]; then
  SOURCE_DATE_EPOCH="$(date +%s)"
fi
export SOURCE_DATE_EPOCH

echo "[kernel] version=$KERNEL_VERSION epoch=$SOURCE_DATE_EPOCH"

# Download if not present
if [ ! -f "$KERNEL_TAR" ]; then
  echo "[kernel] Downloading..."
  wget -q -O "$KERNEL_TAR" "$KERNEL_URL"
fi

# Extract if not present
if [ ! -d "$KERNEL_SRC" ]; then
  echo "[kernel] Extracting..."
  tar -xf "$KERNEL_TAR" -C "$ROOT/kernel/"
fi

cd "$KERNEL_SRC"

# Apply config from repo
cp "$ROOT/config/kernel/kernel.config" .config
make olddefconfig

# Build
echo "[kernel] Compiling with $(nproc) jobs..."
make -j"$(nproc)" bzImage modules

# Install
mkdir -p "$OUTPUT/img" "$OUTPUT/iso"
cp arch/x86/boot/bzImage "$OUTPUT/vmlinuz-$KERNEL_VERSION"
cp System.map "$OUTPUT/System.map-$KERNEL_VERSION"

# Install modules into a staging dir for rootfs
mkdir -p "$ROOT/rootfs/modules"
make INSTALL_MOD_PATH="$ROOT/rootfs/modules" modules_install

echo "[kernel] Done. Artifact: output/vmlinuz-$KERNEL_VERSION"
