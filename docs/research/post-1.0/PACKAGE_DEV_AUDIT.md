# Post-1.0 Package + Developer Audit

## airapkg deep inspection (source: initramfs/usr/bin/airapkg)
- Format: tar.gz + PKGINFO (NAME/VERSION/DESC/DEPS). Tested: YES.
- Metadata/query/search/info: tested YES (repo fallback included).
- Install/remove/verify: tested YES. Upgrade path: reinstall --force (tested
  implicitly by rollback test's v1→v2 install).
- Rollback: restores overwritten files from DB backup, deletes added files.
  Tested YES (v2→v1 content assert). LIMIT: DB is in RAM — rollback state does
  not survive reboot; remove-then-reinstall loses backup. Documented, not hidden.
- Corruption: tar-extract gate rejects garbage (tested). Truncated-valid-tar:
  UNTESTED edge (tar may partially extract; installer has no checksum gate).
- Dependencies: warn-only, no resolution/order enforcement. Tested (warning).
- Versions: string compare only; no constraint solver. Adequate for local scope.
- Repository: directory of .apkg; update-check compares versions. Tested.
- Signatures/trust: NONE. Remote-ready requires: manifest hashes (sha256 per
  file), signature verify, atomic install, repo index signing. All absent —
  remote repos must stay UNSUPPORTED until then.
- Atomicity: NOT atomic (file-by-file cp; interrupted install = partial state
  + partial DB). Recovery: manual remove+reinstall. Classified as tech debt.
- State: /var/lib/airapkg (RAM). Survives nothing. By design for v1 scope.

## Developer workflow CREATE→REMOVE (evidence)
- CREATE/EDIT: vi in guest (present), samples/hello-aira.c in repo. YES.
- COMPILE: host gcc only (proven: sample binary runs on host AND guest).
  Guest compiler/headers: ABSENT. Third-party dev requires host cross workflow.
- RUN: guest glibc+loader (proven exact-output). YES.
- DEBUG: no gdb/strace in guest; dmesg+logs only. Gap documented.
- PACKAGE/INSTALL/EXECUTE/REMOVE: proven via repo flow. YES.
- Git: host-only. IPC: pipes+TCP proven; Unix-sockets untested.
- SDK structure: samples/ + DEVELOPER_GUIDE.md (accurate, states cross-dev).

## Missing for third-party developers
Guest gcc/headers/make, git, debugger, SDK sysroot packaging, app icon format
docs, login-based multi-user sessions. Recommended as 2.x generation scope.
