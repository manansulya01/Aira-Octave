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

## 2026-10-21 — CI build hardening follow-up
- Updated `scripts/build-gui.sh` in commit
  `d506b9202e97e59b7d1c65b1d7e6a9254da2909b`:
  - records GUI package names unavailable in the runner's configured APT
    repositories instead of letting one absent name silently invalidate the
    entire URI-generation command;
  - fails on unresolved URI generation, failed/empty downloads, and failed
    package extraction instead of continuing with a partial desktop tree;
  - keeps the minimum-package guard and emits counts for diagnosis.
- Updated `.github/workflows/full-os-build-and-qemu.yml` in commit
  `5be7d70cf01627b851a0927b2e51cac8ff1a0f3e` so changes to GUI/network tests
  and build-safety regression scripts trigger full verification.
- These are source/configuration changes only. This environment has not
  executed the repository's WSL build or QEMU tests, and no passing Actions run
  has yet been confirmed. The next gate is inspecting the triggered run and
  correcting any actual failing step; do not mark the release verified yet.

- Additional portability fix committed as
  `fcd36956eba1530ca280fd69afe8b56b106449f5`: the GUI package resolver now
  tries known Ubuntu package-name transitions for GLib, ext2fs, nettle, PNG,
  OpenSSL, libxml2, and LLVM before declaring a package unavailable. Selected
  fallback names are logged explicitly.
- This is still awaiting the triggered clean-runner build. Package availability
  checks are not a substitute for actually booting and testing the resulting
  desktop in QEMU.

## 2026-10-21 — Release directory failure-safety fix
- Audit found `scripts/build-release.sh` previously wrote files directly into
  the existing `release/aira-octave-$VER/` directory before ISO generation.
  A simulated ISO failure could therefore preserve the old ISO/tar/checksum
  while leaving the versioned directory partly overwritten.
- Commit `91b8343d4ad0ad2c97615bea774683d213dbb82a` stages the versioned
  release directory under the private temporary workspace, builds ISO/tar/
  checksums from that staged content, and only swaps the directory after all
  generated artifacts pass basic non-empty checks. If the directory rename
  fails, it attempts to restore the previous directory.
- Commit `63d7677b9a031e2bba78f4222e7b137861eafe95` extends
  `scripts/test-build-release-guards.sh` to assert that a failed ISO build
  preserves a marker in the previous versioned directory and that a successful
  mocked build publishes the new directory content.
- Regression test execution and clean-runner QEMU verification remain pending;
  this entry records code changes, not a passing test result.

- Follow-up transaction audit found that rollback itself must not delete an
  original artifact if making its backup fails. Commit
  `231980fce028346cf84340aa8b4f9a4771de9da3` now copies backups without moving
  the originals, and only enters publication after all backup copies succeed.
  If any publish rename fails, it attempts to restore the old directory and
  top-level artifacts.
- Commit `d6c3c12d17e38c782447692b672ade1b7ce87dbd` adds a simulated tarball
  failure case and asserts that the previous release directory, ISO, tarball,
  and checksum manifest remain unchanged.
- These edits trigger the full workflow through the configured build/test path
  filters. The mocked test and full QEMU suite still need an observed run result;
  source inspection alone is not a test pass.

- The GUI package audit also found that the resolver could omit an unavailable
  core desktop component while still passing the broad minimum-package-count
  check. Commit `1f659b07d1986a18839531b0f5a4d4c7204c23e8` now makes the core
  JWM/X11/session packages mandatory and reports a specific missing package.
  This prevents a partially downloaded package set from being presented as a
  valid desktop stage. Clean-runner verification is still required.

## 2026-10-21 — CI-discovered release directory replacement bug
- The actual GitHub Actions run `39576094421` ran the mocked rootfs and release
  regressions. Rootfs atomic tests passed; the release test caught a real defect:
  POSIX `mv staged-directory existing-nonempty-directory` nests the staged
  directory rather than replacing the old release directory.
