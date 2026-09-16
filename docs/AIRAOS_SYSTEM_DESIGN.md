# AiraOS-Octave System Design

## Identity
- OS: AiraOS-Octave 0.1.0 (`/etc/os-release`), host `aira-octave`.
- Users: root (0) + aira (1000, /home/aira). Groups in /etc/group. DAC enforced (tested: aira denied /root, allowed own home).
- Layout: /bin /sbin /usr/bin /etc /dev /proc /sys /tmp /run /var/log/airaos /persist /home.
- Services: /etc/aira/services/*.conf (CMD/DEPS/DESC), supervised by aira-init, logs per-service.
- Packages: .apkg (tar.gz + PKGINFO NAME/VERSION/DESC/DEPS), airapkg list/query/install/remove/verify/build.
- Logging: /var/log/airaos/{boot,dmesg-boot,services,syslog}.
- GUI: JWM + Aira menu (Terminal/File/Settings/Sysinfo/About), wallpaper #1d2a6b, tray clock.
- Updates: rebuild + retest + reinstall (no self-modifying updater in v1).
