#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${CACHE_DIR:-cache}"
SELECTED_ARCH=""
ACTION="all"
FORCE=0

usage() {
  cat <<USAGE
termux-rootfs

Usage:
  ./main.sh
  ./main.sh --arch aarch64
  ./main.sh --download-only
  ./main.sh --build-only
  ./main.sh --pack-only
  ./main.sh --force
  ./main.sh --list-arch
  ./main.sh --help

Supported Termux bootstrap architectures:
  aarch64
  arm
  i686
  x86_64
USAGE
}

detect_arch() {
  local machine
  machine="$(uname -m)"

  case "$machine" in
    aarch64|arm64)
      echo "aarch64"
      ;;
    armv7l|armv8l|armhf|arm)
      echo "arm"
      ;;
    x86_64|amd64)
      echo "x86_64"
      ;;
    i686|i386)
      echo "i686"
      ;;
    *)
      echo "error: unsupported architecture: $machine" >&2
      exit 1
      ;;
  esac
}

check_deps() {
  local missing=0

  for cmd in curl jq unzip tar zstd sha256sum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "error: missing dependency: $cmd" >&2
      missing=1
    fi
  done

  if [ "$missing" -eq 1 ]; then
    echo
    echo "Install dependencies with:"
    echo "  pkg install -y curl jq unzip tar zstd coreutils"
    exit 1
  fi
}

latest_release_json() {
  curl -fsSL "https://api.github.com/repos/termux/termux-packages/releases/latest"
}

list_available_arches() {
  local json
  json="$(latest_release_json)"

  printf '%s\n' "$json" | jq -r '
    .assets[].name
    | select(startswith("bootstrap-") and endswith(".zip"))
    | sub("^bootstrap-"; "")
    | sub("\\.zip$"; "")
  ' | sort
}

ensure_arch_available() {
  local arch="$1"
  local json="$2"

  if ! printf '%s\n' "$json" | jq -e --arg name "bootstrap-${arch}.zip" '
    any(.assets[]; .name == $name)
  ' >/dev/null; then
    echo "error: bootstrap-${arch}.zip is not available in the latest Termux release" >&2
    echo
    echo "Available architectures:"
    printf '%s\n' "$json" | jq -r '
      .assets[].name
      | select(startswith("bootstrap-") and endswith(".zip"))
      | sub("^bootstrap-"; "")
      | sub("\\.zip$"; "")
    ' | sort | sed 's/^/  - /'
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --arch)
      SELECTED_ARCH="${2:-}"
      if [ -z "$SELECTED_ARCH" ]; then
        echo "error: --arch requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --download-only)
      ACTION="download"
      shift
      ;;
    --build-only)
      ACTION="build"
      shift
      ;;
    --pack-only)
      ACTION="pack"
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --list-arch)
      check_deps
      list_available_arches
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

check_deps

ARCH="${SELECTED_ARCH:-$(detect_arch)}"

echo "[*] Host architecture detected/selected: $ARCH"

JSON="$(latest_release_json)"
TAG="$(printf '%s\n' "$JSON" | jq -r '.tag_name')"

echo "[*] Latest Termux bootstrap release: $TAG"

ensure_arch_available "$ARCH" "$JSON"

mkdir -p "$CACHE_DIR"

if [ "$FORCE" -eq 1 ]; then
  echo "[*] Force mode enabled, clearing cached bootstrap for $ARCH"
  rm -f "$CACHE_DIR/bootstrap-${ARCH}.zip" \
        "$CACHE_DIR/bootstrap-${ARCH}.zip.sha256" \
        "$CACHE_DIR/bootstrap-${ARCH}.zip.sha256.local"
fi

case "$ACTION" in
  all)
    scripts/fetch-bootstrap.sh "$ARCH"
    scripts/build-rootfs.sh "$ARCH"
    scripts/pack-rootfs.sh "$ARCH"
    ;;
  download)
    scripts/fetch-bootstrap.sh "$ARCH"
    ;;
  build)
    scripts/build-rootfs.sh "$ARCH"
    ;;
  pack)
    scripts/pack-rootfs.sh "$ARCH"
    ;;
  *)
    echo "error: invalid action: $ACTION" >&2
    exit 1
    ;;
esac

echo "[✓] Done"
