d → systemd → udev
├─────────────────────────────────────────┤
│  Toolchain / Build system               │  Makefile + bash scripts + CI
├─────────────────────────────────────────┤
│  Kernel                                 │  Linux 6.6.x, VirtIO, DRM, EXT4
└─────────────────────────────────────────┘
```

## Boot sequence

```
BIOS/UEFI → GRUB → vmlinuz → initrd → systemd → getty@tty1 → autologin babu → sway
```

## Graphics stack

```
Linux DRM/KMS (kernel)
  └── virtio-gpu (QEMU virtual GPU)
        └── Mesa (userspace GPU driver)
              └── libwayland (protocol)
                    └── seatd (seat management, rootless)
                          └── Sway (compositor + WM)
                                ├── Waybar (status bar)
                                ├── Foot (terminal)
                                ├── Mako (notifications)
                                └── Q-Dash (dashboard)
```

## Custom package integration

QShell and Q-Dash are packaged as `.deb` files.
They install into `/usr/local/bin/` and never touch system paths.
QShell is registered via `update-alternatives`. It does not replace `/bin/sh`.
Q-Dash is autostarted by Sway via `exec` in `/etc/sway/config`.

## Overlay system

`rootfs/overlay/` mirrors the target filesystem.
Applied after debootstrap via rsync.
Every system config change lives here — never edited inside `rootfs/build/`.
`rootfs/build/` is ephemeral. Wiped on every build.

## Reproducibility

`SOURCE_DATE_EPOCH` is set from the last git commit timestamp.
All build tools that embed timestamps respect this variable.
Two clean builds from the same commit produce identical SHA256 output.
