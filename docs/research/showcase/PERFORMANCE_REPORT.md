# Performance Report — AiraOS-Octave 1.1.0 (QEMU TCG, host-shared CPU)

| metric | value | method |
|---|---|---|
| kernel → userspace ready | ~3.5 s | serial log, kernel t=0 to `AiraOS userspace ready` (512M) |
| desktop startup (Xvfb+jwm) | 1.69 s real | `time aira-session --headless --display :99` in guest (1G) |
| idle RAM | 16 MB used / 477 MB total | `free` on 512M guest at shell idle |
| idle CPU | load 0.00 | `/proc/loadavg` at idle |
| app startup (sysinfo) | 0.05 s | `time aira-sysinfo` |
| app startup (netman --once) | 0.02 s | `time aira-netman --once` |
| app startup (sysmon --once) | 0.05 s | `time aira-sysmon --once` |

No blind optimization performed. Numbers are TCG-virtualized; physical
hardware will differ. Full logs: `/tmp/opencode/perf*.log`.
