#!/bin/sh
set -e
[ -d /run/systemd/system ] && systemctl daemon-reload || true
# the token and the reports not sent yet: kept on remove, gone on purge (a new token needs a new approval)
[ "$1" = purge ] && rm -rf /var/lib/optionfactory-posture || true
