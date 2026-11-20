#!/usr/bin/env bash
# Installed root-owned at /usr/local/bin/jant-test-ssh. The deployment key's
# authorized_keys forced command invokes this entry point with no shell access.
set -euo pipefail

image="${SSH_ORIGINAL_COMMAND:-}"
if [[ ! "$image" =~ ^ccr\.ccs\.tencentyun\.com/chenyahui/jant-my-release@sha256:[a-f0-9]{64}$ ]]; then
  echo "Only a published Jant my-release image digest is accepted." >&2
  exit 1
fi

exec sudo -n /usr/local/sbin/jant-test-deploy "$image"
