# IATO_V7 Lean Package

## Install Lean/Lake locally

Use the helper script from this package directory:

```bash
./scripts/install_lake.sh
```

It attempts:
1. Reuse existing `lean`/`lake` if already installed.
2. Install `elan` from the official Lean/Elan release endpoints.
3. Fallback to `apt-get install elan` when a distribution package is available.
4. Install the exact toolchain declared in `lean-toolchain` and verify `lean`/`lake`.

## Build and test

The canonical local invocation is:

```bash
./scripts/build_lake.sh
```

For CI or already-prepared environments, the script expands to:

```bash
source scripts/env.sh
lake update
lake build
lake test
```

Optional flags:
- `./scripts/build_lake.sh --no-update` skips dependency refresh.
- `./scripts/build_lake.sh --no-test` skips the Lake `test` script.
- `./scripts/build_lake.sh <target>` builds specific Lake targets.

## Build environment variables

Before invoking `lake` directly, load the environment helper:

```bash
source scripts/env.sh
```

This exports:
- `IATO_V7_REPO_ROOT` and `IATO_V7_LEAN_DIR` for deterministic path resolution.
- `IATO_V7_TOOLCHAIN` from `lean-toolchain`.
- `ELAN_HOME` and prepends `$ELAN_HOME/bin` to `PATH`.
- `LEAN` and `LAKE` pointing to the elan-managed binaries.
- `LEAN_ABORT_ON_PANIC=1` for fail-fast behavior.
- `LEAN_PATH` defaulting to the local `.lake/packages`.
- `LAKE_NO_CACHE=0` (cache enabled).


## Install Git GUI

Use:

```bash
./scripts/install_git_gui.sh
```

What it does:
- Installs `git` and `git-gui` via apt.
- Prints proxy-related diagnostics if apt fails (common in restricted environments).
- Adds `alias ggui="git gui"` to `~/.bashrc` for convenience.


## Install Podman

Use:

```bash
./scripts/install_podman.sh
```

What it does:
- Installs `podman`, `podman-compose`, and rootless container dependencies.
- Prints proxy diagnostics when apt is blocked.
- Ensures `scripts/env.sh` includes Podman defaults for portability.

## Podman environment variables for portability

Load env variables before running container builds:

```bash
source scripts/env.sh
```

Important variables:
- `PODMAN_USERNS=keep-id` to reduce host/container UID mismatch issues.
- `PODMAN_SYSTEMD_UNIT=false` to avoid systemd unit expectations in simple sessions.
- `COMPOSE_DOCKER_CLI_BUILD=1` for compatible compose build behavior.

## Kubernetes fallback job (proxy-conflict mitigation)

For environments where local container networking/proxy behavior differs from Podman,
you can run the same build as a standard Kubernetes Job:

```bash
kubectl apply -f k8s-build-job.yaml
kubectl logs -f job/iato-v7-lean-build
```

The job includes `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` fields so cluster-level
proxy values can be managed consistently.


## Fail-forward Defensive DevOps strategy

This project intentionally prioritizes availability and execution over architectural purity:

- **Normalization as a Filter**: `scripts/normalize_ci_env.sh` acts as the source of truth for CI proxy state.
  It maps upper/lower-case proxy variables and writes deterministic values to `GITHUB_ENV` so Lean/Lake
  and container tooling do not inherit host-specific ambiguity.
- **Podman as the low-cost path**: `podman-compose.yml` is the first, fastest daemonless execution path
  for terminal-centric workflows.
- **Kubernetes as the guaranteed path**: `k8s-build-job.yaml` is the fallback when local DNS/proxy
  interception causes Podman networking mismatches, using cluster-native service discovery and egress policy.
