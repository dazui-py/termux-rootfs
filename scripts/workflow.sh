#!/usr/bin/env bash
set -euo pipefail

ARCHES_INPUT="${ARCHES:-}"
FORCE="${FORCE:-0}"
SKIP_IF_RELEASE_EXISTS="${SKIP_IF_RELEASE_EXISTS:-0}"
REPO="${GITHUB_REPOSITORY:-}"

log() {
  printf '[*] %s\n' "$*"
}

ok() {
  printf '[✓] %s\n' "$*"
}

err() {
  printf 'error: %s\n' "$*" >&2
}

require_cmds() {
  local missing=0

  for cmd in curl jq unzip tar zstd sha256sum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      err "missing dependency: $cmd"
      missing=1
    fi
  done

  if [ "$missing" -eq 1 ]; then
    exit 1
  fi
}

latest_termux_tag() {
  curl -fsSL "https://api.github.com/repos/termux/termux-packages/releases/latest" |
    jq -r '.tag_name'
}

release_exists() {
  local tag="$1"

  if ! command -v gh >/dev/null 2>&1; then
    return 1
  fi

  if [ -n "$REPO" ]; then
    gh release view "$tag" --repo "$REPO" >/dev/null 2>&1
  else
    gh release view "$tag" >/dev/null 2>&1
  fi
}

available_arches() {
  ./main.sh --list-arch
}

normalize_arches() {
  if [ -n "$ARCHES_INPUT" ]; then
    printf '%s\n' "$ARCHES_INPUT" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d'
  else
    available_arches
  fi
}

main() {
  require_cmds

  local tag
  tag="$(latest_termux_tag)"

  log "Latest Termux bootstrap tag: $tag"

  if [ "$SKIP_IF_RELEASE_EXISTS" = "1" ] && [ "$FORCE" != "1" ]; then
    if release_exists "$tag"; then
      ok "Release already exists for $tag; skipping build"

      if [ -n "${GITHUB_OUTPUT:-}" ]; then
        {
          echo "tag=$tag"
          echo "built=false"
        } >> "$GITHUB_OUTPUT"
      fi

      exit 0
    fi
  fi

  rm -rf out
  mkdir -p out

  log "Building rootfs artifacts"

  while IFS= read -r arch; do
    [ -z "$arch" ] && continue

    log "Building architecture: $arch"

    rm -rf "work/termux-rootfs-${arch}"

    if [ "$FORCE" = "1" ]; then
      ./main.sh --arch "$arch" --force
    else
      ./main.sh --arch "$arch"
    fi
  done < <(normalize_arches)

  log "Final artifacts:"
  ls -lh out

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "tag=$tag"
      echo "built=true"
    } >> "$GITHUB_OUTPUT"
  fi

  ok "Workflow build complete"
}

main "$@"
