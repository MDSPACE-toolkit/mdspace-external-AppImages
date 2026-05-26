#!/usr/bin/env bash
set -e
rm -rf squashfs-root *.appdir

# ---- PREP ----------------------------------------------------------

export ARCH=x86_64

dnf install -y https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/v1.0.0/rtb2-1.0.0-1.el9.x86_64.rpm
dnf -y install ImageMagick patchelf

# ---- COPY FILES INTO APPDIR ---------------------------------------
SO_BUNDLE=so_bundle

if [ ! -f "$SO_BUNDLE" ]; then
    echo "[INFO] Downloading so_bundle..."
    curl -L -o so_bundle \
        https://github.com/bgallois/SoBundle/releases/download/continuous/so_bundle
    chmod +x so_bundle
fi


./so_bundle -e /usr/bin/rtb2 -a rtb2.appdir

mkdir -p makebloc.pl.appdir

cp /usr/bin/makebloc.pl makebloc.pl.appdir/

cat > makebloc.pl.appdir/AppRun << 'EOF'
#!/usr/bin/env bash
APPDIR="$(dirname "$(readlink -f "$0")")"

exec "$APPDIR/makebloc.pl" "$@"
EOF

chmod +x makebloc.pl.appdir/AppRun
chmod +x makebloc.pl.appdir/makebloc.pl

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."

cat > "rtb2.appdir/rtb2.desktop" << EOF
[Desktop Entry]
Name=rtb2
Exec=AppRun
Icon=rtb2
Type=Application
Categories=Science;
Terminal=true
EOF

cat > "makebloc.pl.appdir/makebloc.pl.desktop" << EOF
[Desktop Entry]
Name=makebloc.pl
Exec=AppRun
Icon=makebloc.pl
Type=Application
Categories=Science;
Terminal=true
EOF
#
# ---- ICON -----------------------------------------------------------

echo "Creating dummy icon..."
convert -size 256x256 canvas:gray "rtb2.appdir/rtb2.png"
convert -size 256x256 canvas:gray "makebloc.pl.appdir/makebloc.pl.png"

# ---- APPIMAGE BUILD -------------------------------------------------

echo "Downloading appimagetool..."
echo "[INFO] Downloading appimagetool..."
curl -L -o appimagetool-x86_64.AppImage \
    https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage

echo "Building AppImage..."
./appimagetool-x86_64.AppImage --appimage-extract
./squashfs-root/AppRun rtb2.appdir rtb2-x86_64.AppImage
./squashfs-root/AppRun makebloc.pl.appdir makebloc.pl-x86_64.AppImage

echo "------------------------------------------------------------"
echo "DONE! Built RTB2"
echo "------------------------------------------------------------"
