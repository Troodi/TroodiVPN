#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"

APP_UI_DIR="$REPO_DIR/app_ui"
CORE_DIR="$REPO_DIR/core_manager"
CORE_BIN_DIR="$CORE_DIR/bin"
CORE_BIN_SRC="$CORE_BIN_DIR/core-manager"
BUNDLE_DIR="$APP_UI_DIR/build/linux/x64/release/bundle"
RELEASE_DIR="$REPO_DIR/dist/linux-release"

echo
echo "=== Troodi VPN - Build and Deploy (Linux) ==="
echo

echo "[1/5] Stopping running processes..."
for pattern in "xray_desktop_ui" "core-manager" "/bundle/xray run -c"; do
  pkill -f "$pattern" 2>/dev/null || true
done
sleep 1

if pgrep -fa "core-manager" >/dev/null 2>&1; then
  echo "  WARNING: core-manager still running (maybe root-owned)."
  echo "  Run manually and retry:"
  echo "    sudo pkill -f core-manager"
  exit 1
fi
echo "  OK"

echo "[2/5] Building core-manager..."
mkdir -p "$CORE_BIN_DIR"
(
  cd "$CORE_DIR"
  go build -o "$CORE_BIN_SRC" ./cmd/core-manager
)
echo "  OK"

echo "[3/5] Building Flutter app (linux release)..."
(
  cd "$APP_UI_DIR"
  flutter build linux --release
)
echo "  OK"

echo "[4/5] Staging release directory..."
if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "  Bundle folder not found: $BUNDLE_DIR"
  exit 1
fi
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
cp -a "$BUNDLE_DIR"/. "$RELEASE_DIR"/
cp -f "$CORE_BIN_SRC" "$RELEASE_DIR/core-manager"
echo "  OK"

echo "[5/5] Verifying..."
required=(
  "$RELEASE_DIR/xray_desktop_ui"
  "$RELEASE_DIR/core-manager"
  "$RELEASE_DIR/xray"
)
for file in "${required[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "  Missing required file: $file"
    exit 1
  fi
done

echo "  core-manager:   $(stat -c '%s bytes, %y' "$RELEASE_DIR/core-manager")"
echo "  xray_desktop_ui:$(stat -c '%s bytes, %y' "$RELEASE_DIR/xray_desktop_ui")"
echo "  xray:           $(stat -c '%s bytes, %y' "$RELEASE_DIR/xray")"

echo
echo "Deploy OK. Release directory:"
echo "  $RELEASE_DIR"