- Fixed in `0f9d6a798daf2501894afb5d31e2872f2d83b958`: after successful backups,
  release publication removes the existing directory and moves the staged
  directory into place; on any subsequent publish failure, the rollback routine
  restores the previous copy.
- The failing CI run was a valid red result, not ignored. The new commit triggers
  another syntax + full-build run. Await its regression result before treating
  the release fix as verified.

## 2026-10-21 — Update subsystem fail-closed correction
- Source audit found `initramfs/sbin/aira-update` was not a functioning updater:
  it wrote a hard-coded version, created an empty fake package, ignored package
  installation failure, and could still report success/change the OS version.
  Its snapshot/rollback path also did not validate snapshot completeness.
- Commit `4fa7dd5d1bdf6050a07fac44af185a2a2989f0b4` removes simulated download,
  install, and rollback behavior. Until a trusted feed, cryptographic signature
  verification, and transactional restore are implemented, those operations
  now fail closed and explicitly report that no data was changed. Status reports
  legacy candidates as unverified instead of implying rollback is available.
- Added `scripts/test-update-safety.sh` in commit
  `17260357bd23ef85a333bfd7bd96d68ec4e224fd`; it asserts check/download/install/
  rollback cannot claim success or modify version/legacy package state without
  a trusted backend. Added it to full-build regression gates in
  `fe554d4c7f009cbbf649b70b55d21604927411c6`.
- This is a correctness/security fix, not a claim that OTA updates are complete.
  A real signed update system remains an unfinished OS capability.

## 2026-10-21 — Installation path audit and guarded host installer
- Auditing `initramfs/sbin/aira-install` exposed several false-success/data-safety
  risks: it could partition before checking boot artifacts/tools, silently ignore
  copy/GRUB errors, use a raw SHA-256 digest as a password hash, and used Bash-only
  brace expansion in a BusyBox `sh` script. Commits
  `cd16d148290c4341f84d9edc6cf8731e83ff24f7` and
  `bfe345c80e80317489359875ed25430f282801fe` add preflight checks before disk
  changes, explicit unattended erase acknowledgement, mounted-device refusal,
  checked copies/boot payload, POSIX directory creation, and real SHA-512 crypt
  password hashing. The in-guest installer still depends on a live environment
  that actually provides the required tools and boot files; it is not a universal
  installer yet.
- Added host-side BIOS/MBR installer `scripts/install-to-disk.sh` in
  `894cc1e8748936f3baf2ec2a60fa590cd1412dce`. It validates the release inputs,
  whole-disk target, mount state, and required tools before formatting; requires
  an exact interactive erase confirmation by default; and installs the built
  rootfs, kernel, initramfs, and GRUB configuration. UEFI is explicitly out of
  scope for this script.
- Added non-destructive acknowledgement tests in
  `scripts/test-install-guard.sh` (`82d17399bdcf60f258f56033d94fab46e5091068`),
  wired them into full-build CI in `3670ddfc0458816fdcfbb741b5de637a6af40aed`,
  and documented the actual install path/limitations in
  `docs/INSTALL.md` (`9cac1df64651507866193327b032e2ad25a89506`).
- Updated initramfs persistence discovery in
  `2fda6dc32524957fccca670128b25a9a06f2980d` to handle both the development
  raw-ext4 disk image (`/dev/vda`) and a partitioned installed disk
  (`/dev/vda1`, plus common SATA/NVMe/eMMC names), preferring the AIRA_ROOT
  label when `blkid` is available.
- These installation changes are source changes only. The full build/QEMU and
  safety tests must pass before the installer is considered verified; no
  physical disk was formatted by this work.

- README audit found the quick-start instructions pointed QEMU at a nonexistent
  root-level `bzImage` and suggested creating a blank disk image that could not
  mount as the persistent ext4 filesystem. Commit
  `c01460389f09c29f1d020922a927707521d49f43` now uses release artifact paths,
  builds the real persistent image before boot, and corrects installer/updater
  status claims. This documentation correction does not itself verify a boot.

