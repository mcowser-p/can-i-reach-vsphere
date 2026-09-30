#!/usr/bin/env bash
# Runs the can-i-reach suite against localhost and records the verdict in
# three places: the log, an exit-code file (read by can-i-reach-wait over
# SSH), and guestinfo (readable from vCenter with govc when SSH is not an
# option). Always exits 0 so cloud-init itself stays healthy — the
# verdict is the exit-code file, not this script's status.
set -uo pipefail
# shellcheck disable=SC1091
. /etc/can-i-reach/env

mkdir -p "$STATE_DIR" "$(dirname "$REPORT_PATH")"
rm -f "$STATE_DIR/exit-code"

if [ -x "$VENV/bin/ansible-playbook" ]; then
  PLAYBOOK_BIN="$VENV/bin/ansible-playbook"
else
  PLAYBOOK_BIN="$(command -v ansible-playbook || true)"
fi
if [ -z "$PLAYBOOK_BIN" ]; then
  echo "ansible-playbook not found (install_tooling=false but the template is not pre-baked?)" | tee "$LOG"
  echo 127 > "$STATE_DIR/exit-code"
  exit 0
fi
if [ -d "$COLLECTIONS" ]; then
  export ANSIBLE_COLLECTIONS_PATH="$COLLECTIONS"
fi
export ANSIBLE_NOCOLOR=1

"$PLAYBOOK_BIN" -i localhost, -c local "$PLAYBOOK" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
echo "$rc" > "$STATE_DIR/exit-code"

verdict=ok
[ "$rc" -eq 0 ] || verdict=fail
if command -v vmware-rpctool >/dev/null 2>&1; then
  vmware-rpctool "info-set guestinfo.can_i_reach.verdict $verdict" || true
  vmware-rpctool "info-set guestinfo.can_i_reach.exit_code $rc" || true
  if [ -f "$REPORT_PATH" ]; then
    vmware-rpctool "info-set guestinfo.can_i_reach.report $(base64 -w0 "$REPORT_PATH")" || true
  fi
fi
echo "can-i-reach: verdict=$verdict exit_code=$rc"
exit 0
