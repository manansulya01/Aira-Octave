# AiraOS Package Management (airapkg 0.2)

Local-only repository. No internet repos exist; do not pretend otherwise.

## Format
`.apkg` = gzipped tar containing `PKGINFO` (NAME, VERSION, DESC, DEPS space-separated)
plus payload files at absolute-equivalent relative paths.

## Commands
- `airapkg list` — installed
- `airapkg search TERM` — installed + `/var/lib/airapkg/repo/*.apkg` matches
- `airapkg query|info NAME` — installed metadata+files, else repo metadata
- `airapkg install [--force] FILE` — refuses present unless --force; warns on missing DEPS
- `airapkg remove NAME` — deletes recorded files + DB entry
- `airapkg verify NAME` — checks recorded files exist
- `airapkg update-check` — installed VERSION vs repo VERSION
- `airapkg build DIR OUT` — DIR must contain PKGINFO

## Repo workflow
1. `mkdir -p pkg/usr/share/aira && printf 'NAME="x"\nVERSION="1.0"\nDESC="d"\nDEPS=""\n' > pkg/PKGINFO`
2. `airapkg build pkg x-1.0.apkg`
3. `cp x-1.0.apkg /var/lib/airapkg/repo/`
4. `airapkg search x`, `airapkg install /var/lib/airapkg/repo/x-1.0.apkg`

## GUI
Package Center (`aira-pkgcenter`): xterm menu over airapkg (search/info/install/remove/update-check).

## Tested
Guest autotest covers build/search/info/update-check/install/verify/remove + invalid-file rejection.
