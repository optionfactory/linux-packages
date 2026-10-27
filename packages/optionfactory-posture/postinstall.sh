#!/bin/sh
set -e
# containers and chroots have no systemd running
[ -d /run/systemd/system ] || exit 0
systemctl daemon-reload
systemctl enable --now optionfactory-posture.timer
