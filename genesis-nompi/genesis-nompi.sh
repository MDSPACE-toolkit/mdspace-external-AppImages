#!/usr/bin/env bash
set -euo pipefail

RPM_URL="https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/continuous/genesis-nompi-2.1.6.3-0.el9.${ARCH}.rpm"
APPDIR="genesis-nompi.AppDir"
APPNAME="genesis-nompi"
BINARY_NAME="atdyn"
ICON_NAME="genesis-nompi"

# ---- PREP ----------------------------------------------------------

rm -rf "$APPDIR"
mkdir -p "$APPDIR"/{usr/bin,usr/share/applications,usr/share/icons/hicolor/256x256/apps}

dnf -y install "$RPM_URL"
dnf -y install ImageMagick fuse

# ---- COPY FILES INTO APPDIR ---------------------------------------

echo "Copying GENESIS binaries..."
test -x "/usr/bin/$BINARY_NAME"
cp /usr/bin/"$BINARY_NAME" "$APPDIR/usr/bin/"

# ---- APPDIR: AppRun ------------------------------------------------

echo "Generating AppRun..."
cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/usr/lib64:${LD_LIBRARY_PATH:-}"

exec "$APPDIR/usr/bin/atdyn" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."
cat > "$APPDIR/usr/share/applications/$APPNAME.desktop" <<EOF
[Desktop Entry]
Name=atdyn-nompi
Exec=AppRun
Icon=$ICON_NAME
Type=Application
Categories=Science;
Terminal=true
Comment=GENESIS atdyn molecular dynamics simulation without MPI support.
EOF

# ---- ICON ----------------------------------------------------------

echo "Creating dummy icon..."
convert -size 256x256 canvas:gray "$APPDIR/usr/share/icons/hicolor/256x256/apps/$ICON_NAME.png"

# ---- APPIMAGE BUILD ------------------------------------------------

echo "Downloading linuxdeploy..."
if [ ! -f linuxdeploy.AppImage ]; then
  curl -L "https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-${ARCH}.AppImage" \
    -o linuxdeploy.AppImage
  chmod +x linuxdeploy.AppImage
fi

echo "Extracting linuxdeploy..."
rm -rf squashfs-root
./linuxdeploy.AppImage --appimage-extract >/dev/null

echo "Building AppImage..."
rm -f "atdyn-${ARCH}.AppImage" "atdyn-nompi-${ARCH}.AppImage"
./squashfs-root/AppRun --appdir "$APPDIR" --output appimage
test -f "atdyn-nompi-${ARCH}.AppImage"

echo "------------------------------------------------------------"
echo "DONE! Built atdyn-nompi-${ARCH}.AppImage"
echo "------------------------------------------------------------"
