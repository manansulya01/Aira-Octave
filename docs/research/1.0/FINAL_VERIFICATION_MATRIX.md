# AiraOS-Octave 1.0.0 Final Verification Matrix

Method: feature → implementation → test (executed in guest) → evidence log.
Regression: test-all.sh 8/8 PASS (2026-09-18) + test-release.sh 1.0.0 PASS.

## BOOT — VERIFIED
| Feature | Location | Test | Evidence |
|---|---|---|---|
| Kernel boot/markers, no panic | linux-7.2.2/bzImage | test-kernel.sh (+5x stress) | baseline/qemu-baseline-*.log |
| grub ISO boot | release/aira-octave-1.0.0.iso | test-iso.sh | release/iso-boot-1.0.0-*.log |
| Release pipeline | scripts/test-release.sh | test-release.sh 1.0.0 | checksums OK + ISO boot |

## SYSTEM — VERIFIED
CPU/SMP/memory/scheduler/filesystem/devices: Linux 7.2.2 (inherited, configured);
platform listing via `aira platform` (cpu/pci/virtio/input), guest-asserted;
evidence services-*.log. PCI/VirtIO/e1000/ata/i8042: QEMU VERIFIED (0.3 report).

## SECURITY — VERIFIED basics
root+aira, /root 700, DAC deny/allow, no setuid, no listeners, USER= services,
privileged-process dump; evidence services-*.log; audits 0.4/0.9. Residual: root
desktop/services, no login/firewall/encryption (documented).

## SERVICES — VERIFIED
boot/start/stop/restart/status/enable/disable/shutdown, deps, crash→failed→recover,
ordered shutdown + recovery; evidence services-*.log.

## PACKAGES — VERIFIED
build/search/info/install/verify/rollback/remove/update-check, corrupt+invalid
rejection, dep warnings, sample-app end-to-end; evidence services-*.log; local-repo
docs. Remote repos: UNSUPPORTED by design.

## GRAPHICS — VERIFIED (Xvfb path)
Xvfb+Xorg/JWM session, tray clock+xload, DejaVu fonts; evidence gui-*.log.

## APPLICATIONS — VERIFIED windows+content
Terminal, File Manager(mc), Text Editor(vi), System Monitor(live), Settings,
Network Manager, Package Center, Sysinfo, About: mapped-window count + content
asserts + screenshot + survives-exit; evidence gui-*.log + screenshots/*.xwd.
Interactive click-through: PARTIALLY VERIFIED (manual per DEMO_SCRIPT).

## DEVELOPER — VERIFIED workflow
C sample: host build → .apkg → repo → guest install/execute/remove; IPC loopback
TCP; evidence storage-*/network-*.log.

## RECOVERY — VERIFIED
Serial recovery shell (every boot), guarded shutdown/reboot with ordered service
stop, ACPI S5 poweroff in every autotest log.

## RELEASE — VERIFIED
Reproducible scripts, 1.0.0 tarball+ISO+sha256, checksum verification, ISO boot;
evidence release/ + test-release log.

## UNTESTED / UNSUPPORTED (declared)
Physical HW; Bochs VGA; DRI/GPU path; multi-vCPU; OOM; idle-CPU bench; Internet DNS;
remote repos; user-session separation. No fake claims anywhere.
