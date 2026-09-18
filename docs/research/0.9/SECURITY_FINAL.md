# 0.9 Security Final Audit

Extends docs/research/0.4/SECURITY_AUDIT.md with 0.5–0.9 changes. All checks
guest-executed (see services-*.log security sections).

## Privileged processes
- PID1 /init (root, required), kthreadd/kworkers (kernel), syslogd/klogd (root,
  justified: kernel-log access), udhcpc client (root, justified: interface config),
  Xvfb/JWM/apps (root in headless test — residual risk, documented).
- USER= mechanism proven: non-root service files owned by UID 1000.

## Files
- /root 700 enforced by /init (asserted). /home/aira 1000:1000 (asserted).
- No setuid/setgid in /bin /sbin /usr/bin (scanned each autotest).
- Service defs root-owned in initramfs (read-only ramfs at runtime).

## Package installation
- airapkg writes only recorded paths; rollback restores overwritten files.
- Corrupt/truncated archives rejected (tar-extract gate tested).
- No signatures (local-only repo by design — documented in PACKAGE_MANAGEMENT.md).

## Network exposure
- No TCP listeners by default (scanned). Outbound DHCP/DNS client only.

## Desktop applications
- Apps are separate processes; killing any app leaves JWM alive (tested).
- xterm shell runs with invoker privileges (root in test) — user-session
  separation remains future work (see 1.0 limitations).

## Residual risks (accepted, documented)
Root desktop/services, no login/firewall/encryption/secure-boot. Suitable for
trusted demo/QEMU use; not yet a multi-user hardened endpoint.
