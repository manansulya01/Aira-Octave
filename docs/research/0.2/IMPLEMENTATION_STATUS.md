# 0.2 Implementation Status (starting from verified 0.1.0)

## COMPLETE (verify, don't rewrite)
Kernel 7.2.2/GZIP/SMP, serial boot, initramfs+BusyBox, /init, ext4 persist (2-boot),
users root+aira+DAC test, aira-init services, aira CLI, airapkg local flow, loopback+e1000/virtio-net,
Xvfb/JWM desktop + xterm/mc/xmessage apps + screenshot, build/test/release scripts, ISO boot.

## NEEDS HARDENING (0.2 work)
- Boot UX: shutdown/reboot commands (aira shutdown/reboot missing), service-failure handling.
- aira CLI: missing services/storage/users/packages/version subcommands (has info/system/status/service/network/package/diagnose/update).
- airapkg: missing search/info/update-check; no local repo docs (docs/PACKAGE_MANAGEMENT.md missing).
- Services: no enable/disable, no non-root users, restart policy unenforced.
- Desktop identity: JWM default look + blue solid; no wallpaper image, no Aira icons, no menu categories.
- Apps: no text editor, no system monitor (dynamic CPU/mem), no package center GUI; file-mgr/settings click-through partial.
- Demo: no scripts/demo.sh, no aira demo, no SHOWCASE.md, no screenshots dir.
- Docs: missing PACKAGE_MANAGEMENT.md, HARDWARE_COMPATIBILITY.md (have HARDWARE_SUPPORT.md).

## PARTIAL (finish in 0.2)
- File manager / settings interactive verification (headless-tested wrappers only).
- virtio-gpu /dev/dri path (Xvfb verified instead).
- Real-HW support (QEMU only).

## MISSING (build in 0.2)
- aira shutdown/reboot/version/storage/users/services/packages subcommands.
- Service enable/disable + run-as-user for safe services.
- Text editor, system monitor, package center GUI apps + menu categories + icons + wallpaper.
- Demo mode + showcase doc + demo script + screenshots + performance doc.
- 0.2.0 release + 5x boots + final audit.

## Priority (per mission)
BOOT > ROOTFS/USERSPACE > SERVICES > SECURITY > STORAGE > NETWORKING > GRAPHICS > DESKTOP > APPS > PKG > TESTING > RELEASE > SHOWCASE > DOCS > POLISH.
