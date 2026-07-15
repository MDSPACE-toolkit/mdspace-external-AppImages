#!/usr/bin/env bash
set -e

APPDIR="pdb-fixer.AppDir"
APPNAME="pdb-fixer"
ICON_NAME="pdb-fixer"

# ---- PREP ----------------------------------------------------------

rm -rf "$APPDIR"

mkdir -p \
  "$APPDIR/usr/bin" \
  "$APPDIR/usr/libexec" \
  "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps"

dnf install -y \
  "https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/continuous/pdb-fixer-1.0.0-1.el9.${ARCH}.rpm"

dnf install -y \
  ImageMagick \
  fuse

# ---- COPY INSTALLED RPM FILES --------------------------------------

echo "Copying pdb-fixer..."

cp -a \
  /usr/libexec/pdb-fixer \
  "$APPDIR/usr/libexec/"

ln -s \
  ../libexec/pdb-fixer/pdb-fixer \
  "$APPDIR/usr/bin/pdb-fixer"

# ---- VERIFY OPENMM CPU PLUGIN --------------------------------------

echo "Checking OpenMM CPU plugin..."

test -f \
  "$APPDIR/usr/libexec/pdb-fixer/openmm_plugins/libOpenMMCPU.so"

echo "OpenMM plugins included:"

find \
  "$APPDIR/usr/libexec/pdb-fixer/openmm_plugins" \
  -maxdepth 1 \
  -type f \
  -name 'libOpenMM*.so' \
  -print

echo "Checking OpenMM CPU plugin dependencies..."

PDB_FIXER_DIR="$APPDIR/usr/libexec/pdb-fixer"
OPENMM_PLUGIN_DIR="$PDB_FIXER_DIR/openmm_plugins"

if LD_LIBRARY_PATH="$PDB_FIXER_DIR:${LD_LIBRARY_PATH:-}" \
  ldd "$OPENMM_PLUGIN_DIR/libOpenMMCPU.so" \
  | grep -q "not found"; then
  echo "ERROR: OpenMM CPU plugin has missing dependencies"

  LD_LIBRARY_PATH="$PDB_FIXER_DIR:${LD_LIBRARY_PATH:-}" \
    ldd "$OPENMM_PLUGIN_DIR/libOpenMMCPU.so"

  exit 1
fi

# ---- APPDIR: AppRun ------------------------------------------------

echo "Generating AppRun..."

cat > "$APPDIR/AppRun" << 'EOF'
#!/usr/bin/env bash
set -e

APPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PDB_FIXER_DIR="$APPDIR/usr/libexec/pdb-fixer"
OPENMM_PLUGIN_DIR="$PDB_FIXER_DIR/openmm_plugins"

export LD_LIBRARY_PATH="$PDB_FIXER_DIR:${LD_LIBRARY_PATH:-}"
export OPENMM_PLUGIN_DIR

exec "$APPDIR/usr/bin/pdb-fixer" "$@"
EOF

chmod +x "$APPDIR/AppRun"

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."

cat > "$APPDIR/usr/share/applications/$APPNAME.desktop" << EOF
[Desktop Entry]
Name=PDB Fixer
Exec=AppRun
Icon=$ICON_NAME
Type=Application
Categories=Science;
Terminal=true
Comment=Repair PDB structures using PDBFixer and OpenMM.
EOF

# ---- ICON ----------------------------------------------------------

echo "Creating dummy icon..."

convert \
  -size 256x256 \
  canvas:gray \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/$ICON_NAME.png"

# ---- APPDIR VALIDATION ---------------------------------------------

echo "Checking AppDir executable..."

test -x \
  "$APPDIR/usr/libexec/pdb-fixer/pdb-fixer"

test -L \
  "$APPDIR/usr/bin/pdb-fixer"

echo "Testing pdb-fixer from the AppDir..."

"$APPDIR/AppRun" --help

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

./linuxdeploy.AppImage \
  --appimage-extract \
  >/dev/null

echo "Building AppImage..."

./squashfs-root/AppRun \
  --appdir "$APPDIR" \
  --output appimage

# ---- FINAL VALIDATION ----------------------------------------------

APPIMAGE_FILE="$(
  find . \
    -maxdepth 1 \
    -type f \
    -iname '*pdb*fixer*.AppImage' \
    -print \
    | head -n 1
)"

if [ -z "$APPIMAGE_FILE" ]; then
  echo "ERROR: pdb-fixer AppImage was not generated"
  exit 1
fi

FINAL_APPIMAGE="pdb-fixer-${ARCH}.AppImage"

mv \
  "$APPIMAGE_FILE" \
  "$FINAL_APPIMAGE"

chmod +x "$FINAL_APPIMAGE"

echo "Testing generated AppImage..."

APPIMAGE_EXTRACT_AND_RUN=1 \
  "./$FINAL_APPIMAGE" \
  --help

echo "------------------------------------------------------------"
echo "DONE! Built $FINAL_APPIMAGE"
echo "------------------------------------------------------------"
