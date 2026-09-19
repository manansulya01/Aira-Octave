# Security Report — AiraOS-Octave 1.1.0

## Bugs found by real testing (all fixed, all re-tested)

### S1. DHCP lease obtained but never applied (REAL BUG, Part 1 network)
- Symptom: `eth0` UP, link up, but NO IPv4 address, NO route (mission §2).
- Root cause (proven): `udhcpc` defaults to `/usr/share/udhcpc/default.script`
  to configure the interface; initramfs shipped NO such script, so the lease
  (10.0.2.15 from 10.0.2.2) was obtained then discarded.
- Fix: new `initramfs/usr/share/udhcpc/default.script` (+ `/etc/udhcpc` copy):
  applies IP/prefix (mask→prefix), default route, `/etc/resolv.conf` on
  bound/renew; flushes on deconfig. `aira-net-setup` and `aira network dhcp`
  now pass `-s <script>`. Same fix applied to `aira-netman` / `aira-settings`
  DHCP actions.
- Test: user-net boot → `inet 10.0.2.15/24`, `default via 10.0.2.2`,
  `nameserver 10.0.2.3`; `aira network dhcp eth0` RC=0 with lease. VERIFIED.

### S2. airapkg made EVERY installed file executable (REAL BUG)
- Root cause: `chmod +x "$dest"` unconditionally after copy.
- Fix: `cp -p` (busybox supports it; `chmod --reference` does NOT exist in
  busybox) + repair heuristic (exec stays exec, data stays non-exec).
- Test: 755 script → 755, 600 config → 600 in guest. VERIFIED.

### S3. airapkg sourced PKGINFO → arbitrary code execution (REAL BUG)
- Root cause: `. "$tmp/PKGINFO"` (install, twice) and `. "$d/PKGINFO"`
  (update-check) execute package-supplied shell code. A crafted PKGINFO with
  `EVIL=$(touch ...)` runs at install/query time.
- Fix: parse-only extraction via `sed -n 's/^NAME=".../...'` for
  NAME/VERSION/DEPS everywhere; NAME/VERSION token validation (reject
  `/`, spaces, shell metachars).
- Test: code-exec canary package installs WITHOUT creating the canary file;
  bad NAME (`../../evil`) rejected; malformed PKGINFO rejected without shell
  error leakage. VERIFIED (sandboxed full-install harness on host).

### S4. airapkg installed its own temp file to `/list.txt` (REAL BUG)
- Root cause: `find` payload list excluded PKGINFO/members.txt but not the
  `list.txt` it was writing to → installed to `/` and recorded in DB.
- Fix: exclude `list.txt` in both find and install loop. VERIFIED (sandbox
  root clean).

### S5. Upgrade left stale files behind (REAL BUG, reinstall semantics)
- Defined semantics: upgrade = new payload wins; files in old version but
  absent from new version are removed (with `airapkg rollback` available for
  overwritten-file recovery).
- Fix: save old `files` list before DB commit; delete old-only paths after.
- Test: V1 {A,B,C} → V2 {A,C} prints `removed stale B`, B gone, A/C updated.
  VERIFIED in guest.

## Malicious-package matrix (crafted with python tarfile, full-install harness)

| package | content | result |
|---|---|---|
| abs | `/etc/evil` member | REJECTED (absolute path) |
| trav | `../evil` | REJECTED (traversal) |
| nested | `a/../../evil` | REJECTED (traversal) |
| dotdot | `..` component dir | REJECTED |
| link | symlink → /etc/passwd | REJECTED |
| hard | hardlink → /etc/passwd | REJECTED |
| corrupt | non-tar bytes | REJECTED |
| nopkginfo | no PKGINFO | REJECTED |
| badinfo | malformed PKGINFO | REJECTED (bad NAME) |
| badname | NAME=`../../evil` | REJECTED |
| codeexec | PKGINFO w/ command subst | NEUTRALIZED (ignored, canary untouched) |
| dup | duplicate `f.txt` entries | ACCEPTED (last wins; harmless, documented) |

Host `/etc/evil` untouched in all runs. In-guest autotest also covers
invalid/corrupt/traversal/symlink rejection. VERIFIED.

## Atomicity (mid-install failure, in guest)
- Package {bin/good.txt + proc/cannot}: `cp: can't create '/proc/cannot'`,
  `install failed, rolling back partial`, RC=1; partial file removed;
  pre-existing files untouched; package absent from DB; no staging dirs left.
  VERIFIED. (Crash-during-copy, e.g. power loss, still relies on this same
  rollback on next install — noted in KNOWN_LIMITATIONS.)

## Other hardening (verified, pre-existing from 49b77759f, re-tested)
- Service manager: no stale-PID-as-running (oneshots use .done/.failed);
  single syslogd/klogd instance (dep-clobber bug fixed); crash→failed,
  restart recovery, ordered shutdown. VERIFIED in autotest.
- Permissions: `/root` 700, aira cannot write /root, can write own home,
  no setuid/setgid in system paths, no TCP listeners by default. VERIFIED.
- `/init` hotplug-helper write REMOVED (obsolete; devtmpfs+mdev is correct):
  zero occurrences in 10-boot matrix. VERIFIED.
