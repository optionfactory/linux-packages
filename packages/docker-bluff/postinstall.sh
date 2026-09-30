#!/bin/sh
set -e
getent group docker >/dev/null 2>&1 || groupadd --system docker
chown root:docker /usr/bin/docker-bluff
chmod 0750 /usr/bin/docker-bluff
setcap cap_sys_admin,cap_setuid,cap_setgid,cap_setfcap,cap_sys_ptrace+ep /usr/bin/docker-bluff
# tmpfiles.d recreates it at boot; create it now too.
systemd-tmpfiles --create /usr/lib/tmpfiles.d/docker-bluff.conf >/dev/null 2>&1 \
    || install -d -m 0770 -o root -g docker /run/docker-bluff
