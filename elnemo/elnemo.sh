#!/usr/bin/env bash
set -e

# ---- PREP ----------------------------------------------------------

export ARCH=x86_64

dnf install -y https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/v1.0.0/elnemo-1.0.0-1.el9.x86_64.rpm

# ---- COPY FILES INTO APPDIR ---------------------------------------
SO_BUNDLE=so_bundle

if [ ! -f "$SO_BUNDLE" ]; then
    echo "[INFO] Downloading so_bundle..."
    curl -L -o so_bundle \
        https://github.com/bgallois/SoBundle/releases/download/continuous/so_bundle
    chmod +x so_bundle
fi


./so_bundle -e /usr/bin/nma_diagrtb -a nma_diagrtb.appdir
./so_bundle -e /usr/bin/nma_elnemo_pdbmat -a nma_elnemo_pdbmat.appdir

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."

cat > "nma_diagrtb.appdir/nma_diagrtn.desktop" << EOF
[Desktop Entry]
Name=nma_diagrtn
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
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    echo "[INFO] Downloading appimagetool..."
    curl -L -o appimagetool-x86_64.AppImage \
        https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

echo "Building AppImage..."
./appimagetool-x86_64.AppImage --appimage-extract
./squashfs-root/AppRun nma_diagrtb.appdir nma_diagrtb-x86_64.AppImage
./squashfs-root/AppRun nma_elnemo_pdbmat.appdir nma_elnemo_pdbmat-x86_64.AppImage

echo "------------------------------------------------------------"
echo "DONE! Built Elnemo"
echo "------------------------------------------------------------"
