#!/bin/sh
# dpkg passes remove/purge, rpm passes 0 on erase; upgrades pass something else.
case "$1" in
    remove|purge|0)
        # Never rm -rf: idmapped mounts of host directories may live under it.
        rmdir /run/docker-bluff 2>/dev/null || true
        ;;
esac
