#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OPENCLAW_DEMO_MACHINE="${OPENCLAW_DEMO_MACHINE:-openclaw-demo}"
OPENCLAW_DEMO_CPUS="${OPENCLAW_DEMO_CPUS:-4}"
OPENCLAW_DEMO_MEMORY_MB="${OPENCLAW_DEMO_MEMORY_MB:-4096}"
OPENCLAW_DEMO_DISK_GB="${OPENCLAW_DEMO_DISK_GB:-40}"
OPENCLAW_DEMO_REMOTE_REPO_ROOT="${OPENCLAW_DEMO_REMOTE_REPO_ROOT:-$REPO_ROOT}"
OPENCLAW_DEMO_AGENT_ID="${OPENCLAW_DEMO_AGENT_ID:-demo-agent}"
OPENCLAW_DEMO_AGENT_WORKSPACE="${OPENCLAW_DEMO_AGENT_WORKSPACE:-$OPENCLAW_DEMO_REMOTE_REPO_ROOT/agents/demo-agent/workspace}"
OPENCLAW_DEMO_AGENT_TEMPLATE="${OPENCLAW_DEMO_AGENT_TEMPLATE:-$OPENCLAW_DEMO_REMOTE_REPO_ROOT/agents/demo-agent/agent.template.json}"
OPENCLAW_DEMO_TEST_TARGET="${OPENCLAW_DEMO_TEST_TARGET:-openclaw/openclaw}"

print_step() {
  printf '\n==> %s\n' "$*"
}

run_cmd() {
  printf '+'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
  "$@"
}

run_remote_sh() {
  local remote_script="$1"
  printf '+ podman machine ssh %q -- bash -lc %q\n' "$OPENCLAW_DEMO_MACHINE" "$remote_script"
  podman machine ssh "$OPENCLAW_DEMO_MACHINE" -- bash -lc "$remote_script"
}

run_remote_sh_masked() {
  local display_script="$1"
  local remote_script="$2"
  printf '+ podman machine ssh %q -- bash -lc %q\n' "$OPENCLAW_DEMO_MACHINE" "$display_script"
  podman machine ssh "$OPENCLAW_DEMO_MACHINE" -- bash -lc "$remote_script"
}

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  cat <<'EOF' >&2
Homebrew is required to auto-install Podman on macOS.

Install it first:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
EOF
  exit 1
}

ensure_podman() {
  if command -v podman >/dev/null 2>&1; then
    return 0
  fi
  ensure_brew
  print_step "Installing Podman with Homebrew"
  run_cmd brew install podman
}

machine_exists() {
  podman machine list --format '{{.Name}}' | grep -Fxq "$OPENCLAW_DEMO_MACHINE"
}

machine_running() {
  local state
  state="$(podman machine inspect "$OPENCLAW_DEMO_MACHINE" --format '{{.State}}' 2>/dev/null || true)"
  [[ "$state" == "running" ]]
}

ensure_machine_started() {
  ensure_podman

  if ! machine_exists; then
    print_step "Creating dedicated Podman machine: $OPENCLAW_DEMO_MACHINE"
    run_cmd podman machine init \
      --cpus "$OPENCLAW_DEMO_CPUS" \
      --memory "$OPENCLAW_DEMO_MEMORY_MB" \
      --disk-size "$OPENCLAW_DEMO_DISK_GB" \
      "$OPENCLAW_DEMO_MACHINE"
  fi

  if ! machine_running; then
    stop_other_running_machines
    print_step "Starting Podman machine: $OPENCLAW_DEMO_MACHINE"
    run_cmd podman machine start "$OPENCLAW_DEMO_MACHINE"
  fi
}

wait_for_machine_ssh() {
  local attempt
  print_step "Waiting for SSH access to the Podman machine"
  for attempt in $(seq 1 30); do
    if podman machine ssh "$OPENCLAW_DEMO_MACHINE" -- true >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for podman machine ssh ${OPENCLAW_DEMO_MACHINE} -- true" >&2
  exit 1
}

stop_other_running_machines() {
  local others
  others="$(
    python3 - "$OPENCLAW_DEMO_MACHINE" <<'PY'
import json
import subprocess
import sys

target = sys.argv[1]
raw = subprocess.check_output(['podman', 'machine', 'list', '--format', 'json'], text=True)
machines = json.loads(raw)
for machine in machines:
    if machine.get('Name') != target and machine.get('Running'):
        print(machine['Name'])
PY
  )"

  if [[ -z "$others" ]]; then
    return 0
  fi

  print_step "Stopping other running Podman machines so $OPENCLAW_DEMO_MACHINE can start"
  while IFS= read -r machine_name; do
    [[ -n "$machine_name" ]] || continue
    run_cmd podman machine stop "$machine_name"
  done <<<"$others"
}

