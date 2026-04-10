#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$ROOT/repo"

echo "[packages] Building custom .deb packages..."

build_deb() {
  PKG_DIR="$1"
  PKG_NAME=$(basename "$PKG_DIR")
  CTRL="$PKG_DIR/DEBIAN/control"

  if [ ! -f "$CTRL" ]; then
    echo "[packages] Skipping $PKG_NAME — no DEBIAN/control found"
    return
  fi

  VERSION=$(grep ^Version "$CTRL" | awk '{print $2}')
  ARCH=$(grep ^Architecture "$CTRL" | awk '{print $2}')
  DEB="$ROOT/output/$PKG_NAME-${VERSION}_${ARCH}.deb"

  echo "[packages] Building $PKG_NAME $VERSION..."

  # Build binary if Makefile present
  if [ -f "$PKG_DIR/Makefile" ]; then
    make -C "$PKG_DIR" PREFIX="$PKG_DIR/usr/local"
  fi

  dpkg-deb --build "$PKG_DIR" "$DEB"
  echo "[packages] Built: $DEB"

  # Add to local repo
  mkdir -p "$REPO/pool"
  cp "$DEB" "$REPO/pool/"
}

build_deb "$ROOT/packages/qshell"
build_deb "$ROOT/packages/qdash"

# Regenerate repo index
if [ -f "$REPO/conf/distributions" ]; then
  cd "$REPO"
  reprepro includedeb qosx pool/*.deb 2>/dev/null || true
fi

echo "[packages] Done."
