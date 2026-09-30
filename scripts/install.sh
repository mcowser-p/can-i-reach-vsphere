#!/usr/bin/env bash
# First-boot tooling for the can-i-reach preflight VM: python3 + venv +
# git from the distro, ansible-core from PyPI (or a mirror), and the
# collection from Galaxy/git. Skip it (install_tooling=false) when the
# template is pre-baked — the VLAN under test may have no egress at all.
set -euo pipefail
# shellcheck disable=SC1091
. /etc/can-i-reach/env

log() { echo "[can-i-reach-install] $*"; }

# apt/dnf, pip and git all honour the proxy environment; nothing else
# on the guest is reconfigured.
if [ -n "${PROXY_URL:-}" ]; then
  log "tooling via proxy $(sed -E 's#//[^@]*@#//***@#' <<<"$PROXY_URL")"
  export http_proxy="$PROXY_URL" https_proxy="$PROXY_URL"
  export HTTP_PROXY="$PROXY_URL" HTTPS_PROXY="$PROXY_URL"
  export no_proxy="${NO_PROXY_LIST:-}" NO_PROXY="${NO_PROXY_LIST:-}"
fi

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  log "apt: python3 python3-venv git"
  apt-get update -q
  apt-get install -y -q --no-install-recommends python3 python3-venv git
elif command -v dnf >/dev/null 2>&1; then
  log "dnf: python3 git"
  dnf install -y -q python3 git
elif command -v yum >/dev/null 2>&1; then
  log "yum: python3 git"
  yum install -y -q python3 git
else
  log "no supported package manager; assuming python3 and git are present"
fi

log "venv at $VENV"
python3 -m venv "$VENV"
PIP_ARGS=()
if [ -n "${PIP_INDEX_URL:-}" ]; then
  PIP_ARGS+=(--index-url "$PIP_INDEX_URL")
fi
"$VENV/bin/pip" install -q --upgrade ${PIP_ARGS[@]+"${PIP_ARGS[@]}"} pip
"$VENV/bin/pip" install -q ${PIP_ARGS[@]+"${PIP_ARGS[@]}"} "ansible-core==$ANSIBLE_CORE_VERSION"

log "collection: $COLLECTION_SOURCE"
mkdir -p "$COLLECTIONS"
"$VENV/bin/ansible-galaxy" collection install -p "$COLLECTIONS" "$COLLECTION_SOURCE"
log "done"
