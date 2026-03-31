# OpenClaw on a Dedicated Podman Machine

This repo creates a separate Podman VM named `openclaw-demo`, installs OpenClaw inside that VM using the official getting-started flow, and keeps the demo agent files under `agents/` so they are easy to inspect, export, and modify.

The scripts print the commands they run. The only thing they intentionally redact is API key values.

## What this does

1. `setup.sh`
   Creates or starts the dedicated Podman machine, installs OpenClaw in the VM, and runs `openclaw onboard` inside the VM.
2. `start.sh`
   Starts the VM and the OpenClaw gateway service again later.
3. `test.sh`
   Runs `openclaw --version`, `openclaw gateway status`, and `openclaw doctor --non-interactive` inside the VM.
4. `ssh.sh`
   Opens a direct SSH session into the Podman VM or runs a single command there.
5. `create-agent.sh`
   Creates a demo agent whose workspace is tracked in this repo under `agents/demo-agent/workspace/`.
6. `agent-demo.sh`
   Runs the demo agent against a public GitHub repository issue list.

## File layout

- [setup.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/setup.sh)
- [start.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/start.sh)
- [test.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/test.sh)
- [ssh.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/ssh.sh)
- [create-agent.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/create-agent.sh)
- [agent-demo.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/agent-demo.sh)
- [scripts/lib.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/scripts/lib.sh)
- [agents/demo-agent/agent.template.json](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/agent.template.json)
- [agents/demo-agent/README.md](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/README.md)
- [agents/demo-agent/workspace/SOUL.md](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/workspace/SOUL.md)
- [agents/demo-agent/workspace/skills/github-demo.md](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/workspace/skills/github-demo.md)
- [agents/demo-agent/workspace/tools/github-issue-list-public.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/workspace/tools/github-issue-list-public.sh)
- [agents/demo-agent/workspace/tools/github-issue-create.sh](/Users/maximilien/github/Maximilien-ai/openclaw-test/agents/demo-agent/workspace/tools/github-issue-create.sh)

## Assumptions

- Host OS: macOS
- Podman may be missing. If so, `setup.sh` installs it with Homebrew.
- The Podman machine is isolated from your existing `podman-machine-default`.
- Because Podman only allows one active machine at a time on this host, the scripts stop any other running Podman machine before starting `openclaw-demo`.
- The repo path is visible inside the VM through Podman's default `/Users:/Users` mount.

## Environment variables

Optional sizing overrides for the dedicated VM:

```bash
export OPENCLAW_DEMO_MACHINE=openclaw-demo
export OPENCLAW_DEMO_CPUS=4
export OPENCLAW_DEMO_MEMORY_MB=4096
export OPENCLAW_DEMO_DISK_GB=40
```

Optional model provider for non-interactive onboarding and agent runs:

```bash
export OPENAI_API_KEY=...
# or
export ANTHROPIC_API_KEY=...
# or
export GEMINI_API_KEY=...
# or
export OPENROUTER_API_KEY=...
```

If no provider key is set, `setup.sh` falls back to `openclaw onboard --auth-choice skip`. That is enough to install and configure the gateway, but the demo agent will not be able to answer model-backed requests until a provider is configured later.

Optional model override for the demo agent:

```bash
export OPENCLAW_DEMO_MODEL="openai/gpt-5.2"
```

## Recommended flow

```bash
./setup.sh
./start.sh
./test.sh
./ssh.sh
./create-agent.sh
./agent-demo.sh
```

## Direct VM access

For live demos, `ssh.sh` is the practical escape hatch. It starts the dedicated machine if needed, resolves the machine's current SSH port and identity from `podman machine inspect`, and then connects directly instead of relying on `podman machine ssh`.

Open an interactive shell:

```bash
./ssh.sh
```

Run a single command:

```bash
./ssh.sh openclaw --version
./ssh.sh openclaw gateway status
./ssh.sh openclaw doctor --non-interactive
```

This is useful if the automation gets stuck but the VM itself is still reachable.

## Live demo fallback path

If the full scripted flow gets stuck, use this exact sequence.

Start the machine and open a shell in the VM:

```bash
./ssh.sh
```

From inside the VM, check the basics:

```bash
openclaw --version
openclaw gateway status
openclaw doctor --non-interactive
```

If OpenClaw is not installed yet inside the VM, install it with the same official installer used by `setup.sh`:

```bash
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

If onboarding still needs to happen, run one of these:

Without a model provider:

```bash
openclaw onboard --non-interactive --accept-risk --flow quickstart --install-daemon --skip-channels --skip-search --skip-skills --skip-ui --gateway-bind loopback --auth-choice skip
```

With OpenAI:

```bash
export OPENAI_API_KEY=...
openclaw onboard --non-interactive --accept-risk --flow quickstart --install-daemon --skip-channels --skip-search --skip-skills --skip-ui --gateway-bind loopback --auth-choice openai-api-key --openai-api-key "$OPENAI_API_KEY"
```

Then continue the demo either from the host:

```bash
./test.sh
./create-agent.sh
./agent-demo.sh
```

Or manually from inside the VM:

```bash
openclaw agents list
openclaw config file
```

If you just want a quick health check from the host without opening a shell:

```bash
./ssh.sh openclaw --version
./ssh.sh openclaw gateway status
./ssh.sh openclaw doctor --non-interactive
```

## Commands the scripts are wrapping

The main official OpenClaw install step inside the VM is:

```bash
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

The main official onboarding step inside the VM is:

```bash
openclaw onboard --non-interactive --accept-risk --flow quickstart --install-daemon --skip-channels --skip-search --skip-skills --skip-ui --gateway-bind loopback ...
```

The Podman machine bootstrap is:

```bash
podman machine init --cpus 4 --memory 4096 --disk-size 40 openclaw-demo
podman machine start openclaw-demo
```

## GitHub demo notes

The committed demo agent uses OpenClaw's coding tool profile plus `group:web`. Its workspace includes:

- a public issue lister that works without GitHub auth
- a create-issue helper that uses `gh issue create` when `gh auth login` has been completed inside the VM

That means the first demo can work against a public repo without extra GitHub setup, while issue creation remains an explicit opt-in step.
