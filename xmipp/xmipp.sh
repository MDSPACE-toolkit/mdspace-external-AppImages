#!/usr/bin/env bash
set -e

# ---- PREP ----------------------------------------------------------

export ARCH=x86_64

dnf install -y https://github.com/MDSPACE-toolkit/mdspace-external-rpms/releases/download/v1.0.0/xmipp-3.25.06.0-3.el9.x86_64.rpm

# ---- COPY FILES INTO APPDIR ---------------------------------------
SO_BUNDLE=so_bundle

if [ ! -f "$SO_BUNDLE" ]; then
    echo "[INFO] Downloading so_bundle..."
    curl -L -o so_bundle \
        https://github.com/bgallois/SoBundle/releases/download/continuous/so_bundle
    chmod +x so_bundle
fi

# ---- APPIMAGE BUILD -------------------------------------------------

echo "Downloading appimagetool..."
APPIMAGETOOL=appimagetool-x86_64.AppImage
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
echo "[INFO] Downloading $APPIMAGETOOL..."
curl -L -o "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
chmod +x "$APPIMAGETOOL"
./"$APPIMAGETOOL" --appimage-extract >/dev/null


apps=(
  xmipp_reconstruct_fourier
  xmipp_image_convert
  xmipp_volume_from_pdb
  xmipp_phantom_project
  xmipp_image_resize
  xmipp_phantom_simulate_microscope
  xmipp_ctf_phase_flip
)

for app in "${apps[@]}"; do
  exe="/usr/bin/${app}"
  appdir="${app}.appdir"
  desktop="${appdir}/${app}.desktop"
  icon="${appdir}/xmipp.png"
  out="${app}-x86_64.AppImage"

  echo "------------------------------------------------------------"
  echo "Bundling: $app"
  echo "------------------------------------------------------------"

  [[ -x "$exe" ]] || { echo "[ERROR] Missing executable: $exe" >&2; exit 1; }

  # Bundle shared libs etc.
  ./so_bundle -e "$exe" -a "$appdir"

  # ---- DESKTOP FILE --------------------------------------------------
  echo "Writing desktop file..."
  cat > "$desktop" <<EOF
[Desktop Entry]
Name=$app
Exec=AppRun
Icon=xmipp
Type=Application
Categories=Science;
Terminal=true
EOF

  # ---- ICON ----------------------------------------------------------
  echo "Creating dummy icon..."
  convert -size 256x256 canvas:gray "$icon"

  # ---- APPIMAGE BUILD ------------------------------------------------
  echo "Building AppImage..."
  ./squashfs-root/AppRun "$appdir" "$out"
done

echo "------------------------------------------------------------"
echo "DONE! Built XMIPP"
echo "------------------------------------------------------------"
