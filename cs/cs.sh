#!/usr/bin/env bash
set -e

APPDIR="cryosparc-cs-reader.AppDir"
APPNAME="cryosparc-cs-reader"
ICON_NAME="cryosparc-cs-reader"

# ---- PREP ----------------------------------------------------------

rm -rf "$APPDIR"
mkdir -p "$APPDIR"/{usr/bin,usr/libexec,usr/share/applications,usr/share/icons/hicolor/256x256/apps}

dnf install -y \
  "https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/continuous/cryosparc-cs-reader-1.0.0-1.el9.${ARCH}.rpm"

dnf install -y ImageMagick fuse

# ---- COPY INSTALLED RPM FILES --------------------------------------

echo "Copying cryosparc-cs-reader..."

cp -a /usr/libexec/cryosparc-cs-reader "$APPDIR/usr/libexec/"

ln -s \
  ../libexec/cryosparc-cs-reader/cryosparc-cs-reader \
  "$APPDIR/usr/bin/cryosparc-cs-reader"

# ---- APPDIR: AppRun ------------------------------------------------

echo "Generating AppRun..."

cat > "$APPDIR/AppRun" << 'EOF'
#!/usr/bin/env bash
set -e

APPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export LD_LIBRARY_PATH="$APPDIR/usr/libexec/cryosparc-cs-reader:${LD_LIBRARY_PATH:-}"

exec "$APPDIR/usr/bin/cryosparc-cs-reader" "$@"
EOF

chmod +x "$APPDIR/AppRun"

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."

cat > "$APPDIR/usr/share/applications/$APPNAME.desktop" << EOF
[Desktop Entry]
Name=cryosparc-cs-reader
Exec=AppRun
Icon=$ICON_NAME
Type=Application
Categories=Science;
Terminal=true
Comment=Convert CryoSPARC CS files to MDSPACE-compatible TSV files.
EOF

# ---- ICON ----------------------------------------------------------

echo "Creating dummy icon..."

convert \
  -size 256x256 \
  canvas:gray \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/$ICON_NAME.png"

# ---- APPIMAGE BUILD ------------------------------------------------

echo "Downloading linuxdeploy..."

if [ ! -f linuxdeploy.AppImage ]; then
  curl -L \
    "https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-${ARCH}.AppImage" \
    -o linuxdeploy.AppImage

  chmod +x linuxdeploy.AppImage
fi

echo "Extracting linuxdeploy..."

rm -rf squashfs-root
./linuxdeploy.AppImage --appimage-extract >/dev/null

echo "Building AppImage..."

./squashfs-root/AppRun \
  --appdir "$APPDIR" \
  --output appimage

echo "------------------------------------------------------------"
echo "DONE! Built cryosparc-cs-reader-${ARCH}.AppImage"
echo "------------------------------------------------------------"
