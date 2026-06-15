#!/usr/bin/env bash
set -e
rm -rf squashfs-root *.appdir

# ---- PREP ----------------------------------------------------------

dnf install -y https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/v1.0.0/elnemo-1.0.0-1.el9.${ARCH}.rpm
dnf -y install ImageMagick patchelf

# ---- COPY FILES INTO APPDIR ---------------------------------------
SO_BUNDLE=so_bundle

if [ ! -f "$SO_BUNDLE" ]; then
    echo "[INFO] Downloading so_bundle..."
    curl -L -o so_bundle \
        https://github.com/bgallois/SoBundle/releases/download/continuous/so_bundle_${ARCH}
    chmod +x so_bundle
fi


./so_bundle -e /usr/bin/nma_diagrtb -a nma_diagrtb.appdir
./so_bundle -e /usr/bin/nma_elnemo_pdbmat -a nma_elnemo_pdbmat.appdir

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."

cat > "nma_diagrtb.appdir/nma_diagrtb.desktop" << EOF
[Desktop Entry]
Name=nma_diagrtb
Exec=AppRun
Icon=elnemo
Type=Application
Categories=Science;
Terminal=true
EOF

cat > "nma_elnemo_pdbmat.appdir/nma_elnemo_pdbmat.desktop" << EOF
[Desktop Entry]
Name=nma_elnemo_pdbmat
Exec=AppRun
Icon=elnemo
Type=Application
Categories=Science;
Terminal=true
EOF
#
# ---- ICON -----------------------------------------------------------

echo "Creating dummy icon..."
convert -size 256x256 canvas:gray "nma_diagrtb.appdir/elnemo.png"
convert -size 256x256 canvas:gray "nma_elnemo_pdbmat.appdir/elnemo.png"

# ---- APPIMAGE BUILD -------------------------------------------------

echo "Downloading appimagetool..."
echo "[INFO] Downloading appimagetool..."
curl -L -o appimagetool-${ARCH}.AppImage \
    https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage
chmod +x appimagetool-${ARCH}.AppImage

echo "Building AppImage..."
./appimagetool-${ARCH}.AppImage --appimage-extract
./squashfs-root/AppRun nma_diagrtb.appdir nma_diagrtb-${ARCH}.AppImage
./squashfs-root/AppRun nma_elnemo_pdbmat.appdir nma_elnemo_pdbmat-${ARCH}.AppImage

echo "------------------------------------------------------------"
echo "DONE! Built Elnemo"
echo "------------------------------------------------------------"
