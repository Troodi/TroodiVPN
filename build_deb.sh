#!/usr/bin/env bash
# Build a .deb for Troodi VPN (amd64). Runs deploy_linux.sh unless skipped.
#
# Build-time tools (host): bash, flutter, go, dpkg-deb, coreutils.
# Runtime deps are declared in DEBIAN/control (GTK, Wayland/X11, sudo, iproute2, …).
#
# Usage:
#   ./build_deb.sh                 # full rebuild + .deb
#   TROODI_DEB_SKIP_BUILD=1 ./build_deb.sh   # package dist/linux-release as-is
#
# Output:
#   dist/troodi-vpn_<version>_amd64.deb

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
APP_UI_DIR="$REPO_DIR/app_ui"
PUBSPEC="$APP_UI_DIR/pubspec.yaml"
RELEASE_DIR="$REPO_DIR/dist/linux-release"
OUT_DEB_DIR="$REPO_DIR/dist"
LOGO_SRC="$APP_UI_DIR/lib/images/logo.png"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v dpkg-deb >/dev/null 2>&1 || die "dpkg-deb not found (install: sudo apt install dpkg-dev)"

[[ -f "$PUBSPEC" ]] || die "pubspec not found: $PUBSPEC"

# version: 0.1.0+1 -> deb 0.1.0-1
read -r APP_VERSION APP_BUILD <<<"$(awk '
  /^version:/ {
    gsub(/^version:[[:space:]]+/, "")
    gsub(/\r/, "")
    sub(/\+/, " ")
    print
    exit
  }
' "$PUBSPEC")"
[[ -n "${APP_VERSION:-}" ]] || die "could not parse version from pubspec.yaml"
DEB_REV="${APP_BUILD:-1}"
PKG_VER="${APP_VERSION}-${DEB_REV}"

ARCH="amd64"
PKG_NAME="troodi-vpn"
INSTALL_ROOT="/opt/troodi-vpn"
STAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/${PKG_NAME}-deb.XXXXXX")"
cleanup() { rm -rf "$STAGE_ROOT"; }
trap cleanup EXIT

echo
echo "=== Troodi VPN — .deb build (${PKG_VER}, ${ARCH}) ==="
echo

if [[ "${TROODI_DEB_SKIP_BUILD:-0}" != "1" ]]; then
  (cd "$REPO_DIR" && bash ./deploy_linux.sh)
else
  echo "[skip] TROODI_DEB_SKIP_BUILD=1 — using existing $RELEASE_DIR"
fi

[[ -d "$RELEASE_DIR" ]] || die "release dir missing: $RELEASE_DIR (run ./deploy_linux.sh)"
[[ -f "$RELEASE_DIR/xray_desktop_ui" ]] || die "missing binary: $RELEASE_DIR/xray_desktop_ui"

mkdir -p "$STAGE_ROOT${INSTALL_ROOT}"
cp -a "$RELEASE_DIR"/. "$STAGE_ROOT${INSTALL_ROOT}/"

mkdir -p "$STAGE_ROOT/usr/share/applications"
mkdir -p "$STAGE_ROOT/usr/share/pixmaps"
mkdir -p "$STAGE_ROOT/usr/share/icons/hicolor/256x256/apps"

cat >"$STAGE_ROOT/usr/share/applications/troodi-vpn.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Troodi VPN
Comment=Xray-based VPN client
Exec=/opt/troodi-vpn/xray_desktop_ui %u
Icon=troodi-vpn
Terminal=false
Categories=Network;VPN;
StartupNotify=true
Keywords=vpn;xray;proxy;
EOF

if [[ -f "$LOGO_SRC" ]]; then
  install -m0644 "$LOGO_SRC" "$STAGE_ROOT/usr/share/pixmaps/troodi-vpn.png"
  install -m0644 "$LOGO_SRC" "$STAGE_ROOT/usr/share/icons/hicolor/256x256/apps/com.troodi.vpn.png"
fi

mkdir -p "$STAGE_ROOT/DEBIAN"

# Installed-Size in KiB: payload only (/opt + /usr), not DEBIAN/
INSTALLED_KB="$(du -sk "$STAGE_ROOT${INSTALL_ROOT}" "$STAGE_ROOT/usr" 2>/dev/null | awk '{s+=$1} END {print s+0}')"

# Runtime dependencies: GTK/Flutter Linux stack + tools used by core-manager (ip, sudo).
# libharfbuzz package name differs across releases; alternatives cover common cases.
cat >"$STAGE_ROOT/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${PKG_VER}
Section: net
Priority: optional
Architecture: ${ARCH}
Maintainer: Troodi <https://github.com/troodi/ToodiVPN>
Installed-Size: ${INSTALLED_KB}
Depends: libc6 (>= 2.31),
 libgtk-3-0 (>= 3.10.0),
 libglib2.0-0 (>= 2.56),
 libgdk-pixbuf-2.0-0,
 libstdc++6,
 libgcc-s1 | libgcc1,
 zlib1g,
 libpango-1.0-0,
 libpangocairo-1.0-0,
 libharfbuzz0b | libharfbuzz0,
 libatk1.0-0,
 libcairo2,
 libcairo-gobject2,
 libepoxy0,
 libfontconfig1,
 libfreetype6,
 libpng16-16,
 libxi6,
 libx11-6,
 libxext6,
 libxfixes3,
 libxkbcommon0,
 libwayland-client0,
 libwayland-cursor0,
 libwayland-egl1,
 libatk-bridge2.0-0,
 libxcursor1,
 libxdamage1,
 libxcomposite1,
 libxrandr2,
 libxinerama1,
 libxrender1,
 libdbus-1-3,
 sudo,
 iproute2
Recommends: xdg-desktop-portal, xdg-desktop-portal-gtk | xdg-desktop-portal-kde
Homepage: https://github.com/troodi/ToodiVPN
Description: Troodi VPN desktop client
 Bundle under ${INSTALL_ROOT}: Flutter UI, bundled Xray, and core-manager.
 TUN mode uses sudo and iproute2 (ip). Russia profile may download routing rule data on first use.
EOF

cat >"$STAGE_ROOT/DEBIAN/postinst" <<'EOS'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
EOS

cat >"$STAGE_ROOT/DEBIAN/postrm" <<'EOS'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
EOS

chmod 0755 "$STAGE_ROOT/DEBIAN/postinst" "$STAGE_ROOT/DEBIAN/postrm"

find "$STAGE_ROOT${INSTALL_ROOT}" -type d -exec chmod 0755 {} +
find "$STAGE_ROOT${INSTALL_ROOT}" -type f -exec chmod 0644 {} +
chmod 0755 "$STAGE_ROOT${INSTALL_ROOT}/xray_desktop_ui" \
  "$STAGE_ROOT${INSTALL_ROOT}/xray" \
  "$STAGE_ROOT${INSTALL_ROOT}/core-manager" 2>/dev/null || true

mkdir -p "$OUT_DEB_DIR"
DEB_OUT="$OUT_DEB_DIR/${PKG_NAME}_${PKG_VER}_${ARCH}.deb"
rm -f "$DEB_OUT"

dpkg-deb --root-owner-group --build "$STAGE_ROOT" "$DEB_OUT"

echo
echo "deb OK:"
echo "  $DEB_OUT"
ls -lh "$DEB_OUT"
echo
echo "Install:  sudo apt install ./$(basename "$DEB_OUT")"
echo "Or:       sudo dpkg -i $DEB_OUT"
