#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib.sh"

print_step "Bootstrapping the dedicated Podman machine"
ensure_machine
ensure_repo_visible_in_vm

print_step "Installing OpenClaw inside the Podman machine"
ensure_remote_openclaw_installed

if [[ "${OPENCLAW_DEMO_SKIP_ONBOARD:-0}" == "1" ]]; then
  print_step "Skipping onboarding because OPENCLAW_DEMO_SKIP_ONBOARD=1"
  exit 0
fi

print_step "Running official OpenClaw onboarding inside the Podman machine"
run_remote_onboard

print_step "Gateway status after setup"
run_remote_sh "openclaw gateway status"
