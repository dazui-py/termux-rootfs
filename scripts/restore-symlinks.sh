#!/usr/bin/env bash
set -euo pipefail

PREFIX_DIR="${1:?uso: restore-symlinks.sh <prefix-dir>}"
PREFIX_DIR="$(cd "$PREFIX_DIR" && pwd -P)"
SYMLINKS="$PREFIX_DIR/SYMLINKS.txt"

if [ ! -f "$SYMLINKS" ]; then
  echo "[*] No SYMLINKS.txt found"
  exit 0
fi

echo "[*] Restoring symlinks..."

cd "$PREFIX_DIR"

while IFS= read -r line; do
  [ -z "$line" ] && continue

  target="${line%%←*}"
  link="${line#*←}"

  [ -z "$target" ] && continue
  [ -z "$link" ] && continue
  [ "$target" = "$line" ] && continue

  rm -f "$link"
  mkdir -p "$(dirname "$link")"
  ln -s "$target" "$link"
done < "$SYMLINKS"

rm -f "$SYMLINKS"

echo "[✓] Symlinks restored"
