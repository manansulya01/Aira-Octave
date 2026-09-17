# Feature Verification Matrix (2026-09-17, post-regression)

Method: every feature → implementation file → test → executed in guest → evidence log.
Full run: test-all.sh 8/8 PASS (2026-09-17 12:03–12:05) + ISO retest PASS (12:07).

## VERIFIED
| Feature | Code | Test | Evidence |
|---|---|---|---|
| Kernel boot/markers | linux-7.2.2/bzImage | test-kernel.sh | baseline/qemu-baseline-*.log |
| /init mounts/hostname/mdev | initramfs/init | autotest (via services/storage) | services-*.log |
| aira help/info/version/system/status | initramfs/usr/bin/aira | autotest aira_* | services-*.log |
| aira network (+dhcp renew) | aira | autotest + network suite | network-*.log |
| aira storage | aira | autotest | services-*.log |
| aira users | aira | autotest | services-*.log |
| aira package/* passthrough | aira | autotest | services-*.log |
| aira update --check | aira | autotest | services-*.log |
| aira shutdown/reboot guards | aira | autotest (exit≠0) | services-*.log |
| aira demo tour | aira-demo | autotest + test-demo.sh | demo/demo-*.log |
| airapkg list/search/info/install/verify/remove/update-check/build | airapkg | autotest pkg_* | services-*.log, storage-*.log |
| airapkg invalid rejection | airapkg | autotest | services-*.log |
| services boot/start/stop/restart/status | aira-init | autotest + services suite | services-*.log |
| services enable/disable | aira-init | autotest link asserts | services-*.log |
| services USER=aira (+ownership) | aira-init | autotest marker UID | services-*.log |
| unknown-service rejection | aira-init | autotest | services-*.log |
| users root+aira, DAC deny/allow | passwd/group/init chown | autotest permissions | services-*.log |
| ext4 persist 2-boot | aira-rootfs.img | test-storage.sh | storage/storage-boot*.log |
| loopback ping, eth0, virtio-net | kernel+aira-net-setup | test-network.sh | network-*.log |
| Xvfb start, JWM, tray clock+xload | gui/aira-session,jwmrc | test-gui.sh | gui/gui-*.log |
| terminal/file-mgr/textedit/pkgcenter windows | gui/* | test-gui.sh count≥5 | gui-windows.log in gui-*.log |
| sysmon data, sysinfo/about content | gui/* | test-gui.sh grep | gui-*.log |
| mc present, screenshot 3.1MB | gui/* | test-gui.sh | screenshots/aira-gui-shot.xwd |
| desktop survives app exit | JWM session | test-gui.sh pidof | gui-*.log |
| demo boot mode | guest-demo.sh+/init hook | test-demo.sh | demo-*.log |
| release ISO boot | build-release.sh | test-iso.sh | release/iso-boot-*.log |
| build reproducibility | scripts/build-*.sh | test-all + checksums | release/*.sha256 |

## PARTIAL
| Feature | Gap |
|---|---|
| File-mgr/settings click-through | windows launch verified; interactive use manual (DEMO_SCRIPT) |
| virtio-gpu /dev/dri path | Xvfb verified instead; driver built-in, untested |
| JWM window titles under TCG | count-based verification (titles lag on slow emulation) |

## UNTESTED / UNSUPPORTED
Physical HW; Bochs VGA; Internet/DNS beyond user-net; remote pkg repos;
multi-vCPU; OOM; idle-CPU bench. All pre-declared, no fake claims.

## Failures found + fixed this pass
1. `sh FILE` needs path (sysinfo/about never ran) → `command -v` + content asserts.
2. xload `#color` shell-comment death → named colors.
3. Test windows exited before snapshot → persistent sleeps + 60s poll + count-based matching.
4. test-demo.sh missing +x → SKIP silently → chmod; test-all now runs demo+iso (8 suites).
