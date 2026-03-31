#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib.sh"

ensure_machine_started

readarray -t ssh_info < <(
  python3 - "$OPENCLAW_DEMO_MACHINE" <<'PY'
import json
import subprocess
import sys

name = sys.argv[1]
raw = subprocess.check_output(["podman", "machine", "inspect", name], text=True)
data = json.loads(raw)[0]
ssh = data["SSHConfig"]
print(ssh["RemoteUsername"])
print(str(ssh["Port"]))
print(ssh["IdentityPath"])
PY
)

remote_user="${ssh_info[0]}"
remote_port="${ssh_info[1]}"
identity_path="${ssh_info[2]}"

ssh_base=(
  ssh
  -i "$identity_path"
  -p "$remote_port"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  "${remote_user}@localhost"
)

print_step "Waiting for direct SSH access to the Podman machine"
for attempt in $(seq 1 30); do
  if "${ssh_base[@]}" true >/dev/null 2>&1; then
    if [[ "$#" -eq 0 ]]; then
      printf '+'
      for arg in "${ssh_base[@]}"; do
        printf ' %q' "$arg"
      done
      printf '\n'
      exec "${ssh_base[@]}"
    fi

    printf '+'
    for arg in "${ssh_base[@]}" "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
    exec "${ssh_base[@]}" "$@"
  fi
  sleep 2
done

echo "Timed out waiting for direct SSH to ${OPENCLAW_DEMO_MACHINE} on localhost:${remote_port}" >&2
exit 1
