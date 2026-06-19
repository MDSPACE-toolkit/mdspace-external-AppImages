#!/usr/bin/env bash
set -euo pipefail

: "${ARCH:?ARCH must be set, e.g. x86_64 or aarch64}"

rm -rf squashfs-root *.appdir *.AppImage

# ---- PREP ----------------------------------------------------------

dnf install -y \
  "https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/continuous/rtb2-1.0.0-1.el9.${ARCH}.rpm"

dnf -y install ImageMagick patchelf gcc

# ---- COPY FILES INTO APPDIR ---------------------------------------

SO_BUNDLE=so_bundle

if [ ! -f "$SO_BUNDLE" ]; then
    echo "[INFO] Downloading so_bundle..."
    curl -L -o so_bundle \
        "https://github.com/bgallois/SoBundle/releases/download/continuous/so_bundle_${ARCH}"
    chmod +x so_bundle
fi

# RTB2 AppDir.
./so_bundle -e /usr/bin/rtb2 -a rtb2.appdir

# makebloc.pl AppDir.
# This AppDir contains only a Perl script, so appimagetool cannot infer
# the target architecture by itself. We add a tiny native ELF executable
# only as an architecture marker.
mkdir -p makebloc.pl.appdir/usr/bin

cp /usr/bin/makebloc.pl makebloc.pl.appdir/usr/bin/

cat > makebloc.pl.appdir/usr/bin/arch-marker.c << 'EOF'
int main(void) { return 0; }
EOF

gcc makebloc.pl.appdir/usr/bin/arch-marker.c \
    -o makebloc.pl.appdir/usr/bin/arch-marker

rm -f makebloc.pl.appdir/usr/bin/arch-marker.c

cat > makebloc.pl.appdir/AppRun << 'EOF'
#!/usr/bin/env bash
APPDIR="$(dirname "$(readlink -f "$0")")"

exec "$APPDIR/usr/bin/makebloc.pl" "$@"
EOF

chmod +x makebloc.pl.appdir/AppRun
chmod +x makebloc.pl.appdir/usr/bin/makebloc.pl
chmod +x makebloc.pl.appdir/usr/bin/arch-marker

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop files..."

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

# ---- ICON -----------------------------------------------------------

echo "Creating dummy icons..."

convert -size 256x256 canvas:gray "rtb2.appdir/rtb2.png"
convert -size 256x256 canvas:gray "makebloc.pl.appdir/makebloc.pl.png"

# ---- APPIMAGE BUILD -------------------------------------------------

echo "[INFO] Downloading appimagetool..."

curl -L -o "appimagetool-${ARCH}.AppImage" \
    "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage"

chmod +x "appimagetool-${ARCH}.AppImage"

echo "Building AppImages..."

"./appimagetool-${ARCH}.AppImage" --appimage-extract

export ARCH

./squashfs-root/AppRun rtb2.appdir "rtb2-${ARCH}.AppImage"
./squashfs-root/AppRun makebloc.pl.appdir "makebloc.pl-${ARCH}.AppImage"

echo "------------------------------------------------------------"
echo "DONE! Built RTB2 AppImages:"
ls -lh "rtb2-${ARCH}.AppImage" "makebloc.pl-${ARCH}.AppImage"
echo "------------------------------------------------------------"
