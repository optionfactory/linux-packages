#!/bin/sh
set -e
case "$1" in
    remove|purge)
        [ -d /run/systemd/system ] && systemctl disable --now optionfactory-posture.timer || true
        ;;
esac
