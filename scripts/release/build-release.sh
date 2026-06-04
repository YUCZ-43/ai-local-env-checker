#!/usr/bin/env bash
set -u

VERSION="0.3.0-preview"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="${2:-0.3.0-preview}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: bash scripts/release/build-release.sh [--version VERSION]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-local-env-checker-release.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT INT TERM

info() {
  printf '[release] %s\n' "$1"
}

warn() {
  printf '[release][WARN] %s\n' "$1" >&2
}

make_dir() {
  mkdir -p "$1"
}

copy_item() {
  rel="$1"
  dest_root="$2"
  src="$ROOT_DIR/$rel"
  dest="$dest_root/$rel"

  [ -e "$src" ] || return 0
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
}

init_placeholders() {
  package_root="$1"
  mkdir -p "$package_root/logs" "$package_root/reports"
  : > "$package_root/logs/.gitkeep"
  : > "$package_root/reports/.gitkeep"
}

copy_common() {
  package_root="$1"

  for file in README.md README.zh-CN.md README.en-US.md LICENSE SECURITY.md; do
    copy_item "$file" "$package_root"
  done

  copy_item docs "$package_root"
  copy_item locales "$package_root"
}

make_platform_package() {
  name="$1"
  shift
  package_root="$TMP_ROOT/$name"
  mkdir -p "$package_root"
  copy_common "$package_root"

  for script_dir in "$@"; do
    copy_item "$script_dir" "$package_root"
  done

  init_placeholders "$package_root"
  tar -czf "$DIST_DIR/ai-local-env-checker-$name-v$VERSION.tar.gz" -C "$package_root" .
}

make_source_tar() {
  tar -czf "$DIST_DIR/ai-local-env-checker-source-v$VERSION.tar.gz" \
    --exclude='./.git' \
    --exclude='./.git/*' \
    --exclude='./dist/*' \
    --exclude='./dist/*.zip' \
    --exclude='./dist/*.tar.gz' \
    --exclude='./dist/*.tgz' \
    --exclude='./dist/*.7z' \
    --exclude='./logs/*.log' \
    --exclude='./logs/.cmd-*' \
    --exclude='./reports/*.json' \
    --exclude='./reports/*.md' \
    --exclude='./.env' \
    --exclude='./.env.*' \
    --exclude='*.env' \
    --exclude='*.local' \
    --exclude='*.token' \
    --exclude='*.tokens' \
    --exclude='*.key' \
    --exclude='*.keys' \
    --exclude='*.pem' \
    --exclude='*.pfx' \
    --exclude='*.p12' \
    --exclude='id_rsa*' \
    --exclude='id_ed25519*' \
    --exclude='secrets.*' \
    --exclude='credentials.*' \
    --exclude='./.codex' \
    --exclude='./.codex/*' \
    --exclude='./.claude' \
    --exclude='./.claude/*' \
    -C "$ROOT_DIR" .
}

make_source_zip_if_available() {
  if ! command -v zip >/dev/null 2>&1; then
    warn "zip was not found. Skipping optional source ZIP package."
    return 0
  fi

  (
    cd "$ROOT_DIR" || exit 1
    zip -qr "$DIST_DIR/ai-local-env-checker-source-v$VERSION.zip" . \
      -x ".git/*" \
      -x "dist/*" \
      -x "dist/*.zip" \
      -x "dist/*.tar.gz" \
      -x "dist/*.tgz" \
      -x "dist/*.7z" \
      -x "logs/*.log" \
      -x "logs/.cmd-*" \
      -x "reports/*.json" \
      -x "reports/*.md" \
      -x ".env" \
      -x ".env.*" \
      -x "*.env" \
      -x "*.local" \
      -x "*.token" \
      -x "*.tokens" \
      -x "*.key" \
      -x "*.keys" \
      -x "*.pem" \
      -x "*.pfx" \
      -x "*.p12" \
      -x "id_rsa*" \
      -x "id_ed25519*" \
      -x "secrets.*" \
      -x "credentials.*" \
      -x ".codex/*" \
      -x ".claude/*"
  )
}

info "Repository root: $ROOT_DIR"
info "Version: $VERSION"

make_dir "$DIST_DIR"

info "Cleaning generated archives in dist/"
for pattern in \
  "$DIST_DIR"/ai-local-env-checker-*.zip \
  "$DIST_DIR"/ai-local-env-checker-*.tar.gz \
  "$DIST_DIR"/ai-local-env-checker-*.tgz \
  "$DIST_DIR"/ai-local-env-checker-*.7z
do
  [ -e "$pattern" ] && rm -f "$pattern"
done

make_platform_package wsl scripts/wsl scripts/linux || exit 1
make_platform_package linux scripts/linux || exit 1
make_platform_package macos scripts/macos || exit 1
make_source_tar || exit 1
make_source_zip_if_available || exit 1

info "Package list:"
for package_file in "$DIST_DIR"/ai-local-env-checker-*; do
  [ -f "$package_file" ] && printf '  %s\n' "$(basename "$package_file")"
done | sort
