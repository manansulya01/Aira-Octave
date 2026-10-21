# AiraOS-Octave Development Log — Autonomous Engineering & Polish Mission

## 2026-10-13 — Phase 1: Baseline
- Verified root `/home/manan/Aira-Octave`, branch `main` @ `84b0a05`, +52 ahead origin. No pushes made.
- Recorded 10 modified + 20 untracked paths; preserved all (no reset/clean/restore).
- Wrote `reports/baseline-20261013-0925.md`.
- Host pre-fix results: kernel PASS, userspace PASS, shell 107/0, features 52/0,
  files 56/0, settings 55/0, terms 37/0, sysstat 31/0, net 115/0, pkg 39/0,
  doctor 36/0, manifest 32/0, user 72/1 FAIL (shadow 644), services FAIL (guest IPC).

## 2026-10-13/14 — Phase 2: Build & test infra
- `chmod +x` 6 scripts that were 0644: build-initramfs, build-gui,
  check-gui-libs, test-full, pull-screenshots, test-user.
- Confirmed `scripts/test-all.sh` already propagates `PIPESTATUS` and reports
  SKIP vs FAIL separately (pre-existing user rewrite preserved, not redone).

## 2026-10-14 — Phase 4F fix: user/security
- Root cause: `aira-user _commit()` ran `chmod MODE TMP` then `cat TMP > TARGET`.
  Redirection preserves the target's mode, so shadow stayed 0644 world-readable.
- Fix: chmod the TARGET after the copy. Host `test-user.sh`: 72/1 → 73/0 PASS.
- Guest `guest-usertest.sh` accepted any mode starting with 6/4/2/0 (so 644
  passed as "safe"). Replaced with others-bit test `8#MODE & 0004 == 0`.
  Guest USERTEST: PASS (incl. `shadow mode 640 not world-readable`).

## 2026-10-14 — Phase 4B fix: IPC bus (critical)
- Symptom: fresh-image guest autotest showed every `aira-ipc` call returning
  empty; early rejects (bad-version/malformed) still worked.
- Root cause: new `audit_log()` references `$5` under `set -u`, but the
  success path calls it with 4 args → unbound-variable abort before `respond`.
- Fix: `${5:-}`. Rebuilt initramfs; guest autotest went FAIL → PASS, zero FAIL
  lines. `test-services.sh`: FAIL → PASS. DEVPERM: PASS (incl. unprivileged bus
  use, shadow/token denial).

## 2026-10-14 — Phase 5: GUI polish (JWM + xmessage + text console)
- `gui/aira-welcome`: dropped emoji (no font coverage on console/minimal X),
  fixed `airapk`→`airapkg` typos, corrected Alt+F4 (Close, not Editor) and
  Editor launch path per `aira-jwmrc`, stopped forcing `DISPLAY` (headless stays
  text), made stdin-closed runs non-hanging, replaced invented NET/DSK tour
  values with live-or-generic text.
- `gui/aira-help`: corrected shortcut table, listed all 11 real IPC services,
  added `-h/--help`, fixed `grep "$TOPIC"` option-injection with `--`, made
  HELP_DIR fall back to TMPDIR when /usr unwritable (host-testable).
- `gui/aira-about`: storage line now checks `/persist` mount instead of
  trusting `df /persist`; no invented values (host shows host, guest shows guest).
- Verified: `sh -n` all three, `--help`/dash-topic/about/welcome headless runs,
  skip-flag behavior. Guest autotest help/docs block still PASS after rebuild.

## 2026-10-14 — Phase 6: Regression
- Rebuilt initramfs (final `765d1d79…`, 2631168 B); `boot-qemu` + kernel PASS.
- Host re-runs: shell 107/0, settings 55/0, terms 37/0, sysstat 31/0,
  net 115/0, pkg 39/0, doctor 36/0, manifest 32/0, features 52/0, files 56/0,
  user 73/0, userspace PASS, demo PASS.
- Guest: AUTOTEST PASS (no FAIL), USERTEST PASS, DEVPERM PASS,
  `test-services.sh` PASS, single-boot persist verify PASS (incl.
  cross-boot `persist-exists` marker).
- Regenerated `release/MANIFEST.txt` (0 missing, hashes current).
- Skipped, not claimed: full 2×220s `test-storage.sh`, 280s `test-gui.sh`
  (Xvfb), `test-iso.sh` (prebuilt ISO predates commit) — documented below.
