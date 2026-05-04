#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:-aarch64}"
CACHE_DIR="${CACHE_DIR:-cache}"
API_URL="https://api.github.com/repos/termux/termux-packages/releases/latest"

mkdir -p "$CACHE_DIR"

ZIP_NAME="bootstrap-${ARCH}.zip"
ZIP_PATH="$CACHE_DIR/$ZIP_NAME"
TAG_PATH="$CACHE_DIR/latest-tag.txt"

echo "[*] Fetching latest Termux bootstrap metadata..."

JSON="$(curl -fsSL "$API_URL")"
TAG="$(printf '%s\n' "$JSON" | jq -r '.tag_name')"
BODY="$(printf '%s\n' "$JSON" | jq -r '.body // ""')"

ZIP_URL="$(printf '%s\n' "$JSON" | jq -r --arg name "$ZIP_NAME" '
  .assets[] | select(.name == $name) | .browser_download_url
')"

if [ -z "$ZIP_URL" ] || [ "$ZIP_URL" = "null" ]; then
  echo "erro: $ZIP_NAME não encontrado na release $TAG" >&2
  exit 1
fi

if [ -f "$ZIP_PATH" ] && [ -f "$TAG_PATH" ] && [ "$(cat "$TAG_PATH")" = "$TAG" ]; then
  echo "[✓] Cache already up to date: $ZIP_NAME ($TAG)"

  if unzip -tq "$ZIP_PATH" >/dev/null 2>&1; then
    echo "[✓] Cached zip looks valid"
    exit 0
  fi

  echo "[!] Cached zip is broken, downloading again..."
  rm -f "$ZIP_PATH"
fi

echo "[*] Latest release: $TAG"
echo "[*] Downloading $ZIP_NAME"

curl -fL "$ZIP_URL" -o "$ZIP_PATH"

echo "$TAG" > "$TAG_PATH"

if ! unzip -tq "$ZIP_PATH" >/dev/null 2>&1; then
  echo "erro: downloaded zip is invalid: $ZIP_PATH" >&2
  exit 1
fi

CHECKSUM_LINE="$(printf '%s\n' "$BODY" | grep -E "[a-fA-F0-9]{64}[[:space:]]+$ZIP_NAME" | head -n1 || true)"

if [ -n "$CHECKSUM_LINE" ]; then
  echo "[*] Verifying checksum from release body..."
  printf '%s\n' "$CHECKSUM_LINE" > "$CACHE_DIR/$ZIP_NAME.sha256"

  (
    cd "$CACHE_DIR"
    sha256sum -c "$ZIP_NAME.sha256"
  )
else
  echo "[!] Official checksum line not found in release body; generating local checksum"
  sha256sum "$ZIP_PATH" > "$CACHE_DIR/$ZIP_NAME.sha256.local"
fi

echo "[✓] Bootstrap ready: $ZIP_PATH"
