#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib.sh"

print_step "Starting the dedicated Podman machine"
ensure_machine

print_step "Starting the OpenClaw gateway service inside the machine"
run_remote_sh "openclaw gateway start"

print_step "Current gateway status"
run_remote_sh "openclaw gateway status"
