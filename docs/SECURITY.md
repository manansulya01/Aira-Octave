# Security posture and known limitations

This document describes the current AiraOS-Octave implementation. A passing
QEMU test suite is not a security certification and does not establish safety
on arbitrary physical hardware.

## Verified controls

- Separate `root` and `aira` accounts exist; `aira` uses UID/GID 1000.
- Guest permission tests verify that `aira` cannot write to `/root` and can
  write to its own home.
- Desktop window management and GUI applications run as unprivileged `aira`.
- Init assigns restrictive ownership/modes to `/etc/shadow` and
  `/etc/gshadow`.
- The initramfs is checked for unexpected setuid binaries.
- Audio device nodes are assigned to `root:audio` mode `0660`; `aira` is
  a member of the audio group.
- Normal boot does not intentionally start remote login daemons or an inbound
  web server; network configuration uses a DHCP client.
- Safe mode skips persistent-disk mounting and normal service/desktop startup,
  leaving a serial recovery shell.

## Release-blocking security gaps

- **No interactive authenticated login is enabled.** The shipped root and
  aira shadow entries are locked. Normal boot currently provides a root serial
  recovery shell, not a secure multi-user login flow.
- **Password authentication is not end-to-end verified.** The account tool
  writes a project-specific password hash format, but a complete login
  verifier and boot-to-login test have not been demonstrated. Setting a
  password is not proof that login is secure or functional.
- **No firewall policy is shipped.** Network exposure has not been validated
  against a hostile network.
- **No signed update chain is available.** Package/update authenticity and
  rollback protection are not equivalent to a trusted signed OS update system.
- **No Secure Boot integration or full-disk encryption is provided.**
- **Physical hardware behavior is not certified.** QEMU does not prove laptop
  firmware, Wi-Fi, GPU, audio, suspend/resume, or storage behavior.
- The service supervisor still runs core services with elevated privileges;
  least-privilege review remains necessary.

## Daily-use status

AiraOS-Octave is experimental and is not currently recommended as a primary
or security-sensitive daily-use operating system. Keep important data backed
up and test only in a disposable VM until authenticated login, firewall
defaults, trusted updates, installation/recovery, and target hardware support
have been verified.
