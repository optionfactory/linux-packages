#!/bin/sh
set -e
getent group docker >/dev/null 2>&1 || groupadd --system docker
chown root:docker /usr/bin/docker-intrude
chmod 0750 /usr/bin/docker-intrude
setcap cap_sys_admin,cap_sys_ptrace,cap_setpcap+ep /usr/bin/docker-intrude
