# QOSX Build System
# Usage: make <target>
# All targets are idempotent. Run from repo root only.

SHELL       := /bin/bash
ROOT        := $(shell pwd)
VERSION     := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
EPOCH       := $(shell git log -1 --pretty=%ct 2>/dev/null || date +%s)
ARCH        := x86_64
DEBIAN_SUITE := bookworm
MIRROR      := http://deb.debian.org/debian

IMG         := output/img/qosx-$(VERSION).img
ISO         := output/iso/qosx-$(VERSION).iso
IMG_SIZE    := 10G
LOOP_DEV    := /dev/loop8

export SOURCE_DATE_EPOCH=$(EPOCH)

.PHONY: all kernel rootfs packages graphics image iso test clean help

all: kernel rootfs packages image iso

## Kernel
kernel:
	@echo "[kernel] Building..."
	@scripts/build-kernel.sh

## Root filesystem
rootfs:
	@echo "[rootfs] Bootstrapping..."
	@scripts/build-rootfs.sh

## Custom packages (qshell, qdash)
packages:
	@echo "[packages] Building .deb packages..."
	@scripts/build-packages.sh

## Graphics stack install into rootfs
graphics:
	@echo "[graphics] Installing graphics stack..."
	@scripts/install-graphics.sh

## Assemble disk image
$(IMG):
	@echo "[image] Assembling $@..."
	@sudo scripts/build-image.sh $@

image: $(IMG)

## Wrap into bootable ISO
$(ISO): $(IMG)
	@echo "[iso] Creating $@..."
	@sudo scripts/build-iso.sh $(IMG) $@

iso: $(ISO)

## Boot test in QEMU headless — exits 0 if TTY prompt found
test: $(IMG)
	@echo "[test] Running boot test..."
	@scripts/test-boot.sh $(IMG)

## Boot with GUI (interactive)
run: $(IMG)
	@echo "[run] Launching QEMU with disk image..."
	@scripts/run-qemu.sh $(IMG)

## Boot ISO with GUI (interactive)
run-iso: $(ISO)
	@echo "[run] Launching QEMU with ISO CD-ROM..."
	@scripts/run-qemu.sh $(ISO)

## Clean build artifacts (not source)
clean:
	rm -rf output/img/*.img output/iso/*.iso
	rm -rf rootfs/build

help:
	@grep -E '^##' Makefile | sed 's/## /  /'
