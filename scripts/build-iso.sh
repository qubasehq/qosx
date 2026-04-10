#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="${1:-$ROOT/output/img/qosx.img}"
ISO="${2:-$ROOT/output/iso/qosx.iso}"
ISOWORK="$ROOT/output/isowork"
KERNEL_VERSION="6.6.30"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: ISO build requires root"
  exit 1
fi

echo "[iso] Building $ISO from $IMG..."

# Cleanup on exit
LOOP=""
cleanup_iso() {
  umount /mnt/qosx-iso 2>/dev/null || true
  [ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
}
trap cleanup_iso EXIT

rm -rf "$ISOWORK"
mkdir -p "$ISOWORK"/{boot/grub,live,EFI/boot}

# Mount the image and extract squashfs
LOOP=$(losetup --find --partscan --show "$IMG")
mkdir -p /mnt/qosx-iso
mount "${LOOP}p3" /mnt/qosx-iso

echo "[iso] Preparing Live overrides..."
mkdir -p "$ISOWORK/rootfs_overrides/etc"
# Provide an empty fstab for the Live system to prevent mount conflicts
echo "# Live ISO fstab" > "$ISOWORK/rootfs_overrides/etc/fstab"

echo "[iso] Creating squashfs filesystem..."
# Merge rootfs and overrides. No exclusions to ensure /dev, /proc, /sbin exist.
mksquashfs /mnt/qosx-iso "$ISOWORK/rootfs_overrides" "$ISOWORK/live/filesystem.squashfs" \
  -comp xz \
  -noappend

# Copy kernel — use versioned filename that actually exists
cp /mnt/qosx-iso/boot/vmlinuz-$KERNEL_VERSION "$ISOWORK/boot/vmlinuz"

# Copy or generate initrd
if [ -f /mnt/qosx-iso/boot/initrd.img-$KERNEL_VERSION ]; then
  cp /mnt/qosx-iso/boot/initrd.img-$KERNEL_VERSION "$ISOWORK/boot/initrd.img"
else
  echo "[iso] WARNING: No initrd found, ISO may not boot"
fi

# Copy GRUB modules from the mounted image
mkdir -p "$ISOWORK/boot/grub/i386-pc"
mkdir -p "$ISOWORK/boot/grub/x86_64-efi"
cp -a /mnt/qosx-iso/boot/grub/i386-pc/. "$ISOWORK/boot/grub/i386-pc/" 2>/dev/null || true
cp -a /mnt/qosx-iso/boot/grub/x86_64-efi/. "$ISOWORK/boot/grub/x86_64-efi/" 2>/dev/null || true

umount /mnt/qosx-iso
losetup -d "$LOOP"
LOOP=""

# GRUB config for ISO
cat > "$ISOWORK/boot/grub/grub.cfg" << 'EOF'
set timeout=5
set default=0

menuentry "QOSX Live" {
  linux  /boot/vmlinuz boot=live components quiet splash
  initrd /boot/initrd.img
}

menuentry "QOSX Live (recovery)" {
  linux  /boot/vmlinuz boot=live components single
  initrd /boot/initrd.img
}
EOF

# Generate EFI boot image
mkdir -p "$ISOWORK/EFI/boot"
grub-mkimage \
  --format=x86_64-efi \
  --output="$ISOWORK/EFI/boot/bootx64.efi" \
  --prefix=/boot/grub \
  part_gpt part_msdos fat iso9660 normal boot linux echo configfile \
  search search_label search_fs_uuid ls all_video gfxterm gfxterm_background \
  gfxmenu png jpeg ext2 squash4

# Generate eltorito BIOS boot image
grub-mkimage \
  --format=i386-pc-eltorito \
  --output="$ISOWORK/boot/grub/i386-pc/eltorito.img" \
  --prefix=/boot/grub \
  part_gpt part_msdos biosdisk iso9660 normal boot linux echo configfile \
  search ls ext2 squash4

# Create EFI partition image for xorriso
dd if=/dev/zero of="$ISOWORK/boot/grub/efi.img" bs=1M count=4
mkfs.fat "$ISOWORK/boot/grub/efi.img"
mmd -i "$ISOWORK/boot/grub/efi.img" ::/EFI ::/EFI/boot
mcopy -i "$ISOWORK/boot/grub/efi.img" \
  "$ISOWORK/EFI/boot/bootx64.efi" ::/EFI/boot/

# Build ISO (EFI + BIOS hybrid)
echo "[iso] Running xorriso..."
xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "QOSX" \
  -eltorito-boot boot/grub/i386-pc/eltorito.img \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  --efi-boot boot/grub/efi.img \
  -efi-boot-part \
  --efi-boot-image \
  --protective-msdos-label \
  -output "$ISO" \
  "$ISOWORK"

rm -rf "$ISOWORK"

# Set ownership back to the invoking user if run via sudo
if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
  chown "$SUDO_UID:$SUDO_GID" "$ISO"
fi

echo "[iso] Done: $ISO"
echo "[iso] SHA256: $(sha256sum "$ISO")"
