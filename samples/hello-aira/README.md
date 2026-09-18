# hello-aira sample application

Proves the AiraOS-Octave developer workflow end to end:

1. Write C (libc only): `hello-aira.c`
2. Build on the host: `make` (or `scripts/build-samples.sh`)
3. Package: payload staged under `pkg/` with `PKGINFO`, built to
   `hello-aira-1.0.apkg` via `airapkg build`
4. Ship: .apkg copied into the rootfs local repo
   (`rootfs/var/lib/airapkg/repo/`)
5. Install in the guest: `airapkg install /var/lib/airapkg/repo/hello-aira-1.0.apkg`
6. Run: `/usr/share/aira-samples/hello-aira`
   (guest glibc + /lib64 loader symlink resolve it)
7. Remove: `airapkg remove hello-aira`

Guest test coverage: install → exact-output execution → remove
(see guest-autotest.sh "sample app" section).
