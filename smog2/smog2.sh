#!/usr/bin/env bash
set -e

APPDIR="smog2.AppDir"
APPNAME="smog2"
BINARY_NAME="smog2"
ICON_NAME="smog2"

# ---- PREP ----------------------------------------------------------

export ARCH=x86_64
rm -rf "$APPDIR"
mkdir -p "$APPDIR"/{usr/bin,usr/share,usr/share/applications,usr/share/icons/hicolor/256x256/apps/}

dnf install -y https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/v1.0.0/smog2-2.5-4.el9.x86_64.rpm

# ---- COPY FILES INTO APPDIR ---------------------------------------

echo "Copying binary..."
cp /usr/bin/"$BINARY_NAME" "$APPDIR/usr/bin/"

echo "Copying SMOG2 share directory..."
cp -r /usr/share/smog2 "$APPDIR/usr/share/"

echo "Copying perl vendor directory..."
mkdir -p "$APPDIR/usr/share/perl5"
cp -r /usr/share/perl5/ "$APPDIR/usr/share/"

cp /usr/bin/perl "$APPDIR/usr/bin/"

mkdir -p "$APPDIR/usr/lib64/perl5"
cp -r /usr/lib64/perl5/ "$APPDIR/usr/lib64/"

mkdir -p "$APPDIR/usr/lib/jvm"
cp -r /usr/lib/jvm/java-21-openjdk/ "$APPDIR/usr/lib/jvm/"


# ---- APPDIR: AppRun ------------------------------------------------

echo "Generating AppRun..."

cat > "$APPDIR/AppRun" << 'EOF'
#!/usr/bin/env bash

APPDIR="$(dirname "$(readlink -f "$0")")"

SMOG_PATH="$APPDIR/usr/share/smog2"
PERL_BIN="$APPDIR/usr/bin/perl"

export PERL5LIB="$SMOG_PATH:$APPDIR/usr/share/perl5/vendor_perl:$APPDIR/usr/lib64/perl5/vendor_perl:$APPDIR/usr/share/perl5:$APPDIR/usr/lib64/perl5:$PERL5LIB"
export PERLLIB="$SMOG_PATH:$PERLLIB"
export PERL5LIB="$SMOG_PATH:$PERL5LIB"

export JAVA_HOME="$APPDIR/usr/lib/jvm/java-21-openjdk/"
export PATH="$JAVA_HOME/bin:$PATH"

export perl4smog=/usr/bin/perl
SMOG_PATH="$SMOG_PATH" exec /usr/bin/perl "$SMOG_PATH/smogv2" "$@"
EOF

chmod +x "$APPDIR/AppRun"

# ---- DESKTOP FILE --------------------------------------------------

echo "Writing desktop file..."

cat > "$APPDIR/usr/share/applications/$APPNAME.desktop" << EOF
[Desktop Entry]
Name=smog2
Exec=AppRun
Icon=$ICON_NAME
Type=Application
Categories=Science;
Terminal=true
Comment=smog2 coarse-grained modeling tool packaged as an AppImage.
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
export LD_LIBRARY_PATH=/usr/lib/jvm/java-21-openjdk/lib/server:$LD_LIBRARY_PATH
./linuxdeploy --appdir "$APPDIR" --output appimage
chmod +x smog2-x86_64.AppImage

echo "------------------------------------------------------------"
echo "DONE! Built smog2-x86_64.AppImage"
echo "------------------------------------------------------------"
