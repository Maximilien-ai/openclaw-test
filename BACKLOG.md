# Backlog

This backlog tracks the work needed to make the dedicated `openclaw-demo` Podman machine stable enough for a reliable OpenClaw demo on macOS.

## Observed issues

- [ ] Confirm and document that only one Podman machine can be active at a time on this host.
- [ ] Reproduce the intermittent `openclaw-demo` boot instability.
- [ ] Reproduce and capture the Fedora CoreOS emergency-mode boot failure during Ignition.
- [ ] Reproduce and capture the case where the VM log looks healthy but `podman machine ssh openclaw-demo` still fails.
- [ ] Document why the full `setup.sh -> test.sh -> create-agent.sh -> agent-demo.sh` path could not be validated end to end yet.

## Root cause investigation

### Podman lifecycle on macOS

- [ ] Check whether Podman `5.8.1` has known AppleHV or machine-state issues on macOS.
- [ ] Verify whether `podman machine start` returns before SSH is actually ready.
- [ ] Verify whether the VM process exits after an apparently successful boot.
- [ ] Determine whether the failure is in Podman state tracking, VM boot, or SSH exposure.

### VM resource profile

- [ ] Compare `4 CPU / 4096 MiB / 40 GiB` against the larger profile that previously failed.
- [ ] Test a smaller profile such as `2 CPU / 2048 MiB / 30 GiB`.
- [ ] Check whether memory pressure on the host correlates with machine instability.
- [ ] Check whether Rosetta settings affect machine stability.

### Fedora CoreOS and Ignition

- [ ] Capture full VM boot logs for both successful and failed starts.
- [ ] Determine why one run entered emergency mode during Ignition.
- [ ] Check whether the machine image or ignition state is being reused after failed create/start attempts.
- [ ] Decide whether broken machines should always be destroyed and recreated instead of retried.

### SSH readiness

- [ ] Replace the current simple poll with stronger readiness checks.
- [ ] Detect the difference between VM not running, SSH port not open, and SSH login failing.
- [ ] Check whether `podman machine inspect` contains a better readiness signal than the current approach.
- [ ] Evaluate whether direct SSH fallback should be supported when `podman machine ssh` is unreliable.

## Diagnostics

### Machine state capture

- [ ] Capture `podman machine list --format json` before each start attempt.
- [ ] Capture `podman machine inspect openclaw-demo` before each start attempt.
- [ ] Capture the same commands after each start attempt.
- [ ] Record timestamps and whether `Running` and `Starting` are both set.

### Host process capture

- [ ] Capture `vfkit`, `gvproxy`, and `podman machine start/stop` processes during boot.
- [ ] Record whether any of those processes exit unexpectedly after boot.
- [ ] Check whether stale `podman machine` processes are left behind after a failure.

### Boot log capture

- [ ] Save the latest `openclaw-demo` VM boot log after each failed boot.
- [ ] Create `docs/boot-logs/` for archived machine logs.
- [ ] Store timestamped copies of failed and successful boot logs for comparison.

### Connectivity checks

- [ ] Retry `podman machine ssh openclaw-demo -- true` after each start attempt.
- [ ] If needed, test direct SSH using the identity path and port from `podman machine inspect`.
- [ ] Record whether Podman wrapper failures and direct SSH failures match.

### Host environment checks

- [ ] Measure available RAM and swap before starting the machine.
- [ ] Check whether other virtualization tooling is running at the same time.
- [ ] Verify whether macOS updates are pending.
- [ ] Verify whether a newer Podman version is available.

## Script hardening

### Machine recovery

- [ ] Add bounded retries around `podman machine start`.
- [ ] Collect diagnostics automatically when machine start fails.
- [ ] Print exact cleanup commands when the machine is stuck half-started.
- [ ] Create `scripts/recover-machine.sh` to stop stuck processes, remove the machine, and recreate it.

### Debug collection

- [ ] Create `scripts/collect-podman-debug.sh`.
- [ ] Include `podman machine list --format json` in the debug bundle.
- [ ] Include `podman machine inspect openclaw-demo` in the debug bundle.
- [ ] Include relevant process listings in the debug bundle.
- [ ] Include the latest VM boot log in the debug bundle.

### Readiness handling

- [ ] Add structured logging around each readiness attempt.
- [ ] Fail with a diagnostic bundle instead of a generic timeout.
- [ ] Improve the error message when SSH is refused after a successful-looking machine start.

## Validation

### Setup validation

- [ ] Run `./setup.sh` successfully against a fresh `openclaw-demo` machine.
- [ ] Confirm OpenClaw installs inside the VM.
- [ ] Confirm `openclaw onboard` completes in the VM.

### Health validation

- [ ] Run `./test.sh` successfully.
- [ ] Capture `openclaw doctor --non-interactive` output.
- [ ] Save the doctor output into `docs/verification.md`.

### Agent validation

- [ ] Run `./create-agent.sh` successfully.
- [ ] Confirm the demo agent appears in `openclaw agents list`.
- [ ] Run `./agent-demo.sh` successfully.
- [ ] Save a successful agent run example into `docs/verification.md`.

## Nice to have

- [ ] Add `./status.sh` to print machine state, gateway state, and recent relevant logs.
- [ ] Add an option to reuse an already-running machine instead of always stopping the default one.
- [ ] Add a `make demo` or `just demo` wrapper once the flow is stable.

## Exit criteria

- [ ] `openclaw-demo` boots reliably on two consecutive fresh create/start cycles.
- [ ] `podman machine ssh openclaw-demo -- true` succeeds consistently after `./setup.sh`.
- [ ] `./setup.sh`, `./test.sh`, `./create-agent.sh`, and `./agent-demo.sh` complete without manual intervention other than API keys when needed.
- [ ] `openclaw doctor --non-interactive` output is captured and reviewed.
