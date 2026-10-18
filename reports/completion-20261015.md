# Completion Report — AiraOS-Octave Release Verification (2026-10-15)

## WHAT FOUND
1. Prior fixes confirmed intact in checkout (aira-user chmod-target, guest-usertest
   others-bit check, aira-ipc-handle `${5:-}`, 6 executable scripts, GUI corrections).
2. Stale release artifacts: shipped 1.5.0 ISO/tarball (Sep 28) packaged initramfs
   `ccd02730…`, not the fixed `765d1d79…` — rebuilt.
3. Two deferred cleanups implemented (help cache litter, implicit `--tour`).
4. Screenshot path traced: guest `aira-gui-test` writes XWD into the rootfs image
   (`/screenshots/aira-gui-shot.xwd`), extractable via debugfs; no host converter
   existed, so a stdlib-only XWD→PNG path was used for inspection.
5. Cosmetic observation (not a defect, unchanged): IPC-sourced sysinfo lines render
   spaces as underscores (pre-existing C0 payload encoding); direct /proc sections
   render normally. Left as-is.
6. No new defects found in storage, GUI, guest network, ISO, or regression runs.

## WHAT CHANGED
- `gui/aira-help`: fallback cache dir now trap-cleaned on EXIT/HUP/INT/TERM, and
  only when the fallback (not the system path) was used.
- `gui/aira-welcome`: explicit arg parsing (`--force`, `--tour`, `-h/--help/help`
  with usage); tour body factored into `show_tour_text()` shared by the xmessage
  dialog and a new headless text path, so `--tour` works without a display; all
  values remain live-or-generic.
- Rebuilt: `initramfs.cpio` → release dir → ISO/tarball/sha256 → `release/MANIFEST.txt`.
- Added: `reports/baseline-20261015-0900.md`, `reports/completion-20261015.md`,
  `logs/verify-20261015-0900/desktop-20261015.{png,xwd}`, dev-log entries.
- Preserved: all prior user modifications, `"$_gtmp"|` artifact, old ISO/tarball
  backups in `/tmp` (not in repo), previous logs/reports.

## WHY
- Trap scope guard (`_HELP_TMP`) makes cache cleanup safe: it can never delete the
  system help index or user files — only the per-PID dir the process created.
- Explicit `--tour` closes the gap between the skip condition (which already named
  `--tour`) and behavior (which had no `--tour` path); shared function prevents
  dialog/text drift; no metrics invented (same live-or-generic sources).
- Release rebuild required because the shipped ISO predated the security/IPC fixes;
  re-verified after every source change so artifacts always match source.

## TEST COMMAND
- `bash scripts/test-storage.sh` (2×220s boots, drive image)
- `bash scripts/test-gui.sh` (280s, 1G, drive, `aira_autotest=1 aira_guitest=1`)
- `bash scripts/test-network.sh` (220s, `--net user`)
- `bash scripts/build-release.sh` (VER default 1.5.0)
- `bash scripts/test-iso.sh 1.5.0` (60s grub boot)
- `bash scripts/release-manifest.sh`, `bash scripts/test-manifest.sh`
- `bash scripts/test-user.sh`, `bash scripts/test-kernel.sh`, `bash scripts/test-userspace.sh`
- `bash scripts/boot-qemu.sh --timeout 120 --log LOG --append aira_autotest=1`
- GUI behavior: `aira-welcome --help/--tour`, skip-flag run, `aira-help --help`, `sh -n` both.

## RESULT
- Storage: PASS (boot1 persist write + boot2 `persist-exists from previous boot`).
- GUI: PASS — guest markers all OK (8 windows mapped, sysmon/netman data, sysinfo/
  about content, jwm -p parse, indicators, workspace keys, 4 EWMH workspaces,
  6 themes + set/readback, 6 wallpapers + set, launcher, quick-settings rows,
  vol/power/net/storage indicator lines, notify drain+history, WM-restart survival,
  EXPECT marker, screenshot 3148907 B, post-apps survival). No panic.
