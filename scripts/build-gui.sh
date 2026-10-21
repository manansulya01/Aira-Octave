#!/usr/bin/env bash
# Stage GUI (X11+JWM+apps) into rootfs/ by downloading Ubuntu debs (no sudo needed).
# Then run build-rootfs.sh to make aira-rootfs.img. Logs everything.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
OUTDIR="$ROOT/logs/final-completion/build"
mkdir -p "$OUTDIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
LOG="$OUTDIR/gui-build-$TS.log"
STAGE="$ROOT/rootfs"
DLDIR="$OUTDIR/debs-$TS"
mkdir -p "$STAGE" "$DLDIR"
echo "LOG=$LOG STAGE=$STAGE"
{
  echo "TS=$TS"
  git rev-parse HEAD
} | tee "$LOG"

# Core set (small, no GTK): Xvfb+Xorg, JWM, xterm, mc, x11-utils + required libs.
# Includes Xorg video/input drivers for the visible desktop: modesetting is in
# xserver-xorg-core; vesa/fbdev cover QEMU std VGA; libinput covers virtio
# keyboard/mouse. Libs are downloaded explicitly to avoid recursive explosion;
# missing libs added iteratively on test failure.
PKGS="jwm xterm xvfb xserver-xorg-core xserver-xorg-input-libinput xserver-xorg-input-evdev xserver-xorg-video-vesa xserver-xorg-video-fbdev xinput x11-utils x11-xserver-utils x11-apps mc xauth x11-xkb-utils xbitmaps mc-data xkb-data xfonts-base xfonts-encodings xfonts-utils xserver-common"
PKGS="$PKGS libc6 libx11-6 libxcb1 libbsd0 libmd0 libpcre2-8-0 liblzma5 zlib1g libzstd1 libexpat1 libuuid1 libblkid1 libmount1 libsmartcols1 libfdisk1 libffi8 libdrm2 libxshmfence1 libfontenc1"
PKGS="$PKGS libpixman-1-0 libxfont2 libgl1 libxaw7 libxmu6 libxpm4 libxft2 libxinerama1 libxrender1 libxext6 libxt6t64 libice6 libsm6 libfontconfig1 libfreetype6 libglib2.0-0t64 libslang2 libgpm2 libssh2-1t64 libext2fs2t64 libcairo2 libpango-1.0-0 libpangoft2-1.0-0 libpangoxft-1.0-0 libjpeg8 libpng16-16t64 librsvg2-2 libxcomposite1 libxrandr2 libxkbfile1 libxmuu1 libxtst6 libxv1 libxxf86dga1 libxxf86vm1 libxcb-shape0 libx11-xcb1 libutempter0 libtinfo6 libaudit1 libselinux1 libsystemd0 libunwind8 libnettle8t64 libxdmcp6 libxau6 libxcursor1 libxi6 libxcb-damage0 libxcb-present0 libxcb-xfixes0"
PKGS="$PKGS libglvnd0 libglx-mesa0 libglapi-mesa libegl-mesa0 libgbm1 libwayland-client0 libglx0 libopengl0 libegl1 libbz2-1.0 liblz4-1 libcap2 libgcrypt20 libgpg-error0 libxfixes3 libatomic1 libbrotli1 libcairo-gobject2 libcap-ng0 libcom-err2 libssl3t64 libepoxy0 libfribidi0 libgcc-s1 libgdk-pixbuf-2.0-0 libharfbuzz0b libjpeg-turbo8 libpangocairo-1.0-0 libpciaccess0 libthai0 libudev1 libxcb-dri3-0 libxcb-glx0 libxcb-randr0 libxcb-render0 libxcb-shm0 libxml2-16 libxxhash0 libdatrie1 libgl1-mesa-dri libglycin-2-0 libgraphite2-3 mesa-libgallium liblcms2-2 libseccomp2 libllvm21 libdrm-amdgpu1 libdrm-intel1 libelf1t64 libsensors5 libstdc++6 libxcb-sync1 libedit2 fontconfig fontconfig-config fonts-dejavu-core"
PKGS="$PKGS libinput10 libevdev2 libmtdev1t64 libwacom9 libdbus-1-3 libxcvt0 libgudev-1.0-0 libicu74"

# Resolve package names against the actual runner repositories. The manifest
# spans Ubuntu releases, where several runtime library package names changed.
VALID_PKGS=""
MISSING_PKGS=""
for pkg in $PKGS; do
  case "$pkg" in
    libglib2.0-0t64) alternatives="libglib2.0-0" ;;
    libext2fs2t64) alternatives="libext2fs2" ;;
    libnettle8t64) alternatives="libnettle8" ;;
    libpng16-16t64) alternatives="libpng16-16" ;;
    libssl3t64) alternatives="libssl3" ;;
    libxml2-16) alternatives="libxml2" ;;
    libllvm21) alternatives="libllvm20 libllvm19 libllvm18 libllvm17 libllvm16" ;;
    libxt6t64) alternatives="libxt6" ;;
    libssh2-1t64) alternatives="libssh2-1" ;;
    libjpeg8) alternatives="libjpeg-turbo8 libjpeg62-turbo" ;;
    libmtdev1t64) alternatives="libmtdev1" ;;
    libwacom9) alternatives="libwacom8 libwacom7" ;;
    libicu74) alternatives="libicu76 libicu78 libicu72 libicu70" ;;
    *) alternatives="" ;;
  esac
  selected=""
  for candidate in "$pkg" $alternatives; do
    if apt-cache show "$candidate" >/dev/null 2>&1; then
      selected="$candidate"
      break
    fi
  done
  if [ -n "$selected" ]; then
    VALID_PKGS="$VALID_PKGS $selected"
    [ "$selected" = "$pkg" ] || echo "PACKAGE_NAME_FALLBACK:$pkg=>$selected" | tee -a "$LOG"
  else
    MISSING_PKGS="$MISSING_PKGS $pkg"
  fi
