#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="${1:-$ROOT/output/img/qosx.img}"
IMG_SIZE="10G"
BUILD="$ROOT/rootfs/build"
KERNEL_VERSION="6.6.30"
LOOP=""

cleanup() {
  echo "[image] Cleaning up mounts..."
  umount -lf /mnt/qosx/boot/efi 2>/dev/null || true
  umount -lf /mnt/qosx/boot      2>/dev/null || true
  umount -lf /mnt/qosx           2>/dev/null || true
  [ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: image build requires root"
  exit 1
fi

echo "[image] Creating $IMG ($IMG_SIZE)..."
mkdir -p "$(dirname "$IMG")"
qemu-img create -f raw "$IMG" "$IMG_SIZE"

# Partition: GPT, BIOS boot (1MB), EFI (100MB), root (rest)
parted -s "$IMG" \
  mklabel gpt \
  mkpart bios_boot 1MiB 2MiB \
  set 1 bios_grub on \
  mkpart ESP fat32 2MiB 102MiB \
  set 2 esp on \
  mkpart primary ext4 102MiB 100%

# Setup loop device
LOOP=$(losetup --find --partscan --show "$IMG")
echo "[image] Loop: $LOOP"

# Format partitions
mkfs.fat -F32 "${LOOP}p2"
mkfs.ext4 -q "${LOOP}p3"

# Mount
mkdir -p /mnt/qosx
mount "${LOOP}p3" /mnt/qosx
mkdir -p /mnt/qosx/boot/efi
mount "${LOOP}p2" /mnt/qosx/boot/efi

# Copy rootfs
echo "[image] Copying rootfs..."
rsync -a --exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' \
  "$BUILD/" /mnt/qosx/

# Copy kernel + initrd
cp "$ROOT/output/vmlinuz-$KERNEL_VERSION" /mnt/qosx/boot/vmlinuz
# Generate initramfs inside chroot
chroot /mnt/qosx /bin/bash -c "
  update-initramfs -c -k $KERNEL_VERSION 2>/dev/null || \
  mkinitramfs -o /boot/initrd.img-$KERNEL_VERSION $KERNEL_VERSION
" 2>/dev/null || cp /boot/initrd.img* /mnt/qosx/boot/initrd.img 2>/dev/null || true

# Install GRUB (BIOS + EFI)
echo "[image] Installing GRUB..."
grub-install \
  --target=i386-pc \
  --boot-directory=/mnt/qosx/boot \
  --recheck \
  "$LOOP"

grub-install \
  --target=x86_64-efi \
  --efi-directory=/mnt/qosx/boot/efi \
  --boot-directory=/mnt/qosx/boot \
  --removable \
  --recheck

# Install GRUB config
cp "$ROOT/config/grub/grub.cfg" /mnt/qosx/boot/grub/grub.cfg

echo "[image] Done: $IMG"
