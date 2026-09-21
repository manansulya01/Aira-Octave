# KNOWN LIMITATIONS — AiraOS-Octave 1.2.0 (honest list)

- QEMU TCG only; no physical-hardware testing → no HW support claims.
- User-mode networking only (no bridge/TAP, no Wi-Fi; benign `regulatory.db`
  firmware notice at boot).
- Desktop/services run as root; no login manager, no user sessions (USER=
  proven for services; non-root desktop is future work).
- IPC binds all interfaces at the `nc -ll` level: this BusyBox nc has no `-s`
  bind flag, so loopback-only cannot be enforced by listen address. Mitigations
  in place: QEMU user-net forwards no guest ports by default; privileged bus
  methods require the root-only token (600, per-boot, non-root cannot read —
  all tested). Do not expose the guest network beyond user-net without adding
  a real bind/firewall.
- IPC serves connections sequentially (nc `-ll`); concurrent clients succeed
  but queue. Tested 5× parallel with generous timeout; not a high-throughput
  bus.
- virtio-GPU/DRI Xorg path and human click-through of JWM: UNTESTED here
  (headless; gui-test covers Xvfb + apps + windows + screenshot).
- airapkg: local repo only (no network fetch, no signatures); power-loss
  during copy relies on next-install rollback rather than copy-on-write.
- Package DB lives on initramfs root (`/var/lib/airapkg`); installed files
  persist only with `/persist` backing (documented, not claimed otherwise).
- Shutdown: use `sync` before `poweroff -f`; hard poweroff with writes in
  flight can emit transient guest I/O errors (image itself verified clean).
- `test-all.sh` ISO test boots the newest `release/*.iso` present.
- Full `test-all.sh` takes ~20 min on TCG (extended by IPC coverage); harness
  timeouts (220s services/storage/network, 280s GUI) reflect that reality.
