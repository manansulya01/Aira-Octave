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
if [ "$PASS" = "1" ]; then echo "===== FILEOPS PASS ====="; else echo "===== FILEOPS FAIL ====="; fi
sync
poweroff -f 2>/dev/null || reboot -f 2>/dev/null || echo halt
sleep 5