- Preserved unknown artifact `"$_gtmp"|` untouched; pre-existing `init`,
  `guest-autotest.sh`, `test-all.sh` user rewrites untouched.

## 2026-10-15 — Release verification & completion
- Phase A: baseline `reports/baseline-20261015-0900.md`; `git diff --check` clean;
  artifacts present; prior fixes confirmed in checkout; `"$_gtmp"|` preserved;
  new log dir `logs/verify-20261015-0900/`; rootfs backed up to
  `/tmp/aira-rootfs-backup-20261015.img` (536870912 B).
- Phase B: full `scripts/test-storage.sh` PASS across both 220s boots
  (`storage-boot1/2-20261015-112738.log`, `persist-exists` marker in boot2).
- Phase C: full `scripts/test-gui.sh` PASS (280s, 1G, drive). Guest GUI markers
  all OK incl. 8 client windows, sysinfo/about content, 4 workspaces (EWMH),
  6 themes, 6 wallpapers, indicators, notify drain, WM-restart survival,
  `screenshot 3148907 bytes`. Screenshot extracted from the image via debugfs
  (`screenshots/aira-gui-shot.xwd`), converted XWD→PNG with a stdlib-only
  script (1024x768 TrueColor verified), visually inspected: JWM desktop, Editor
  + System Information (real os-release/IPC/memory/persist/kernel/CPU data) +
  notify dialog readable, no clipping of dialog content, taskbar intact.
  Saved as `logs/verify-20261015-0900/desktop-20261015.{png,xwd}`.
  Observation (not a defect): IPC-sourced lines in sysinfo render spaces as
  underscores (pre-existing C0 payload encoding); direct sections unaffected.
- Phase D: `scripts/test-network.sh` (guest, `--net user`, virtio NIC) PASS.
- Phase E: old 1.5.0 ISO/tarball backed up to /tmp; `build-release.sh` rebuilt
  from current source (ISO 567660544 B, tarball 117535314 B); packaged
  initramfs hash equals live `initramfs.cpio`; `release-manifest.sh` clean.
- Phase F: `test-iso.sh 1.5.0` on the fresh ISO: ISO BOOT TEST PASS.
- Phase G: regression — kernel PASS, userspace PASS, user 73/0, manifest 32/0,
  guest AUTOTEST PASS (zero FAIL) after cleanup changes; `git diff --check` clean.
- Phase H: help fallback cache now trap-cleaned (only our own TMPDIR dir, never
  the system path; verified no `/tmp/aira-help-*` litter); welcome gained
  explicit `--force`/`--tour`/`--help` parsing with `show_tour_text()` shared by
  dialog and headless paths (verified `--help`, `--tour` live output, skip
  behavior, `sh -n`). Rebuilt initramfs + release + ISO + manifest afterwards
  so artifacts match source; re-ran autotest/ISO/manifest/userspace.
- No commits, no pushes, no resets; `"$_gtmp"|` still preserved.


## 2026-10-21 — Full-build CI failure analysis and correction
- Inspected full OS workflow run 39247102383 at commit
  `6a514432b650c2bb437a88b4e45371da4847badd`.
- Evidence: Linux 7.2.2 kernel build PASS; initramfs build PASS; rootfs step
  failed with `ERROR: rootfs staging directory is missing: .../rootfs`.
  All downstream guest/recovery/persistence/release/ISO checks were skipped.
- Root cause in workflow ordering: it invoked `scripts/build-rootfs.sh 256`
  without first running the existing `scripts/build-gui.sh`, which stages
  desktop packages into `rootfs/`. The repository's `.gitignore` excludes
  `rootfs/`, so a clean CI checkout does not contain that generated staging tree.
- Correction committed to `main` as
  `ff03d0c84bc8751959af35ad11376890f377e014`: stage GUI before rootfs, use
  the documented 512 MiB desktop image size, and explicitly install curl.
- Verification status at log time: correction committed; follow-up full workflow
  has not yet been confirmed green. Do not claim release/boot success until
  the new run completes and its logs are inspected.

- Follow-up coverage improvement committed as
  `16d39563f8792a9ffae9bf9da27b4036d8b6ac65`: the full CI workflow now also
  runs the existing `test-gui.sh` (guest desktop/apps under QEMU) and
  `test-network.sh` (QEMU NIC/loopback checks). These checks were absent from
  the first full-build workflow; release verification should exercise the
  actual desktop and network path, not only kernel/initramfs startup.
- The latest workflow run and its results still need to be inspected before
  marking these checks or the release as passing.
