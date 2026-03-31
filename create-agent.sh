#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib.sh"

print_step "Ensuring the machine and OpenClaw are ready"
ensure_machine
ensure_repo_visible_in_vm
ensure_remote_openclaw_installed

print_step "Preparing the agent workspace"
run_remote_sh "mkdir -p $(printf '%q' "$OPENCLAW_DEMO_AGENT_WORKSPACE") $(printf '%q' "$OPENCLAW_DEMO_AGENT_WORKSPACE/tools") $(printf '%q' "$OPENCLAW_DEMO_AGENT_WORKSPACE/skills")"

print_step "Creating the agent if it does not exist"
run_remote_sh "python3 - <<'PY'
import json
import subprocess

agent_id = '${OPENCLAW_DEMO_AGENT_ID}'
workspace = '$(printf '%q' "$OPENCLAW_DEMO_AGENT_WORKSPACE")'
raw = subprocess.check_output(['openclaw', 'agents', 'list', '--json'], text=True)
agents = json.loads(raw)
if any(agent.get('id') == agent_id for agent in agents):
    print(f'Agent already exists: {agent_id}')
else:
    subprocess.check_call([
        'openclaw',
        'agents',
        'add',
        agent_id,
        '--workspace',
        workspace,
        '--non-interactive',
    ])
PY"

print_step "Merging the committed agent template into the machine config"
run_remote_sh "python3 - $(printf '%q' "$OPENCLAW_DEMO_AGENT_TEMPLATE") $(printf '%q' "$OPENCLAW_DEMO_AGENT_WORKSPACE") <<'PY'
import json
import os
import pathlib
import subprocess
import sys

template_path = pathlib.Path(sys.argv[1])
workspace = sys.argv[2]
config_path = pathlib.Path(
    subprocess.check_output(['openclaw', 'config', 'file'], text=True).strip()
)

data = {}
if config_path.exists():
    data = json.loads(config_path.read_text())

template = json.loads(template_path.read_text())
agent_id = template['id']

def patch_placeholders(value):
    if isinstance(value, dict):
        return {k: patch_placeholders(v) for k, v in value.items()}
    if isinstance(value, list):
        return [patch_placeholders(item) for item in value]
    if value == '__WORKSPACE__':
        return workspace
    if value == '__MODEL__':
        model = os.environ.get('OPENCLAW_DEMO_MODEL', '').strip()
        return model or None
    return value

template = patch_placeholders(template)
if template.get('model') is None:
    template.pop('model', None)

agents = data.setdefault('agents', {}).setdefault('list', [])
for index, agent in enumerate(agents):
    if agent.get('id') == agent_id:
        agents[index] = {**agent, **template}
        break
else:
    agents.append(template)

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(json.dumps(data, indent=2) + '\n')
PY"

print_step "Setting a readable identity for the demo agent"
run_remote_sh "openclaw agents set-identity --agent ${OPENCLAW_DEMO_AGENT_ID} --name 'OpenClaw Demo Operator' --theme 'Repo issue triage and lightweight GitHub automation'"

print_step "Restarting the gateway so agent changes are picked up"
run_remote_sh "openclaw gateway restart"

print_step "Current agents"
run_remote_sh "openclaw agents list"
