#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:-aarch64}"
BOX_NAME="termux-rootfs-${ARCH}"

ROOTFS="work/${BOX_NAME}/rootfs"
PREFIX_DIR="$ROOTFS/data/data/com.termux/files/usr"
HOME_DIR="$ROOTFS/data/data/com.termux/files/home"
TMP_DIR="$PREFIX_DIR/tmp"

BOOTSTRAP="cache/bootstrap-${ARCH}.zip"
TAG_FILE="cache/latest-tag.txt"

if [ ! -f "$BOOTSTRAP" ]; then
  echo "[*] Bootstrap missing, downloading..."
  scripts/fetch-bootstrap.sh "$ARCH"
fi

rm -rf "work/${BOX_NAME}"
mkdir -p "$PREFIX_DIR" "$HOME_DIR" "$TMP_DIR"

echo "[*] Extracting bootstrap into sandbox prefix..."
unzip -q "$BOOTSTRAP" -d "$PREFIX_DIR"

scripts/restore-symlinks.sh "$PREFIX_DIR"

mkdir -p \
  "$ROOTFS/dev" \
  "$ROOTFS/proc" \
  "$ROOTFS/sys" \
  "$ROOTFS/system" \
  "$ROOTFS/sdcard" \
  "$ROOTFS/storage" \
  "$ROOTFS/tmp"

cat > "work/${BOX_NAME}/manifest.json" <<MANIFEST
{
  "name": "termux-rootfs",
  "arch": "$ARCH",
  "source": "termux/termux-packages",
  "bootstrap_tag": "$(cat "$TAG_FILE" 2>/dev/null || echo unknown)",
  "prefix": "/data/data/com.termux/files/usr",
  "home": "/data/data/com.termux/files/home",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
MANIFEST

cp "work/${BOX_NAME}/manifest.json" "$ROOTFS/manifest.json"

echo "[✓] Rootfs built at: $ROOTFS"
