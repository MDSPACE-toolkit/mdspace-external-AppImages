#!/usr/bin/env bash
set -e

# ---- PREP ----------------------------------------------------------

export ARCH=x86_64

dnf install -y https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/v1.0.0/xmipp-3.25.06.0-2.el9.x86_64.rpm

# ---- COPY FILES INTO APPDIR ---------------------------------------
SO_BUNDLE=so_bundle

if [ ! -f "$SO_BUNDLE" ]; then
    echo "[INFO] Downloading so_bundle..."
    curl -L -o so_bundle \
        https://github.com/bgallois/SoBundle/releases/download/continuous/so_bundle
    chmod +x so_bundle
fi


./so_bundle -e /usr/bin/xmipp_reconstruct_fourier -a xmipp_reconstruct_fourier.appdir
./so_bundle -e /usr/bin/xmipp_image_convert -a xmipp_image_convert.appdir

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."

cat > "xmipp_reconstruct_fourier.appdir/xmipp_reconstruct_fourier.desktop" << EOF
[Desktop Entry]
Name=xmipp_reconstruct_fourier
Exec=AppRun
Icon=xmipp
Type=Application
Categories=Science;
Terminal=true
EOF

cat > "xmipp_image_convert.appdir/xmipp_image_convert.desktop" << EOF
[Desktop Entry]
Name=xmipp_image_convert
Exec=AppRun
Icon=xmipp
Type=Application
Categories=Science;
Terminal=true
EOF
#
# ---- ICON -----------------------------------------------------------

echo "Creating dummy icon..."
convert -size 256x256 canvas:gray "xmipp_reconstruct_fourier.appdir/xmipp.png"
convert -size 256x256 canvas:gray "xmipp_image_convert.appdir/xmipp.png"

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
./squashfs-root/AppRun xmipp_reconstruct_fourier.appdir xmipp_reconstruct_fourier-x86_64.AppImage
./squashfs-root/AppRun xmipp_image_convert.appdir xmipp_image_convert-x86_64.AppImage

echo "------------------------------------------------------------"
echo "DONE! Built XMIPP"
echo "------------------------------------------------------------"