ensure_machine() {
  ensure_machine_started
  wait_for_machine_ssh
}

ensure_repo_visible_in_vm() {
  run_remote_sh "test -d $(printf '%q' "$OPENCLAW_DEMO_REMOTE_REPO_ROOT")"
}

ensure_remote_openclaw_installed() {
  print_step "Installing OpenClaw in the Podman machine if needed"
  run_remote_sh "if command -v openclaw >/dev/null 2>&1; then openclaw --version; else curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard; openclaw --version; fi"
}

resolve_onboard_provider() {
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    OPENCLAW_DEMO_PROVIDER_NAME="openai"
    OPENCLAW_DEMO_PROVIDER_FLAG="--auth-choice openai-api-key --openai-api-key \"\$OPENAI_API_KEY\""
    return 0
  fi
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    OPENCLAW_DEMO_PROVIDER_NAME="anthropic"
    OPENCLAW_DEMO_PROVIDER_FLAG="--auth-choice anthropic-api-key --anthropic-api-key \"\$ANTHROPIC_API_KEY\""
    return 0
  fi
  if [[ -n "${GEMINI_API_KEY:-}" ]]; then
    OPENCLAW_DEMO_PROVIDER_NAME="gemini"
    OPENCLAW_DEMO_PROVIDER_FLAG="--auth-choice gemini-api-key --gemini-api-key \"\$GEMINI_API_KEY\""
    return 0
  fi
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    OPENCLAW_DEMO_PROVIDER_NAME="openrouter"
    OPENCLAW_DEMO_PROVIDER_FLAG="--auth-choice openrouter-api-key --openrouter-api-key \"\$OPENROUTER_API_KEY\""
    return 0
  fi

  OPENCLAW_DEMO_PROVIDER_NAME="skip"
  OPENCLAW_DEMO_PROVIDER_FLAG="--auth-choice skip"
}

run_remote_onboard() {
  resolve_onboard_provider

  local base_cmd
  base_cmd='openclaw onboard --non-interactive --accept-risk --flow quickstart --install-daemon --skip-channels --skip-search --skip-skills --skip-ui --gateway-bind loopback'

  if [[ "$OPENCLAW_DEMO_PROVIDER_NAME" == "skip" ]]; then
    print_step "Running onboarding without a model provider"
    run_remote_sh "$base_cmd $OPENCLAW_DEMO_PROVIDER_FLAG"
    return 0
  fi

  local env_prefix=""
  local display_env=""
  case "$OPENCLAW_DEMO_PROVIDER_NAME" in
    openai)
      env_prefix="OPENAI_API_KEY=$(printf '%q' "$OPENAI_API_KEY") "
      display_env='OPENAI_API_KEY="$OPENAI_API_KEY" '
      ;;
    anthropic)
      env_prefix="ANTHROPIC_API_KEY=$(printf '%q' "$ANTHROPIC_API_KEY") "
      display_env='ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" '
      ;;
    gemini)
      env_prefix="GEMINI_API_KEY=$(printf '%q' "$GEMINI_API_KEY") "
      display_env='GEMINI_API_KEY="$GEMINI_API_KEY" '
      ;;
    openrouter)
      env_prefix="OPENROUTER_API_KEY=$(printf '%q' "$OPENROUTER_API_KEY") "
      display_env='OPENROUTER_API_KEY="$OPENROUTER_API_KEY" '
      ;;
  esac

  print_step "Running onboarding with provider: $OPENCLAW_DEMO_PROVIDER_NAME"
  run_remote_sh_masked \
    "${display_env}${base_cmd} ${OPENCLAW_DEMO_PROVIDER_FLAG}" \
    "${env_prefix}${base_cmd} ${OPENCLAW_DEMO_PROVIDER_FLAG}"
}

require_model_provider_for_agent_run() {
  if [[ -n "${OPENAI_API_KEY:-}${ANTHROPIC_API_KEY:-}${GEMINI_API_KEY:-}${OPENROUTER_API_KEY:-}" ]]; then
    return 0
  fi

  cat <<'EOF' >&2
No model provider API key is set in the host shell.

Set one of these before running the agent demo:
  export OPENAI_API_KEY=...
  export ANTHROPIC_API_KEY=...
  export GEMINI_API_KEY=...
  export OPENROUTER_API_KEY=...
EOF
  exit 1
}
