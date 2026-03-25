#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_UI_DIR="$ROOT_DIR/app_ui"
BUNDLE_DIR="$APP_UI_DIR/build/linux/x64/release/bundle"
STAGE_ROOT="$ROOT_DIR/build/deb_stage"
DIST_DIR="$ROOT_DIR/dist/deb"
PKG_NAME="troodi-vpn"
PKG_DIR="$STAGE_ROOT/$PKG_NAME"

if [[ ! -x "$BUNDLE_DIR/xray_desktop_ui" ]]; then
  echo "Linux release bundle not found at $BUNDLE_DIR"
  echo "Build it first:"
  echo "  (cd app_ui && /home/troodi/.local/toolchains/flutter/bin/flutter build linux --release)"
  exit 1
fi

if [[ ! -x "$BUNDLE_DIR/core-manager" ]]; then
  echo "core-manager not found in release bundle: $BUNDLE_DIR/core-manager"
  echo "Copy the built backend into the bundle first."
  exit 1
fi

VERSION_RAW="$(sed -n 's/^version:[[:space:]]*//p' "$APP_UI_DIR/pubspec.yaml" | head -n 1)"
VERSION="${VERSION_RAW%%+*}"
ARCH="$(dpkg --print-architecture)"
OUT_FILE="$DIST_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"

RUNTIME_DEPENDS="libgtk-3-0, libstdc++6, libc6, libglib2.0-0, libgdk-pixbuf-2.0-0, libpango-1.0-0, libcairo2, libx11-6, libwayland-client0, libxkbcommon0, libepoxy0, libfontconfig1, libblkid1"

rm -rf "$PKG_DIR"
mkdir -p \
  "$PKG_DIR/DEBIAN" \
  "$PKG_DIR/opt/$PKG_NAME" \
  "$PKG_DIR/usr/bin" \
  "$PKG_DIR/usr/share/applications" \
  "$PKG_DIR/usr/share/icons/hicolor/256x256/apps"

cp -a "$BUNDLE_DIR/." "$PKG_DIR/opt/$PKG_NAME/"

install -m 0644 \
  "$ROOT_DIR/packaging/deb/troodi-vpn.desktop" \
  "$PKG_DIR/usr/share/applications/troodi-vpn.desktop"

install -m 0644 \
  "$APP_UI_DIR/lib/images/logo.png" \
  "$PKG_DIR/usr/share/icons/hicolor/256x256/apps/troodi-vpn.png"

install -m 0644 \
  "$APP_UI_DIR/lib/images/logo.png" \
  "$PKG_DIR/usr/share/icons/hicolor/256x256/apps/com.troodi.vpn.png"

cat > "$PKG_DIR/usr/bin/troodi-vpn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /opt/troodi-vpn/xray_desktop_ui "$@"
EOF
chmod 0755 "$PKG_DIR/usr/bin/troodi-vpn"

cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: net
Priority: optional
Architecture: $ARCH
Maintainer: Troodi VPN
Depends: $RUNTIME_DEPENDS
Description: Troodi VPN desktop client
 Troodi VPN is a Flutter + Go + Xray desktop client for Linux.
EOF

cat > "$PKG_DIR/DEBIAN/postinst" <<'EOF'
#!/usr/bin/env bash
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q /usr/share/icons/hicolor || true
fi
exit 0
EOF
chmod 0755 "$PKG_DIR/DEBIAN/postinst"

mkdir -p "$DIST_DIR"
dpkg-deb --build --root-owner-group "$PKG_DIR" "$OUT_FILE"
echo "Built: $OUT_FILE"
