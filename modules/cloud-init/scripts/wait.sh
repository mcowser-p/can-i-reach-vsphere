#!/usr/bin/env bash
# Called by the remote-exec step: wait for the boot-time run to finish,
# replay its log into the apply output, exit with the suite's exit code.
set -uo pipefail
# shellcheck disable=SC1091
. /etc/can-i-reach/env

deadline=$(( $(date +%s) + ${1:-1200} ))
cloud-init status --wait >/dev/null 2>&1 || true
while [ ! -f "$STATE_DIR/exit-code" ]; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "timed out waiting for the boot-time can-i-reach run"
    [ -f "$LOG" ] && tail -n 50 "$LOG"
    exit 124
  fi
  sleep 5
done

cat "$LOG"
rc=$(cat "$STATE_DIR/exit-code")
echo "can-i-reach exit code: $rc"
exit "$rc"
