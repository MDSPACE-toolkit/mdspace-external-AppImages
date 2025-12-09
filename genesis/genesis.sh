#!/usr/bin/env bash
set -e

RPM_URL=""
APPDIR="genesis.AppDir"
APPNAME="genesis"
BINARY_NAME="atdyn"
ICON_NAME="genesis"

# ---- PREP ----------------------------------------------------------

export ARCH=x86_64
rm -rf "$APPDIR"

dnf install -y https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/v1.0.0/genesis-2.1.6-0.el9.x86_64.rpm

# ---- COPY FILES INTO APPDIR ---------------------------------------
SO_BUNDLE=so_bundle

if [ ! -f "$SO_BUNDLE" ]; then
    echo "[INFO] Downloading so_bundle..."
    curl -L -o so_bundle \
        https://github.com/bgallois/SoBundle/releases/download/continuous/so_bundle
    chmod +x so_bundle
fi


./so_bundle -e /usr/bin/atdyn -a "$APPDIR"


# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."

cat > "$APPDIR/$APPNAME.desktop" << EOF
[Desktop Entry]
Name=atdyn
Exec=AppRun
Icon=$ICON_NAME
Type=Application
Categories=Science;
Terminal=true
Comment=atdyn MD simulation.
EOF

# ---- ICON -----------------------------------------------------------

echo "Creating dummy icon..."
convert -size 256x256 canvas:gray "$APPDIR/$ICON_NAME.png"

# ---- APPIMAGE BUILD -------------------------------------------------

echo "Downloading appimagetool..."
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    echo "[INFO] Downloading appimagetool..."
    curl -L -o appimagetool-x86_64.AppImage \
        https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

echo "Building AppImage..."
./appimagetool-x86_64.AppImage --appimage-extract
./squashfs-root/AppRun $APPDIR atdyn-x86_64.AppImage

echo "------------------------------------------------------------"
echo "DONE! Built atdyn-x86_64.AppImage"
echo "------------------------------------------------------------"
