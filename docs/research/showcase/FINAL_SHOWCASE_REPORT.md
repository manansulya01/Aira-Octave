# Final Showcase Report — AiraOS-Octave 1.1.0 (2026-09-19)

## Release
- VERSION 1.1.0, kernel Linux 7.2.2 x86_64 (bzImage `e198875c`),
  initramfs `82a9588b`, rootfs `5569686e`, ISO `7e9c0821`, tar `e7f195e1`.
- Release dir: `release/aira-octave-1.1.0/` (+ .iso/.tar.gz/.sha256).
  Working files and release files are SHA-identical; the shipped ISO was
  booted to userspace. TEST-ALL 8/8 PASS. Release pipeline PASS.
  10-boot matrix: 10/10. CPU/mem: 256M/512M/1G/2G + smp2 PASS.

## System status
BOOT/USERSPACE/SERVICES/STORAGE/NETWORK/PACKAGES/SECURITY/DESKTOP/
APPLICATIONS/DEMO/GUI/PERFORMANCE/RELEASE: see FINAL_VERIFICATION_MATRIX
(all VERIFIED except human click-through PARTIAL, DRI UNTESTED, HW UNSUPPORTED).

## Every bug: found → root cause → fix → test → result
1. DHCP lease discarded (no default.script) → shipped script, `-s` everywhere
   → 10.0.2.15/24 + route + DNS live. FIXED/VERIFIED.
2. init auto-GUI checked /persist before mounting it → moved after mount +
   services → Xvfb :0 + jwm live. FIXED/VERIFIED.
3. airapkg `chmod +x` on all files → `cp -p` + heuristic → 755/600 preserved.
   FIXED/VERIFIED.
4. airapkg upgrade left stale files → old-list diff removal (`removed stale`)
   → V2 clean. FIXED/VERIFIED.
5. airapkg sourced PKGINFO (code exec) → parse-only + token validation →
   canary untouched. FIXED/VERIFIED.
6. airapkg installed own `/list.txt` → excluded → sandbox root clean.
   FIXED/VERIFIED.
7. GUI DHCP actions lacked `-s`; settings used `read -p` (busybox) →
   fixed both → paths work. FIXED/VERIFIED.
8. JWM menu duplicates; tray swallows had no X window → deduped menus,
   `xterm -e` indicators with refresh. FIXED/VERIFIED (tray pixelsnd
   human-viewed: PARTIAL).
Prior-mission observations closed: hotplug error GONE (removed obsolete op);
stale-PID service failures GONE (oneshot done/failed model + dep fix).

## Remaining limitations
See KNOWN_LIMITATIONS (QEMU-only, root desktop, local pkg repo, untested DRI /
click-through, sync-before-poweroff).

## Exact showcase commands
See SHOWCASE_GUIDE (one-command `aira_gui=1` desktop boot, tour script,
test-all / test-release invocations).
