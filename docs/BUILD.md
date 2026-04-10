# Build Reference

## Requirements

Host OS: Ubuntu 22.04 or Debian bookworm.  
Disk space: 30GB minimum.  
RAM: 8GB minimum for kernel compile.  
Must run build scripts as root (they use debootstrap, losetup, chroot).

## Stage-by-stage breakdown

### make kernel

- Downloads `linux-6.6.30.tar.xz` if not present in `kernel/`
- Extracts into `kernel/linux-6.6.30/`
- Copies `config/kernel/kernel.config` as `.config`
- Runs `make olddefconfig` to apply any new defaults
- Compiles with `make -j$(nproc)`
- Outputs `output/vmlinuz-6.6.30` and `output/System.map-6.6.30`
- Installs modules into `rootfs/modules/`

To change kernel version: edit `KERNEL_VERSION` in `scripts/build-kernel.sh` and update the URL.

### make rootfs

- Requires root
- Wipes `rootfs/build/` completely each run (idempotent)
- Runs `debootstrap --variant=minbase bookworm rootfs/build/`
- Reads `packages/packages.list`, strips comments, installs all packages via chroot apt
- Copies kernel modules from `rootfs/modules/` into rootfs
- Applies `rootfs/overlay/` on top (rsync)
- Creates user `babu`, sets passwords, configures systemd services

### make packages

- Does not require root
- Reads `packages/qshell/DEBIAN/control` and `packages/qdash/DEBIAN/control`
- Runs `dpkg-deb --build` on each package directory
- Outputs `.deb` files to `output/`
- Adds them to `repo/pool/` for reprepro indexing

### make graphics

- Requires root
- Must run after `make rootfs`
- chroot-installs Mesa, Wayland, Sway, seatd, pipewire into `rootfs/build/`
- Enables `seatd` systemd service

### make image

- Requires root
- Creates a 10GB raw disk image via `qemu-img`
- Partitions with GPT: BIOS boot (1MB) + EFI (100MB) + ext4 root (rest)
- Formats partitions, mounts, rsyncs rootfs in
- Installs GRUB for both BIOS and EFI targets
- Copies `config/grub/grub.cfg`
- Output: `output/img/qosx-<version>.img`

### make iso

- Requires root
- Requires `make image` to have completed
- Mounts the .img, creates squashfs from root partition
- Copies kernel + initrd into ISO staging area
- Runs xorriso to produce hybrid BIOS+EFI bootable ISO
- Output: `output/iso/qosx-<version>.iso`

### make test

- Does not require root
- Launches QEMU headless with serial output to `/tmp/qosx-boot-test.log`
- Polls log for string `qosx login:` every 2 seconds
- Times out after 120 seconds
- Exits 0 on success, 1 on failure
- Used by CI as the gate before release

### make run

- Does not require root
- Launches QEMU with `-device virtio-gpu-gl -display gtk,gl=on`
- Enables KVM if `/dev/kvm` is available
- Forwards SSH to host port 2222
- Serial output to stdout

## Common failures

| Error | Cause | Fix |
|-------|-------|-----|
| `debootstrap: command not found` | Missing dep | `sudo apt install debootstrap` |
| `losetup: no free loop device` | Stale loop from failed build | `sudo losetup -D` then retry |
| `grub-install: error` | Missing grub targets | `sudo apt install grub-pc-bin grub-efi-amd64-bin` |
| Boot test timeout | Kernel panic or wrong root device | Check grub.cfg `root=` param matches partition |
| `sway: cannot open display` | GPU not initialized | Ensure `CONFIG_DRM_VIRTIO_GPU=y` in kernel.config |
