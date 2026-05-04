#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:-aarch64}"
BOX_NAME="termux-rootfs-${ARCH}"
ROOTFS="work/${BOX_NAME}/rootfs"
MANIFEST="work/${BOX_NAME}/manifest.json"
OUT_DIR="out"

if [ ! -d "$ROOTFS" ]; then
  echo "erro: rootfs não existe. corre: scripts/build-rootfs.sh $ARCH" >&2
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "erro: manifest não existe. a build falhou ou está incompleta." >&2
  echo "corre de novo: scripts/build-rootfs.sh $ARCH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

TAG="$(cat cache/latest-tag.txt 2>/dev/null || echo unknown)"
OUT_FILE="$OUT_DIR/termux-rootfs-${ARCH}-${TAG}.tar.zst"

rm -f "$OUT_FILE"

echo "[*] Packing rootfs..."
tar -C "$ROOTFS" -cf - . | zstd -q -19 -T0 -o "$OUT_FILE"

cp "$MANIFEST" "$OUT_DIR/manifest-${ARCH}-${TAG}.json"

(
  cd "$OUT_DIR"
  sha256sum "$(basename "$OUT_FILE")" "manifest-${ARCH}-${TAG}.json" > "SHA256SUMS-${ARCH}-${TAG}"
)

echo "[✓] Created: $OUT_FILE"
