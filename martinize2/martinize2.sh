#!/usr/bin/env bash
set -euo pipefail

APPDIR="martinize2.AppDir"
APPNAME="martinize2"
ICON_NAME="martinize2"

export ARCH=x86_64

rm -rf "$APPDIR"
mkdir -p "$APPDIR"/usr/{bin,share,share/applications,share/icons/hicolor/256x256/apps}

# ---- BUILD RUNTIME -------------------------------------------------

python3 -m venv --copies "$APPDIR/usr/venv"
"$APPDIR/usr/venv/bin/pip" install --upgrade pip
"$APPDIR/usr/venv/bin/pip" install vermouth

ln -sf ../venv/bin/martinize2 "$APPDIR/usr/bin/martinize2"

# ---- APPDIR: AppRun ------------------------------------------------

cat > "$APPDIR/AppRun" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

APPDIR="$(dirname "$(readlink -f "$0")")"

export PATH="$APPDIR/usr/venv/bin:$APPDIR/usr/bin:$PATH"
export PYTHONNOUSERSITE=1

"$APPDIR/usr/venv/bin/python" "$APPDIR/usr/venv/bin/martinize2"
EOF
chmod +x "$APPDIR/AppRun"

# ---- DESKTOP FILE --------------------------------------------------

cat > "$APPDIR/usr/share/applications/$APPNAME.desktop" << EOF
[Desktop Entry]
Name=martinize2
Exec=AppRun
Icon=$ICON_NAME
Type=Application
Categories=Science;
Terminal=true
Comment=Martini topology generation tool
EOF

# ---- ICON ----------------------------------------------------------

if command -v convert >/dev/null 2>&1; then
  convert -size 256x256 canvas:lightblue \
    "$APPDIR/usr/share/icons/hicolor/256x256/apps/$ICON_NAME.png"
else
  printf '' > "$APPDIR/usr/share/icons/hicolor/256x256/apps/$ICON_NAME.png"
fi

# ---- linuxdeploy ---------------------------------------------------

if [ ! -f linuxdeploy ]; then
  curl -L \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage \
    -o linuxdeploy
  chmod +x linuxdeploy
fi

./linuxdeploy --appdir "$APPDIR" --output appimage

echo "DONE: built martinize2-x86_64.AppImage"
