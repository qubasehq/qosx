#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/rootfs/build"
OVERLAY="$ROOT/rootfs/overlay"
PKG_LIST="$ROOT/packages/packages.list"
MIRROR="http://deb.debian.org/debian"
SUITE="bookworm"

echo "[rootfs] Building Debian $SUITE rootfs..."

# Require root
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: rootfs build requires root (use sudo)"
  exit 1
fi

# Cleanup function — unmount bind mounts on exit/error
cleanup_chroot() {
  echo "[rootfs] Cleaning up chroot mounts..."
  umount -lf "$BUILD/proc"  2>/dev/null || true
  umount -lf "$BUILD/sys"   2>/dev/null || true
  umount -lf "$BUILD/dev/pts" 2>/dev/null || true
  umount -lf "$BUILD/dev"   2>/dev/null || true
  umount -lf "$BUILD/run"   2>/dev/null || true
  # Restore resolv.conf symlink for systemd-resolved
  rm -f "$BUILD/etc/resolv.conf" 2>/dev/null || true
  ln -sf /run/systemd/resolve/stub-resolv.conf "$BUILD/etc/resolv.conf" 2>/dev/null || true
}
trap cleanup_chroot EXIT

# Clean previous build
rm -rf "$BUILD"
mkdir -p "$BUILD"

# Bootstrap minimal Debian
echo "[rootfs] Running debootstrap..."
debootstrap \
  --arch=amd64 \
  --variant=minbase \
  --include=systemd,systemd-sysv,dbus,sudo,curl,ca-certificates,locales,gnupg \
  "$SUITE" \
  "$BUILD" \
  "$MIRROR"

# Add non-free and non-free-firmware to sources.list
echo "deb $MIRROR $SUITE main contrib non-free non-free-firmware" > "$BUILD/etc/apt/sources.list"
echo "deb $MIRROR $SUITE-updates main contrib non-free non-free-firmware" >> "$BUILD/etc/apt/sources.list"
echo "deb http://security.debian.org/debian-security $SUITE-security main contrib non-free non-free-firmware" >> "$BUILD/etc/apt/sources.list"

# --- Bind mount proc/sys/dev for chroot operations ---
echo "[rootfs] Setting up chroot bind mounts..."
mount --bind /proc    "$BUILD/proc"
mount --bind /sys     "$BUILD/sys"
mount --bind /dev     "$BUILD/dev"
mount --bind /dev/pts "$BUILD/dev/pts"
mkdir -p "$BUILD/run"
mount --bind /run     "$BUILD/run"

# Copy host DNS into chroot so apt can resolve
cp /etc/resolv.conf "$BUILD/etc/resolv.conf"

# Install package list into chroot
echo "[rootfs] Installing packages from packages.list..."
PACKAGES=$(grep -v '^#' "$PKG_LIST" | grep -v '^$' | tr '\n' ' ')

chroot "$BUILD" /bin/bash -c "
  export DEBIAN_FRONTEND=noninteractive
  # Generate locales
  sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen
  update-locale LANG=en_US.UTF-8

  apt-get update -qq
  apt-get install -y --no-install-recommends $PACKAGES
  apt-get clean
  rm -rf /var/lib/apt/lists/*
"

# Install kernel modules
if [ -d "$ROOT/rootfs/modules/lib/modules" ]; then
  echo "[rootfs] Installing kernel modules..."
  cp -a "$ROOT/rootfs/modules/lib/modules" "$BUILD/lib/"
fi

# Apply overlay (branding, config, custom files)
echo "[rootfs] Applying overlay..."
cp -a --no-preserve=ownership "$OVERLAY/." "$BUILD/"

# Copy os-release branding
if [ -f "$ROOT/config/branding/os-release" ]; then
  echo "[rootfs] Installing os-release branding..."
  cp "$ROOT/config/branding/os-release" "$BUILD/etc/os-release"
fi

# Fix sudoers permissions (sudo requires 0440)
chmod 0440 "$BUILD/etc/sudoers.d/babu"

# Fix sway log directory permissions
mkdir -p "$BUILD/var/log/qosx"
chmod 0777 "$BUILD/var/log/qosx"

# Configure systemd services
echo "[rootfs] Enabling systemd services..."
chroot "$BUILD" /bin/bash -c "
  systemctl enable systemd-networkd
  systemctl enable systemd-resolved
  systemctl enable seatd
  systemctl enable gdm3 2>/dev/null || true
  systemctl enable ssh 2>/dev/null || true
  dconf update 2>/dev/null || true
"

# Install custom .deb packages if present
echo "[rootfs] Installing custom .deb packages..."
for deb in "$ROOT"/output/*.deb; do
  if [ -f "$deb" ]; then
    cp "$deb" "$BUILD/tmp/"
    chroot "$BUILD" dpkg -i "/tmp/$(basename "$deb")" || true
    rm -f "$BUILD/tmp/$(basename "$deb")"
    echo "[rootfs] Installed: $(basename "$deb")"
  fi
done

# Create user babu and set passwords
echo "[rootfs] Creating user babu and setting passwords..."

# Ensure required groups exist before adding user to them
chroot "$BUILD" /bin/bash -c "
  getent group _seatd >/dev/null 2>&1 || groupadd -r _seatd
  getent group render >/dev/null 2>&1 || groupadd -r render
  getent group input  >/dev/null 2>&1 || groupadd -r input
  getent group video  >/dev/null 2>&1 || groupadd -r video
  getent group audio  >/dev/null 2>&1 || groupadd -r audio
  id babu >/dev/null 2>&1 || useradd -m -s /usr/local/bin/qsh -G sudo,audio,video,render,input,_seatd babu
"

# Set passwords using chpasswd (safer than raw sed on shadow)
chroot "$BUILD" /bin/bash -c "
  echo 'root:qosx' | chpasswd
  echo 'babu:qosx' | chpasswd
"

echo "[rootfs] Passwords set for babu and root"

# Set hostname
echo "qosx" > "$BUILD/etc/hostname"

# Fix ping SUID bit (capabilities are lost during make_ext4fs)
chmod u+s "$BUILD/bin/ping" "$BUILD/usr/bin/ping" 2>/dev/null || true

# Unmount chroot binds (trap will also do this, but be explicit)
umount -lf "$BUILD/run"     2>/dev/null || true
umount -lf "$BUILD/dev/pts" 2>/dev/null || true
umount -lf "$BUILD/dev"     2>/dev/null || true
umount -lf "$BUILD/sys"     2>/dev/null || true
umount -lf "$BUILD/proc"    2>/dev/null || true

# Symlink resolv.conf for systemd-resolved (final state for booted system)
rm -f "$BUILD/etc/resolv.conf"
ln -sf /run/systemd/resolve/stub-resolv.conf "$BUILD/etc/resolv.conf"

echo "[rootfs] Done. Build at: rootfs/build"