- Guest network: PASS (`--net user`, virtio-net-pci).
- Guest AUTOTEST (post-cleanup image): PASS, zero FAIL lines.
- ISO (freshly built): ISO BOOT TEST PASS (Linux version + userspace ready, no panic).
- Manifest: 32/0, 0 missing, hashes current. Kernel boot: PASS. Userspace: PASS.
  User suite: 73/0. `git diff --check`: clean.
- Prior counts re-confirmed unchanged (shell 107/0, features 52/0, files 56/0,
  settings 55/0, terms 37/0, sysstat 31/0, net-host 115/0, pkg 39/0, doctor 36/0).

## RELEASE ARTIFACTS
- Kernel: `linux-7.2.2/arch/x86/boot/bzImage`, 15053824 B,
  sha256 `5b48abc35b34d313fdc3a3fb715f1c2fdcba37d3144260f36fd9bc210362aaea`
- Initramfs: `initramfs.cpio`, 2631680 B,
  sha256 `c30e45fb701ed6ff53661729e59f1a080f5fdc9ccb529684ebad5a53cbcd824e`
  (packaged copy identical: `release/aira-octave-1.5.0/boot/initramfs.cpio`)
- Rootfs: `aira-rootfs.img`, 536870912 B (also packaged copy `36798884…`; contains
  test markers/screenshots from verification by design of the live image)
- ISO: `release/aira-octave-1.5.0.iso`, 567660544 B,
  sha256 `97e1704cc6b57485715d1982b8f1d3e1888183dd7691d82b96a6c6203be4f963`
- Tarball: `release/aira-octave-1.5.0.tar.gz`, 117535314 B,
  sha256 `eade5f5d6df9aaf880ec81982a28abe4208ecf0b6b474958973a5ebf9a0807ad`
- Checksums: `release/aira-octave-1.5.0.sha256` (5 entries)
- Manifest: `release/MANIFEST.txt` (regenerated, 0 missing)
- Grub cfg, kernel-config.txt, boot-qemu.sh, RELEASE_NOTES.txt under
  `release/aira-octave-1.5.0/`

## SCREENSHOTS
- `logs/verify-20261015-0900/desktop-20261015.xwd` (3148907 B, raw XWD from guest)
- `logs/verify-20261015-0900/desktop-20261015.png` (32645 B, converted inspection copy)
- Content verified by direct viewing: JWM desktop (workspace pager 1–4, taskbar),
  AiraOS Editor window, System Information dialog with real data
  (os-release 1.5.0/Linux 7.2.2, IPC system.version/info/memory, persist mounted
  /dev/vda, kernel build string, QEMU Virtual CPU), notify dialog, all text
  readable, no dialog clipping, no blank screens, no error dialogs.

## REMAINING PROBLEMS
- None blocking. Full storage, GUI+Xvfb+screenshot, guest network, fresh-ISO suites
  all completed and passing this session.
- Cosmetic note: IPC-sourced sysinfo lines show underscores for spaces (pre-existing
  encoding); not changed to avoid redesigning the C0 wire format.
- Pre-existing release `1.5.0` version number reused for the rebuilt artifacts
  (repo has no newer version tag); hashes/checksums distinguish the new build.

## WORKTREE STATE
- Branch: `main` @ `84b0a05631c8d94eb4c06eccf8af0167ee8caa98`.
- Status: 11 modified (`gui/aira-about`, `gui/aira-help`, `gui/aira-welcome`,
  `initramfs.cpio`, `initramfs/init`, `initramfs/sbin/aira-ipc-handle`,
  `initramfs/sbin/guest-autotest.sh`, `initramfs/usr/bin/aira-user`,
  `release/MANIFEST.txt`, `scripts/build-initramfs.sh`, `scripts/test-all.sh`)
  plus preserved untracked work including `"$_gtmp"|` (untouched),
  `docs/DEVELOPMENT_LOG.md`, guest-usertest, packaged GUI copies, doc sync,
  logs, release dir, both reports, `scripts/test-user.sh`, `test-ipc-library.sh`.
- `git diff --stat`: 624 insertions, 205 deletions across the 11 tracked files
  (binary initramfs 2380800 → 2631680 B).
- Nothing committed, nothing pushed, no resets/cleans/restores performed.