- Follow-up result: Core shell workflow run
  [`39576931985`](https://github.com/manansulya01/Aira-Octave/actions/runs/39576931985)
  passed at commit `3670ddfc0458816fdcfbb741b5de637a6af40aed`. It parsed 48
  shell scripts and passed the mocked rootfs atomic and release guard suites,
  including successful replacement of the old versioned release directory.
  The full kernel/QEMU run `39576932208` is separate and still in progress;
  core checks are not a substitute for the end-to-end boot.

## 2026-10-21 — End-to-end build failure and follow-up fixes
- Full workflow run
  [`39576932208`](https://github.com/manansulya01/Aira-Octave/actions/runs/39576932208)
  successfully compiled Linux 7.2.2 and built the initramfs, then failed in GUI
  staging. The uploaded log showed 154 available package names, two Ubuntu
  package-name fallbacks, and `PACKAGE_URL_COUNT=0`: `apt-get download
  --print-uris` was being treated as a URI-printing command even though the
  stage needs actual package archives.
- Branch commit `fb92cff1c637b162315534d5a0432ad1c1324395` changes GUI staging to
  download the resolved packages directly with `apt-get download`, then count
  and validate the resulting `.deb` files. This fix has not yet passed a
  complete clean-runner build.
- Package-manager audit found that partial rollback ignored `AIRA_PKG_ROOT`,
  backups could fail silently, a DB commit failure left payload changes behind,
  and stale-file removal ignored the configured root. Commits
  `862c5bf31aacbf44c0cf172f6eef8a3ef4a6ecb0` and
  `834085c6745d0f5a0403deafe23be67a7f59855b` address rollback paths, preserve
  recovery data on incomplete rollback, and use unique previous-DB names.
  Regression coverage is in `a2df79195a50e0c8d1060e5fe88eae41f7a7a605` and
  `692306e3d66677b0218efcd36f2f74c43b790adb`.
- The new BusyBox-shell CI check exposed malformed syntax in the in-guest
  installer after an earlier edit. Rather than leave a broken disk-writing
  script, commit `2b9a5ebcf04a63d426bb49bd0374a0da55af24ea` makes the live-image
  command fail closed and points users to the host-side installer. The host
  installer now verifies the release checksum manifest, target capacity, and
  BIOS GRUB modules before formatting (`9a6f9c341082122545c98f4dbeddf165128c2579`).
- Pull request #11 runs shell validation and package/update/installer safety
  regressions before merge. Its checks are still in progress; no install to a
  physical disk was performed.

- PR #11 merged as `80ef22aed613f888579c9a00b8b276dfc46cc98d` after its core CI
  passed at `f5669c5709fd6ea5796a827b974a58bf6d7a7dcd`. The run parsed 49 shell
  scripts, passed all selected initramfs `sh -n` checks, and passed rootfs/release
  atomicity, updater fail-closed, installer guard, guest-installer guard, and
  package transaction tests. Package suite result: `PASS=43 FAIL=0`, including
  injected partial-copy failure and restoration of the overwritten file.
- New full build run
  [`39579206079`](https://github.com/manansulya01/Aira-Octave/actions/runs/39579206079)
  is queued for the direct-APT GUI fix and merged safety changes. End-to-end
  release status remains unverified until this run reaches QEMU and ISO boot.

## 2026-10-21 — Clean-runner GUI dependency resolution
- Inspection of the current `scripts/build-gui.sh` found the download command
  used `$VALID_PKGS` without defining it. This would stop a clean runner at
  the GUI staging stage under `set -u`; this was a concrete defect, not a
  speculative roadmap item.
- Commit `63b34a268e8eb5fc57d0234a04fffcb75e46d858` adds a repository-aware
  package resolver before the download step, logs package-name fallbacks and
  unavailable manifest entries, and ensures the download command receives
  the resolved list.
- Follow-up source inspection confirms the resolver is present in the current
  file. It has not yet been validated by a successful Ubuntu runner or by
  building and booting the resulting desktop; the full CI run remains the
  required acceptance gate.

- GitHub Actions run `39591931672` (commit `63b34a268e8eb5fc57d0234a04fffcb75e46d858`)
  completed successfully for shell syntax checks and mocked build-safety
  regressions, including core initramfs entrypoints. This is verified CI
  evidence; it does not replace QEMU boot testing.
- Full build/QEMU run `39591931946` for the same source was observed progressing
  through dependency installation and into the Linux 7.2.2 kernel build. Its
  final result has not yet been confirmed.
- Architecture documentation was corrected in commit
  `a3d7130c6256d5f7af411558df514869414facb0` to distinguish the implemented
  host-side BIOS/MBR installer from the deliberately disabled in-guest
  installer and remote OS updater. This prevents documentation from claiming
  end-to-end update/install features that are not yet implemented.

- Updated `docs/architecture/AIRAOS-COMPLETE-CAPABILITY-MATRIX.md` in commit
  `5a7c9c4af715898534e7a2ec79d04cea03b94880` to mark the GRUB/ISO path and
  safe-mode tests as present, and to distinguish the host-side BIOS installer
  from the blocked in-guest installer and the unimplemented signed OS updater.
  The matrix explicitly warns that historical evidence is not a fresh run of
  the current full-build workflow.

## 2026-10-21 — Clean-runner QEMU exposed two desktop integration defects
- Full build run `39591931946` verified the Linux 7.2.2 kernel build, initramfs
  build, desktop package staging, rootfs image creation, static userspace checks,
  and the baseline kernel/userspace boot. It then failed in GUI QEMU validation.
- The captured guest log identified:
  1. Xvfb could not execute `/usr/bin/xkbcomp` because the desktop lives under
     `/persist`, while Xorg/Xvfb resolve XKB tools/data using absolute paths
     in the initramfs root.
  2. JWM could not load `libicuuc.so.74`; the manual GUI runtime package list
     omitted the ICU package required by the Ubuntu Noble JWM binary.
  3. The guest autotest invoked `aira-help doctor` after its deliberate service
     shutdown check but before restoring the IPC daemon, so the test failed on
     service state rather than the help/doctor command integration.
- Fixes committed to `main`:
  - `9a8a320d14e7aa3d831ecebfae02586816987394`: add ICU package resolution
    (with version-name fallbacks) to GUI staging.
  - `b31b7ac6da1eedce8ba070b38cd8afa5e9484591`: expose the mounted persistent
    XKB compiler and X11 data directory at the absolute paths used by Xorg/Xvfb.
  - `8ff81b9a30ed6c2e409cfc1ed254cd94eb42d989`: restart and probe IPC before
    the help-doctor integration test after the intentional shutdown test.
  - `95f49a60aa128fd16908470be80c082ccadb0011`: fail GUI staging early if
    `xkbcomp` or an ICU runtime library is absent, instead of deferring this
    dependency error until boot.
- The previous run's kernel and base userspace boot passed; the GUI gate failed,
  so networking, persistence, recovery, release creation, and ISO boot were
  correctly skipped. The next full workflow run must prove these fixes before
  any release claim is made.

## 2026-10-21 — Service manager guardrails (PR #13)
- Reject unsafe service names before they can influence service/config, enabled
  state, PID, diagnostic, or log paths. The logs verb now rejects traversal
  instead of allowing a caller to read files outside the service log directory.
- Validate resource limit, NICE, and UMASK settings before command execution.
  Resource-limit commands are now emitted for the child shell (the previous
  command-substitution approach changed limits only in a subshell and did not
  constrain the service process).
- Added a sandbox-only regression for path traversal, valid service operations,
  CPU/file/umask limits, nice level, and malformed limit values. All service
  state is redirected to a temporary test directory.
- Core shell CI passed on the preceding service-manager commit. The latest
  expanded resource-limit/nice test is awaiting its own CI run; merge only after
  it passes and the current main full-build gate is complete.
