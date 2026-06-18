#!/usr/bin/env bash
set -e

RPM_URL=""
APPDIR="genesis.AppDir"
APPNAME="genesis"
BINARY_NAME="atdyn"
ICON_NAME="genesis"

# ---- PREP ----------------------------------------------------------

rm -rf "$APPDIR"
mkdir -p "$APPDIR"/{usr/bin,usr/share,usr/share/applications,usr/share/icons/hicolor/256x256/apps/}

dnf install -y https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/continuous/genesis-2.1.6.2-0.el9.${ARCH}.rpm
dnf -y install ImageMagick fuse

# ---- COPY FILES INTO APPDIR ---------------------------------------
echo "Copying binary..."
cp /usr/bin/"$BINARY_NAME" "$APPDIR/usr/bin/"

mkdir -p "$APPDIR/usr/lib64/"

# ---- APPDIR: AppRun ------------------------------------------------

echo "Generating AppRun..."

cat > "$APPDIR/AppRun" << 'EOF'
#!/usr/bin/env bash
set -e

APPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MPI_LIBDIRS=""
if command -v mpif90 >/dev/null 2>&1; then
  MPI_LIBDIRS="$(mpif90 --showme:libdirs 2>/dev/null || true)"
elif command -v mpirun >/dev/null 2>&1; then
  MPI_LIBDIRS="$(mpirun --showme:libdirs 2>/dev/null || true)"
fi

for d in $MPI_LIBDIRS \
         /usr/lib64/openmpi/lib \
         /usr/lib/${ARCH}-linux-gnu/openmpi/lib
do
  [ -d "$d" ] && LD_LIBRARY_PATH="$d:${LD_LIBRARY_PATH:-}"
done

export LD_LIBRARY_PATH="$APPDIR/lib:$APPDIR/usr/lib:$APPDIR/usr/lib64:${LD_LIBRARY_PATH:-}"

exec "$APPDIR/usr/bin/atdyn" "$@"
EOF

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."

cat > "$APPDIR/usr/share/applications/$APPNAME.desktop" << EOF
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
convert -size 256x256 canvas:gray "$APPDIR/usr/share/icons/hicolor/256x256/apps/$ICON_NAME.png"

# ---- APPIMAGE BUILD -------------------------------------------------

echo "Downloading linuxdeploy..."
if [ ! -f linuxdeploy.AppImage ]; then
    curl -L https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-${ARCH}.AppImage \
         -o linuxdeploy.AppImage
    chmod +x linuxdeploy.AppImage
fi

echo "Extracting linuxdeploy..."
rm -rf squashfs-root
./linuxdeploy.AppImage --appimage-extract >/dev/null

echo "Building AppImage..."
./squashfs-root/AppRun --appdir "$APPDIR" --output appimage \
    --exclude-library=libmpi*.so* \
    --exclude-library=libopen-pal*.so* \
    --exclude-library=libopen-rte*.so*

echo "------------------------------------------------------------"
echo "DONE! Built atdyn-${ARCH}.AppImage"
echo "------------------------------------------------------------"
