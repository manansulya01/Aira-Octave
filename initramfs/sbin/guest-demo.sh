#!/bin/sh
# Boot-time demo mode (aira_demo=1 on cmdline): tour, then interactive shell.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root TERM=linux
/usr/bin/aira-demo 2>&1
echo
echo "Demo complete — dropping to AiraOS shell. Type 'aira help'."
exec /bin/sh
