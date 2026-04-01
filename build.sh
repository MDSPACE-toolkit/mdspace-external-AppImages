#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <path/to/build-script.sh> [<path/to/build-script2.sh> ...]" >&2
  exit 1
fi

SCRIPT_PATHS=("$@")
PROJECT_ROOT="$(realpath "$PWD")"

# Validate all scripts before starting any work
SCRIPT_PATHS_IN_CONTAINER=()
SCRIPT_DIRS_IN_CONTAINER=()
for SCRIPT_PATH in "${SCRIPT_PATHS[@]}"; do
  if [ ! -f "$SCRIPT_PATH" ]; then
    echo "ERROR: build script not found: $SCRIPT_PATH" >&2
    exit 1
  fi
  SCRIPT_PATH_ABS="$(realpath "$SCRIPT_PATH")"
  case "$SCRIPT_PATH_ABS" in
    "$PROJECT_ROOT"/*) ;;
    *)
      echo "ERROR: build script must be inside current working tree ($PROJECT_ROOT): $SCRIPT_PATH" >&2
      exit 1
      ;;
  esac
  SCRIPT_PATHS_IN_CONTAINER+=("/work/${SCRIPT_PATH_ABS#$PROJECT_ROOT/}")
  SCRIPT_DIRS_IN_CONTAINER+=("$(dirname "/work/${SCRIPT_PATH_ABS#$PROJECT_ROOT/}")")
done

# Serialize arrays for the container shell
SCRIPTS_JSON="$(printf '%s\n' "${SCRIPT_PATHS_IN_CONTAINER[@]}")"
DIRS_JSON="$(printf '%s\n' "${SCRIPT_DIRS_IN_CONTAINER[@]}")"

docker run --rm \
  -v "$PROJECT_ROOT:/work" \
  -w /work \
  almalinux:9.5 \
  bash -lc '
    set -euo pipefail

    mapfile -t SCRIPT_PATHS_IN_CONTAINER <<'"'"'ENDOFPATHS'"'"'
'"$SCRIPTS_JSON"'
ENDOFPATHS
    mapfile -t SCRIPT_DIRS_IN_CONTAINER <<'"'"'ENDOFDIRS'"'"'
'"$DIRS_JSON"'
ENDOFDIRS

    # ── Repo setup ────────────────────────────────────────────────────────────
    rm -f /etc/yum.repos.d/*.repo
    cat > /etc/yum.repos.d/alma95-vault.repo <<'"'"'EOF'"'"'
[baseos]
name=AlmaLinux 9.5 - BaseOS
baseurl=https://vault.almalinux.org/9.5/BaseOS/$basearch/os/
enabled=1
gpgcheck=0
[appstream]
name=AlmaLinux 9.5 - AppStream
baseurl=https://vault.almalinux.org/9.5/AppStream/$basearch/os/
enabled=1
gpgcheck=0
[crb]
name=AlmaLinux 9.5 - CRB
baseurl=https://vault.almalinux.org/9.5/CRB/$basearch/os/
enabled=1
gpgcheck=0
EOF
    dnf clean all
    rm -rf /var/cache/dnf
    dnf makecache --releasever=9.5
    dnf -y --releasever=9.5 install \
      https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
    dnf -y --releasever=9.5 install \
      wget curl-minimal file patch patchelf ImageMagick findutils diffutils

    # ── GLIBC helpers ─────────────────────────────────────────────────────────
    check_system_glibc() {
      echo "=== System toolchain sanity ==="
      rpm -q libgcc libstdc++ || true
      objdump -p /usr/lib64/libgcc_s.so.1 | grep GLIBC | sort -V || true
      MAX_GLIBC="$(
        objdump -p /usr/lib64/libgcc_s.so.1 \
          | grep -o "GLIBC_[0-9]\+\.[0-9]\+" \
          | sort -V | tail -1
      )"
      echo "Detected max GLIBC symbol: ${MAX_GLIBC:-none}"
      if [ -n "${MAX_GLIBC:-}" ] && \
         [ "$(printf "%s\n" "$MAX_GLIBC" "GLIBC_2.34" | sort -V | tail -1)" != "GLIBC_2.34" ]; then
        echo "ERROR: libgcc_s.so.1 requires newer than GLIBC_2.34: $MAX_GLIBC" >&2
        exit 1
      fi
    }

    check_file_glibc() {
      local f="$1"
      local max_glibc
      max_glibc="$(
        objdump -p "$f" 2>/dev/null \
          | grep -o "GLIBC_[0-9]\+\.[0-9]\+" \
          | sort -V | tail -1 || true
      )"
      echo "Detected max GLIBC in $f: ${max_glibc:-none}"
      if [ -n "${max_glibc:-}" ] && \
         [ "$(printf "%s\n" "$max_glibc" "GLIBC_2.34" | sort -V | tail -1)" != "GLIBC_2.34" ]; then
        echo "ERROR: Found newer than GLIBC_2.34 in $f" >&2
        exit 1
      fi
    }

    check_appimage() {
      local appimage="$1"
      local appimage_dir
      appimage_dir="$(dirname "$appimage")"
      echo "=== Checking $appimage ==="
      ( cd "$appimage_dir" && \
        rm -rf squashfs-root && \
        ./"$(basename "$appimage")" --appimage-extract >/dev/null 2>&1 || true
        while IFS= read -r -d "" f; do
          if file "$f" | grep -q ELF; then
            check_file_glibc "$f"
          fi
        done < <(find squashfs-root -type f -print0)
        rm -rf squashfs-root
      )
    }

    # ── Pre-build cleanup ─────────────────────────────────────────────────────
    check_system_glibc
    find /work -name "linuxdeploy*.AppImage" -delete -print
    find /work -name "*.AppDir" -type d -exec rm -rf {} + 2>/dev/null || true
    find /work -name "*.appdir" -type d -exec rm -rf {} + 2>/dev/null || true
    find /work -name "squashfs-root" -type d -exec rm -rf {} + 2>/dev/null || true

    # ── Build each script ─────────────────────────────────────────────────────
    ALL_APPIMAGES=()
    for i in "${!SCRIPT_PATHS_IN_CONTAINER[@]}"; do
      SCRIPT_IN_CONTAINER="${SCRIPT_PATHS_IN_CONTAINER[$i]}"
      SCRIPT_DIR_IN_CONTAINER="${SCRIPT_DIRS_IN_CONTAINER[$i]}"
      echo ""
      echo "════════════════════════════════════════════════════"
      echo "Building: $SCRIPT_IN_CONTAINER"
      echo "════════════════════════════════════════════════════"

      chmod +x "$SCRIPT_IN_CONTAINER"
      ( cd "$SCRIPT_DIR_IN_CONTAINER" && "$SCRIPT_IN_CONTAINER" )

      mapfile -t appimages < <(find "$SCRIPT_DIR_IN_CONTAINER" -maxdepth 1 -type f -name "*-x86_64.AppImage" | sort)
      if [ "${#appimages[@]}" -eq 0 ]; then
        echo "ERROR: no AppImages produced by $SCRIPT_IN_CONTAINER" >&2
        exit 1
      fi
      ALL_APPIMAGES+=("${appimages[@]}")
    done

    # ── Check & clean up, leave final AppImages in place ─────────────────────
    check_system_glibc
    echo ""
    echo "=== All produced AppImages ==="
    printf "%s\n" "${ALL_APPIMAGES[@]}"

    for appimage in "${ALL_APPIMAGES[@]}"; do
      check_appimage "$appimage"
    done

    echo ""
    echo "=== Cleaning up temporary build artifacts ==="
    find /work -name "linuxdeploy*.AppImage" -delete -print
    find /work -name "*.AppDir" -type d -exec rm -rf {} + 2>/dev/null || true
    find /work -name "*.appdir" -type d -exec rm -rf {} + 2>/dev/null || true
    find /work -name "squashfs-root" -type d -exec rm -rf {} + 2>/dev/null || true
    echo ""
    echo "=== Done. Final AppImages ==="
    printf "%s\n" "${ALL_APPIMAGES[@]}"
  '
