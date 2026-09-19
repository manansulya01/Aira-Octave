# Showcase Guide — AiraOS-Octave 1.1.0

## One-command demo (desktop, serial console stays for narration)
```sh
qemu-system-x86_64 -kernel linux-7.2.2/arch/x86/boot/bzImage \
  -initrd initramfs.cpio \
  -append "console=ttyS0 rdinit=/init loglevel=7 aira_gui=1" \
  -m 1G -nographic -no-reboot \
  -drive file=aira-rootfs.img,if=virtio,format=raw \
  -device virtio-net-pci,netdev=n0 -netdev user,id=n0
```
Then in the shell: `export DISPLAY=:0; xwininfo -root; aira demo`.

## Tour script (serial shell + desktop)
1. `aira info` / `aira system` — version, kernel, CPU, memory.
2. Desktop on :0 (JWM) — Aira menu → System Information (live data).
3. File Manager (mc) — browse `/persist`, create a file.
4. Text Editor (vi) — edit + save the file.
5. System Monitor — live CPU/mem/procs. 6. Network Manager — `eth0`
   10.0.2.15 via fixed DHCP. 7. Package Center — `airapkg` list/search.
8. Terminal — real shell. 9. `aira status` — services.
10. `aira demo` — guided live tour. 11. `aira shutdown --force` (sync first).

## Text-only quick boot (no GUI/disk/net)
```sh
bash scripts/boot-qemu.sh --mem 512M --timeout 30
```
## Full validation
```sh
bash scripts/test-all.sh            # 8 suites
bash scripts/test-release.sh 1.1.0  # build + checksums + ISO boot
```
Evidence: `docs/research/showcase/evidence/desktop-1.1.0.xwd` (root-window
screenshot from the passing GUI test).
