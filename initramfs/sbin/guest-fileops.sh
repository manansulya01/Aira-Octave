#!/bin/sh
# In-guest file-operation verification (runs as init when aira_fileops=1 is
# on the kernel cmdline). Exercises the exact operations the AiraOS File
# Manager (mc) performs on behalf of the user: browse, mkdir, create, rename,
# copy, move, delete — in both /root and /home/aira. Prints FILEOPS markers
# to serial, then poweroff. Never hangs.
export PATH=/persist/usr/bin:/persist/bin:/persist/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/persist/usr/lib/x86_64-linux-gnu:/persist/lib/x86_64-linux-gnu:/persist/usr/lib:/persist/lib:$LD_LIBRARY_PATH
PASS=1
echo "===== FILEOPS START ====="
T1=/root/aira-fileops-test
T2=/home/aira/aira-fileops-test
rm -rf "$T1" "$T2" 2>/dev/null
mkdir -p "$T1/sub" "$T2" 2>/dev/null || { echo "FILEOPS FAIL: mkdir"; PASS=0; }
echo "hello aira" > "$T1/sub/note.txt" 2>/dev/null || { echo "FILEOPS FAIL: create"; PASS=0; }
ls -lR "$T1" 2>/dev/null | head -n 8
[ "$(cat "$T1/sub/note.txt" 2>/dev/null)" = "hello aira" ] && echo "FILEOPS OK: create+read" || { echo "FILEOPS FAIL: readback"; PASS=0; }
mv "$T1/sub/note.txt" "$T1/sub/renamed.txt" 2>/dev/null && [ -f "$T1/sub/renamed.txt" ] && echo "FILEOPS OK: rename" || { echo "FILEOPS FAIL: rename"; PASS=0; }
cp "$T1/sub/renamed.txt" "$T1/copy.txt" 2>/dev/null && [ -f "$T1/copy.txt" ] && echo "FILEOPS OK: copy" || { echo "FILEOPS FAIL: copy"; PASS=0; }
mv "$T1/copy.txt" "$T2/moved.txt" 2>/dev/null && [ -f "$T2/moved.txt" ] && echo "FILEOPS OK: move across dirs" || { echo "FILEOPS FAIL: move"; PASS=0; }
rm -f "$T2/moved.txt" 2>/dev/null; [ ! -e "$T2/moved.txt" ] && echo "FILEOPS OK: delete file" || { echo "FILEOPS FAIL: delete"; PASS=0; }
rm -rf "$T1" "$T2" 2>/dev/null; [ ! -e "$T1" ] && [ ! -e "$T2" ] && echo "FILEOPS OK: delete tree" || { echo "FILEOPS FAIL: rmdir"; PASS=0; }
command -v mc >/dev/null 2>&1 && echo "FILEOPS OK: mc backend present ($(mc --version 2>/dev/null | head -n1))" || { echo "FILEOPS FAIL: mc missing"; PASS=0; }
echo "--- IPC files service (C1) ---"
T3=/root/aira-fileops-ipc
rm -rf "$T3" 2>/dev/null
if command -v aira-files >/dev/null 2>&1; then
  echo "FILEOPS OK: aira-files CLI present"
else
  echo "FILEOPS FAIL: aira-files CLI missing"; PASS=0
fi
if command -v aira-ipc >/dev/null 2>&1 && aira-ipc ping >/dev/null 2>&1; then
  echo "FILEOPS INFO: bus reachable (bus path exercised)"
  _BUS=1
else
  echo "FILEOPS INFO: bus unreachable (local handler path exercised)"
  _BUS=0
