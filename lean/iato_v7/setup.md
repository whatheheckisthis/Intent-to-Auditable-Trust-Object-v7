# CI Proxy Worker setup (Minikube + WSL2 + Windows host)

When you run this, you are essentially creating a "Sidecar" or "Runner" pattern. Because you are using Minikube, keep in mind that the `hostPath` doesn't see your C: drive by default—Minikube runs inside a VM.

## Missing link command (run from Windows terminal)

```powershell
minikube mount C:\Users\Name\Project:/workspace
```

## Minikube mount command (with persistence-friendly UID/GID)

```bash
minikube mount --uid=1000 --gid=1000 C:/Users/Name/Project:/workspace
```

## Recommended `/etc/wsl.conf`

```ini
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = false
```

After updating `/etc/wsl.conf`, restart WSL:

```powershell
wsl --shutdown
```

Then re-open your WSL shell and re-run the Minikube mount command.

## Apply the CI Proxy worker resources

```bash
kubectl apply -f lean/iato_v7/k8s-ci-proxy-worker.yaml
kubectl logs -f job/iato-v7-ci-proxy-worker
```

The worker loads `lean/iato_v7/k8s-build-job.yaml` as read-only scaffold input, parses the scaffold `args`, and executes them in `/workspace` inside the Lean container.

## Deterministic host-path audit (Nmap NSE)

Run the orchestrator in dry-run mode first to verify deterministic command construction from `lakefile.toml`, this setup file, `k8s-ci-proxy-worker.yaml`, and `run-ci-proxy.sh`:

```bash
python3 lean/iato_v7/scripts/nmap_path_audit_orchestrator.py --dry-run
```

Execute the scan to generate the canonical XML artifact consumed by IĀTŌ‑V7:

```bash
python3 lean/iato_v7/scripts/nmap_path_audit_orchestrator.py \
  --xml-out lean/iato_v7/nmap-path-state.xml
```

Execution profile:
- Uses `nmap --noninteractive -Pn -sn` for headless execution while suppressing host discovery and network probing semantics.
- Uses `-oX` output for stable machine-consumable XML.
- Passes strict schema/release/script arguments to `lean/iato_v7/nse/path_audit.nse`.
- Writes `lean/iato_v7/.nmap-path-policy.json` as a deterministic intermediate policy payload.

## Release binary assets

Build deterministic release assets for distribution:

```bash
python3 lean/iato_v7/scripts/build_nmap_release_assets.py
```

This produces:
- `lean/iato_v7/release/iato-v7-nmap-audit-<version>.py` (headless executable Python orchestrator)
- `lean/iato_v7/release/SHA256SUMS`
- `lean/iato_v7/release/release-manifest.json`
