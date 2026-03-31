#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib.sh"

print_step "Ensuring the dedicated Podman machine is up"
ensure_machine

print_step "OpenClaw version in the machine"
run_remote_sh "openclaw --version"

print_step "Gateway status"
run_remote_sh "openclaw gateway status"

print_step "OpenClaw doctor"
run_remote_sh "openclaw doctor --non-interactive"
