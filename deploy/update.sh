#!/bin/bash
#
# Apply the current checkout: reload the systemd units and restart the timer.
#
# Called by r2lab-embedded/services/run-updates.sh after it has moved this
# repo to the latest origin commit; can also be run by hand to force a redeploy.
# The git update itself is NOT done here, since resetting a repo under a
# running script is unsafe.
#
# The units are symlinked by hand into /etc/systemd/system, this script does
# not install them. The service is oneshot and run from the timer, so it just
# picks up the new code next time; only the timer is restarted, and only if
# it is installed AND enabled, so that this also works on hosts that do not
# run it.
#

set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."

systemctl daemon-reload

UNIT=backup-faraday-images.timer

if systemctl is-enabled --quiet "$UNIT"; then
    systemctl restart "$UNIT"
else
    echo "update.sh: skipping $UNIT (not installed or not enabled)"
fi