done
echo "AVAILABLE_PACKAGE_COUNT=$(wc -w <<< "$VALID_PKGS")" | tee -a "$LOG"
if [ -n "$MISSING_PKGS" ]; then
  echo "PACKAGES_NOT_IN_RUNNER_REPOSITORIES:$MISSING_PKGS" | tee -a "$LOG"
fi
[ -n "$VALID_PKGS" ] || { echo "ERROR: no GUI package names resolve in configured APT repositories" | tee -a "$LOG"; exit 1; }

echo "Downloading GUI packages directly through APT" | tee -a "$LOG"
cd "$DLDIR" || exit 1
# apt-get download already downloads package archives. Combining it with
# --print-uris produced no parseable URLs on Ubuntu 24.04 and left this stage
# empty. Download the resolved package names directly and validate the output.
if ! apt-get download $VALID_PKGS >>"$LOG" 2>&1; then
  echo "ERROR: apt-get download failed for the resolved GUI package set" | tee -a "$LOG"
  tail -n 80 "$LOG"
  exit 1
fi
COUNT=$(find "$DLDIR" -maxdepth 1 -type f -name '*.deb' | wc -l)
echo "DEBS=$COUNT" | tee -a "$LOG"
[ "$COUNT" -ge 5 ] || { echo "ERROR: too few debs ($COUNT)" | tee -a "$LOG"; exit 1; }

for d in "$DLDIR"/*.deb; do
  if ! dpkg-deb -x "$d" "$STAGE" >>"$LOG" 2>&1; then
    echo "ERROR: extraction failed for $d" | tee -a "$LOG"
    exit 1
  fi
done

# Fail at staging time if the desktop's runtime-critical XKB compiler or ICU
# runtime is missing. The QEMU test also verifies the initramfs exposes these
# persistent-tree resources at the absolute paths expected by Xorg/Xvfb.
if [ ! -x "$STAGE/usr/bin/xkbcomp" ]; then
  echo "ERROR: x11-xkb-utils extraction did not provide usr/bin/xkbcomp" | tee -a "$LOG"
  exit 1
fi
ICU_RUNTIME="$(find "$STAGE/usr/lib" -name 'libicuuc.so.*' -print -quit 2>/dev/null)"
if [ -z "$ICU_RUNTIME" ]; then
  echo "ERROR: ICU runtime library libicuuc.so.* missing from GUI staging" | tee -a "$LOG"
  exit 1
fi
echo "GUI_RUNTIME_CHECK PASS: xkbcomp=$STAGE/usr/bin/xkbcomp ICU=$ICU_RUNTIME" | tee -a "$LOG"

# Aira GUI files
mkdir -p "$STAGE/etc/jwm" "$STAGE/usr/bin" "$STAGE/etc/aira" "$STAGE/usr/lib"
# C0: shared IPC client lib (canonical: usr/lib/aira-ipc.sh) for /persist apps
if [ -f "$ROOT/usr/lib/aira-ipc.sh" ]; then
  cp -f "$ROOT/usr/lib/aira-ipc.sh" "$STAGE/usr/lib/aira-ipc.sh"
  chmod 644 "$STAGE/usr/lib/aira-ipc.sh"
else
  echo "ERROR: $ROOT/usr/lib/aira-ipc.sh missing (C0 shared API)" | tee -a "$LOG"; exit 1
fi
cp -f "$ROOT/gui/aira-jwmrc" "$STAGE/etc/jwm/aira-jwmrc"
cp -f "$ROOT/gui/aira-jwmrc.classic" "$STAGE/etc/jwm/aira-jwmrc.classic"
[ -f "$STAGE/etc/aira/theme.conf" ] || cp -f "$ROOT/gui/aira-theme.conf.default" "$STAGE/etc/aira/theme.conf"
for b in aira-session aira-terminal aira-file-manager aira-settings aira-sysinfo aira-about aira-clock aira-gui-test aira-textedit aira-sysmon aira-pkgcenter aira-netman aira-net-indicator aira-storage-indicator aira-vol-indicator aira-power-indicator aira-welcome aira-help aira-notify aira-notifyd aira-session-mgr aira-dm aira-theme aira-wallpaper aira-launcher aira-quicksettings; do
  cp -f "$ROOT/gui/$b" "$STAGE/usr/bin/$b"
  chmod +x "$STAGE/usr/bin/$b"
done
# JWM needs /etc/jwm/system.jwmrc fallback (use ours)
cp -f "$ROOT/gui/aira-jwmrc" "$STAGE/etc/jwm/system.jwmrc" 2>/dev/null || true
# Ensure ld cache + basic dirs (var/lib/aira holds launcher recents on /persist)
mkdir -p "$STAGE/tmp/.X11-unix" "$STAGE/var/log/airaos" "$STAGE/var/lib/aira" "$STAGE/home/aira" "$STAGE/root"
chmod 1777 "$STAGE/tmp" 2>/dev/null || true
du -sh "$STAGE" | tee -a "$LOG"
echo "GUI STAGE PASS (now run scripts/build-rootfs.sh 512)"
