#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib.sh"

require_model_provider_for_agent_run

print_step "Ensuring the demo agent exists"
"$REPO_ROOT/create-agent.sh"

print_step "Running the agent against a public GitHub repo"
run_remote_sh "openclaw agent --agent ${OPENCLAW_DEMO_AGENT_ID} --message 'Use web research plus the local workspace tools to inspect public issues for ${OPENCLAW_DEMO_TEST_TARGET}. First run ./tools/github-issue-list-public.sh ${OPENCLAW_DEMO_TEST_TARGET} 5. Then summarize the three most interesting open issues in plain English and mention whether ./tools/github-issue-create.sh would need extra auth.' --json"
