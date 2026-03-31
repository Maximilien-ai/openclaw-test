# Demo Agent

This directory contains the committed files for the demo agent that `create-agent.sh` provisions inside the `openclaw-demo` Podman machine.

## Intent

- Keep the agent workspace in the repo so it can be exported or edited directly.
- Give the agent a small, inspectable GitHub workflow.
- Avoid hidden runtime state where possible.

## Workspace contents

- [workspace/SOUL.md](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/workspace/SOUL.md)
- [workspace/skills/github-demo.md](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/workspace/skills/github-demo.md)
- [workspace/tools/github-issue-list-public.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/workspace/tools/github-issue-list-public.sh)
- [workspace/tools/github-issue-create.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/workspace/tools/github-issue-create.sh)

`create-agent.sh` points the OpenClaw agent workspace at this committed `workspace/` directory and merges [agent.template.json](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/agent.template.json) into the machine's `openclaw.json`.
