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
mkdir -p "$APPDIR"/{usr/bin,usr/share,usr/share/applications,usr/share/icons/hicolor/256x256/apps/}

dnf install -y https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/v1.0.0/genesis-2.1.6-0.el9.x86_64.rpm

# ---- COPY FILES INTO APPDIR ---------------------------------------
echo "Copying binary..."
cp /usr/bin/"$BINARY_NAME" "$APPDIR/usr/bin/"

mkdir -p "$APPDIR/usr/lib64/"

# ---- APPDIR: AppRun ------------------------------------------------

echo "Generating AppRun..."

cat > "$APPDIR/AppRun" << 'EOF'
#!/usr/bin/env bash
set -e

APPDIR="$(dirname "$(readlink -f "$0")")"

if ! command -v mpirun >/dev/null 2>&1; then
    echo "Error: No MPI runtime found on this system (mpirun missing)."
    echo "Please install OpenMPI or load the appropriate MPI module."
    exit 1
fi

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
if [ ! -f linuxdeploy ]; then
    curl -L https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage \
         -o linuxdeploy
    chmod +x linuxdeploy
fi

echo "Building AppImage..."
export LD_LIBRARY_PATH="$APPDIR/usr/lib64:$APPDIR/usr/lib64/pmix:$APPDIR/usr/lib64/openmpi/lib:$APPDIR/usr/lib64/openmpi/lib/openmpi:$LD_LIBRARY_PATH"
./linuxdeploy --appdir "$APPDIR" --output appimage

echo "------------------------------------------------------------"
echo "DONE! Built atdyn-x86_64.AppImage"
echo "------------------------------------------------------------"
