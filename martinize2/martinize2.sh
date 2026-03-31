#!/usr/bin/env bash
set -euo pipefail

APPDIR="martinize2.AppDir"
APPNAME="martinize2"
ICON_NAME="martinize2"

export ARCH=x86_64

rm -rf "$APPDIR" build-nuitka
mkdir -p "$APPDIR"/usr/{bin,lib,share,share/applications,share/icons/hicolor/256x256/apps}

python3 -m pip install --upgrade pip
python3 -m pip install --upgrade nuitka ordered-set zstandard vermouth

MARTINIZE2_SCRIPT="$(command -v martinize2)"

python3 -m nuitka \
  --standalone \
  --deployment \
  --static-libpython=no \
  --output-dir=build-nuitka \
  --output-filename=martinize2 \
  --include-package=vermouth \
  --include-package-data=vermouth \
  "$MARTINIZE2_SCRIPT"

mkdir -p "$APPDIR/usr/lib/martinize2"
cp -a build-nuitka/martinize2.dist/. "$APPDIR/usr/lib/martinize2/"

# Optional convenience symlink
ln -sf ../lib/martinize2/martinize2 "$APPDIR/usr/bin/martinize2"

# ---- APPDIR: AppRun ------------------------------------------------

cat > "$APPDIR/AppRun" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

APPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNDIR="$APPDIR/usr/lib/martinize2"

export LD_LIBRARY_PATH="$RUNDIR:$RUNDIR/scipy.libs:$RUNDIR/numpy.libs:${LD_LIBRARY_PATH:-}"
export PATH="$RUNDIR:${PATH:-}"
export PYTHONNOUSERSITE=1
unset PYTHONPATH
unset PYTHONHOME

exec "$RUNDIR/martinize2" "$@"
EOF
chmod +x "$APPDIR/AppRun"

cat > "$APPDIR/$APPNAME.desktop" << EOF
[Desktop Entry]
Name=martinize2
Exec=AppRun
Icon=$ICON_NAME
Type=Application
Categories=Science;
Terminal=true
Comment=Martini topology generation tool
EOF

if command -v convert >/dev/null 2>&1; then
  convert -size 256x256 canvas:lightblue \
    "$APPDIR/$ICON_NAME.png"
else
  printf '' > "$APPDIR/$ICON_NAME.png"
fi

if [ ! -f appimagetool ]; then
  curl -L \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
    -o appimagetool
  chmod +x appimagetool
fi

ARCH=x86_64 ./appimagetool "$APPDIR"

echo "DONE: built ${APPNAME}-x86_64.AppImage"
