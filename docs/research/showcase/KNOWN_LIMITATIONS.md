# Known Limitations — AiraOS-Octave 1.1.0 (honest list)

- QEMU TCG only; no physical-hardware testing → no HW support claims.
- User-mode networking only (no bridge/TAP, no Wi-Fi; benign
  `regulatory.db` firmware notice at boot).
- Desktop/services run as root; no login manager, no user sessions.
- virtio-GPU/DRI Xorg path and human click-through of JWM: UNTESTED here
  (headless; gui-test covers Xvfb + apps + windows + screenshot).
- airapkg: local repo only (no network fetch, no signatures); duplicate
  tar members accepted (last wins); power-loss-during-copy relies on
  next-install rollback rather than copy-on-write transactions.
- Package DB is RAM-visible under `/var/lib/airapkg` (initramfs root);
  persistence of installed packages across reboots needs /persist backing
  (documented, not claimed otherwise).
- Shutdown: use `sync` before `poweroff -f`; hard poweroff with writes in
  flight can emit transient guest I/O errors (image itself verified clean).
- `test-all.sh` ISO test boots the newest `release/*.iso` present.
