# AiraOS-Octave Testing

## Automated suite
```bash
bash scripts/test-kernel.sh      # boot to userspace (markers, no panic)
bash scripts/test-userspace.sh   # /init layout, busybox applets, aira CLI, services, users
bash scripts/test-build-rootfs-atomic.sh # mocked failure/success image-publication checks
bash scripts/test-storage.sh     # ext4 persist: create file, reboot, verify
bash scripts/test-network.sh     # lo + eth0 + dhcp/ping where permitted
bash scripts/test-services.sh    # start/stop/restart/status/deps
bash scripts/test-gui.sh         # Xvfb headless: desktop + 5 apps start, no crash
bash scripts/test-all.sh         # all above, single PASS/FAIL + logs
```
All scripts: timestamps, logs under `logs/final-completion/<area>/`,
correct exit codes (0 PASS, 1 FAIL, 2 infra error), panic/oops detection.

## Manual GUI verification (where automation limited)
1. `bash scripts/boot-qemu.sh --gpu virtio --net user --drive aira-rootfs.img`
2. In guest: `aira-session &` or `startx`
3. Check: panel, clock, launcher, open Terminal/File/Settings/Info/About,
   move focus, close/relaunch, no desktop crash on app exit.
4. Record: `logs/final-completion/gui/manual-*.log` + screenshot (VNC/screendump).

## Release gate
- 3 consecutive `test-kernel.sh` PASS on release bzImage+initramfs.
- `test-all.sh` PASS.
- See docs/RELEASE.md for artifact checksums.