fi
aira-files mkdir "$T3" >/dev/null 2>&1 && [ -d "$T3" ] && echo "FILEOPS OK: files mkdir" || { echo "FILEOPS FAIL: files mkdir"; PASS=0; }
echo "ipc-data" > "$T3/note.txt" 2>/dev/null || { echo "FILEOPS FAIL: files seed"; PASS=0; }
aira-files list "$T3" 2>/dev/null | grep -q "note.txt" && echo "FILEOPS OK: files list" || { echo "FILEOPS FAIL: files list"; PASS=0; }
aira-files stat "$T3/note.txt" 2>/dev/null | grep -q "file" && echo "FILEOPS OK: files stat" || { echo "FILEOPS FAIL: files stat"; PASS=0; }
aira-files rename "$T3/note.txt" "$T3/renamed.txt" >/dev/null 2>&1 && [ -f "$T3/renamed.txt" ] && echo "FILEOPS OK: files rename" || { echo "FILEOPS FAIL: files rename"; PASS=0; }
aira-files copy "$T3/renamed.txt" "$T3/copy.txt" >/dev/null 2>&1 && [ -f "$T3/copy.txt" ] && echo "FILEOPS OK: files copy" || { echo "FILEOPS FAIL: files copy"; PASS=0; }
aira-files move "$T3/copy.txt" "$T3/moved.txt" >/dev/null 2>&1 && [ -f "$T3/moved.txt" ] && [ ! -e "$T3/copy.txt" ] && echo "FILEOPS OK: files move" || { echo "FILEOPS FAIL: files move"; PASS=0; }
aira-files delete "$T3/moved.txt" >/dev/null 2>&1 && [ ! -e "$T3/moved.txt" ] && echo "FILEOPS OK: files delete" || { echo "FILEOPS FAIL: files delete"; PASS=0; }
echo "x" > "$T3/keep.txt" 2>/dev/null
if aira-files delete "$T3" >/dev/null 2>&1; then echo "FILEOPS FAIL: non-empty dir deleted"; PASS=0;
else echo "FILEOPS OK: non-empty dir refused"; fi
rm -f "$T3/keep.txt" "$T3/renamed.txt" 2>/dev/null
aira-files delete "$T3" >/dev/null 2>&1 && [ ! -e "$T3" ] && echo "FILEOPS OK: files rmdir" || { echo "FILEOPS FAIL: files rmdir"; PASS=0; }
echo "--- files attacks (must all fail) ---"
if aira-files list "/root/../etc" >/dev/null 2>&1; then echo "FILEOPS FAIL: traversal accepted"; PASS=0;
else echo "FILEOPS OK: traversal rejected"; fi
if aira-files stat "/root/%2e%2e/etc/passwd" >/dev/null 2>&1; then echo "FILEOPS FAIL: encoded traversal accepted"; PASS=0;
else echo "FILEOPS OK: encoded traversal rejected"; fi
if aira-files stat "/run/aira-ipc/root.token" >/dev/null 2>&1; then echo "FILEOPS FAIL: token readable via files"; PASS=0;
else echo "FILEOPS OK: token denied"; fi
if aira-files mkdir "/sbin/aira-fileops-evil" >/dev/null 2>&1; then echo "FILEOPS FAIL: escape from writable roots"; PASS=0; rm -rf /sbin/aira-fileops-evil 2>/dev/null;
else echo "FILEOPS OK: writable roots enforced"; fi
if [ "$_BUS" = "1" ]; then
  if aira-ipc call files list "/root/../etc" >/dev/null 2>&1; then echo "FILEOPS FAIL: bus traversal accepted"; PASS=0;
  else echo "FILEOPS OK: bus traversal rejected"; fi
  if su aira -c 'aira-ipc call files mkdir /root/aira-fileops-unpriv' >/dev/null 2>&1; then echo "FILEOPS FAIL: unprivileged write allowed"; PASS=0;
  else echo "FILEOPS OK: unprivileged write denied"; fi
  rm -rf /root/aira-fileops-unpriv 2>/dev/null
else
  echo "FILEOPS INFO: bus attack probes skipped (no bus)"
fi
rm -rf "$T3" 2>/dev/null
if [ "$PASS" = "1" ]; then echo "===== FILEOPS PASS ====="; else echo "===== FILEOPS FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5
