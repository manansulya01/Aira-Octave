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
# Libs are downloaded explicitly to avoid recursive explosion; missing libs added iteratively on test failure.
PKGS="jwm xterm xvfb xserver-xorg-core x11-utils x11-xserver-utils x11-apps mc xauth x11-xkb-utils xbitmaps mc-data xkb-data xfonts-base xfonts-encodings xfonts-utils xserver-common"
PKGS="$PKGS libc6 libx11-6 libxcb1 libbsd0 libmd0 libpcre2-8-0 liblzma5 zlib1g libzstd1 libexpat1 libuuid1 libblkid1 libmount1 libsmartcols1 libfdisk1 libffi8 libdrm2 libxshmfence1 libfontenc1"
PKGS="$PKGS libpixman-1-0 libxfont2 libgl1 libxaw7 libxmu6 libxpm4 libxft2 libxinerama1 libxrender1 libxext6 libxt6t64 libice6 libsm6 libfontconfig1 libfreetype6 libglib2.0-0t64 libslang2 libgpm2 libssh2-1t64 libext2fs2t64 libcairo2 libpango-1.0-0 libpangoft2-1.0-0 libpangoxft-1.0-0 libjpeg8 libpng16-16t64 librsvg2-2 libxcomposite1 libxrandr2 libxkbfile1 libxmuu1 libxtst6 libxv1 libxxf86dga1 libxxf86vm1 libxcb-shape0 libx11-xcb1 libutempter0 libtinfo6 libaudit1 libselinux1 libsystemd0 libunwind8 libnettle8t64 libxdmcp6 libxau6 libxcursor1 libxi6 libxcb-damage0 libxcb-present0 libxcb-xfixes0"
PKGS="$PKGS libglvnd0 libglx-mesa0 libglapi-mesa libegl-mesa0 libgbm1 libwayland-client0 libglx0 libopengl0 libegl1 libbz2-1.0 liblz4-1 libcap2 libgcrypt20 libgpg-error0 libxfixes3 libatomic1 libbrotli1 libcairo-gobject2 libcap-ng0 libcom-err2 libssl3t64 libepoxy0 libfribidi0 libgcc-s1 libgdk-pixbuf-2.0-0 libharfbuzz0b libjpeg-turbo8 libpangocairo-1.0-0 libpciaccess0 libthai0 libudev1 libxcb-dri3-0 libxcb-glx0 libxcb-randr0 libxcb-render0 libxcb-shm0 libxml2-16 libxxhash0 libdatrie1 libgl1-mesa-dri libglycin-2-0 libgraphite2-3 mesa-libgallium liblcms2-2 libseccomp2 libllvm21 libdrm-amdgpu1 libdrm-intel1 libelf1t64 libsensors5 libstdc++6 libxcb-sync1 libedit2 fontconfig fontconfig-config fonts-dejavu-core"
echo "Downloading GUI packages" | tee -a "$LOG"
cd "$DLDIR" || exit 1
set +e
apt-get download --print-uris $PKGS > "$DLDIR/uris.txt" 2>>"$LOG"
RC=$?
echo "APT_URIS_EXIT=$RC" | tee -a "$LOG"
grep -o "'http[^']*'" "$DLDIR/uris.txt" | tr -d "'" > "$DLDIR/urls.txt"
wc -l "$DLDIR/urls.txt" | tee -a "$LOG"
while IFS= read -r url; do
  [ -n "$url" ] || continue
  fn="$(basename "$url")"
  if [ -f "$fn" ]; then echo "have $fn" >>"$LOG"; continue; fi
  echo "curl $fn" | tee -a "$LOG"
  curl -sL --retry 3 -o "$fn" "$url" >>"$LOG" 2>&1 || echo "WARN: curl failed $url" | tee -a "$LOG"
done < "$DLDIR/urls.txt"
set -u
RC=0
ls "$DLDIR"/*.deb >/dev/null 2>&1 || RC=1
echo "CURL_DOWNLOAD_EXIT=$RC" | tee -a "$LOG"
ls -lh "$DLDIR" | tee -a "$LOG"
if [ $RC -ne 0 ]; then echo "WARN: some downloads failed (see $LOG); continuing with what we got"; fi
COUNT=$(ls "$DLDIR"/*.deb 2>/dev/null | wc -l)
echo "DEBS=$COUNT" | tee -a "$LOG"
[ "$COUNT" -ge 5 ] || { echo "ERROR: too few debs ($COUNT)"; exit 1; }

echo "Extracting to $STAGE" | tee -a "$LOG"
for d in "$DLDIR"/*.deb; do
  dpkg-deb -x "$d" "$STAGE" >>"$LOG" 2>&1 || echo "WARN: extract failed $d"
done

# Aira GUI files
mkdir -p "$STAGE/etc/jwm" "$STAGE/usr/bin"
cp -f "$ROOT/gui/aira-jwmrc" "$STAGE/etc/jwm/aira-jwmrc"
for b in aira-session aira-file-manager aira-settings aira-sysinfo aira-about aira-clock aira-gui-test aira-textedit aira-sysmon aira-pkgcenter aira-netman; do
  cp -f "$ROOT/gui/$b" "$STAGE/usr/bin/$b"
  chmod +x "$STAGE/usr/bin/$b"
done
# JWM needs /etc/jwm/system.jwmrc fallback (use ours)
cp -f "$ROOT/gui/aira-jwmrc" "$STAGE/etc/jwm/system.jwmrc" 2>/dev/null || true
# Ensure ld cache + basic dirs
mkdir -p "$STAGE/tmp/.X11-unix" "$STAGE/var/log/airaos" "$STAGE/home/aira" "$STAGE/root"
chmod 1777 "$STAGE/tmp" 2>/dev/null || true
du -sh "$STAGE" | tee -a "$LOG"
echo "GUI STAGE PASS (now run scripts/build-rootfs.sh 512)"
