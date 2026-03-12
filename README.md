# Intent-to-Auditable-Trust-Object (IATO-V7)

From the terminal: host-path, reproducible XML artifacts, and traceable JBoss EAP 7 migration across SOC environments.

[![Build](https://img.shields.io/badge/build-passing-brightgreen)](lean/iato_v7/lakefile.lean)
[![Essential%208](https://img.shields.io/badge/Essential%208-ML4-blue)](docs/cyber-risk-controls.md)
[![SOC2](https://img.shields.io/badge/SOC2-CC6.1%20%7C%20CC6.6-orange)](docs/ARCHITECTURE.md)
[![ISM](https://img.shields.io/badge/ISM-0457--0460-green)](docs/threat-model.md)


## Executive Summary:

IĀTŌ‑v7 is a configuration-driven engine that scans host path file systems, applies predefined rules, and produces clean, standardised XML reports that capture exactly what was found.
The output is consistent and repeatable — the same config and files always produce the same result — giving teams reliable evidence for audits, compliance reviews, and secure system migrations, for legacy JBoss EAP 7 worker environments. 

## Overview: 

We ditched traditional filesystem parsers — which are slow, manual, and error-prone.
Instead, IĀTŌ-V7 uses Nmap (network scanner) as a fast, stateless, high-concurrency engine to audit local file paths.
Runs in WSL2, Minikube, or Ubuntu — works seamlessly in typical dev/test environments for Windows/Linux teams handling legacy JBoss migrations.

| Component | Role |
| --- | --- |
| **TOML Manifest** | Source of truth for paths, hash expectations, and audit rules. |
| **Nmap (Orchestrator)** | Executes path discovery and integrity checks via NSE scripts. |
| **XML Artifacts** | Canonical output format for downstream formal validation. |
| **IĀTŌ‑V7 Engine** | Consumes XML to validate observed state against the original TOML manifest. |

## Compliance Coverage:

| Framework | Control Scope | Coverage |
|---|---|---|
| Essential 8 (ML4) | Privilege separation, application control, patch governance | Worker isolation proofs and compatibility scanning |
| SOC2 TSC | `CC6.1`, `CC6.6`, `A1.2`, `PI1.3` | Access/control enforcement and change evidence workflows |
| ISM (ASD) | `0457`-`0460` privileged boundary and application control requirements | Administrative separation and migration control workflows |


## Control Mapping:

| Capability | Compliance Mapping | Evidence Surface |
|---|---|---|
| Worker compatibility proofing | Essential 8 ML4; SOC2 `CC6.1`; ISM `0457` isolation assurance | `lean/iato_v7/IATO/V7/Worker.lean` |
| Legacy conflict scanning | SOC2 `CC6.6`; SOC2 `PI1.3`; Essential 8 application control | `lean/iato_v7/IATO/V7/Scanner.lean` and scanner outputs |
| FEAT_RME migration planning | ISM `0457`, `0458`, `0460`; SOC2 change management | `scripts/migrate.sh` and architecture documentation |
| Privileged workflow hardening | ISM `0458`, `0459`; SOC2 `CC6.1` | Threat model and operational control procedures |
| Architecture invariants | SOC2/ISM control objectives; EAL7+ readiness support | `lean/iato_v7/IATO/V7/Architecture.lean` |

## Essential 8 Maturity (Level 4)

```text
[ ] Macro    [x] Privilege    [x] Application    [ ] Office
[x] Web      [x] User         [x] Patch           [x] Backup
```

Automation Focus:
- Privilege separation across worker domains.
- Application control through verification and migration gating.
- Patch compatibility checks for legacy worker migration inputs.

## Verified Architecture:

```text
lean/iato_v7/IATO/V7/
  Basic.lean         # Lattice and security foundations
  Worker.lean        # Worker-domain non-interference
  Scanner.lean       # Dependency/conflict detection
  Architecture.lean  # System invariants aligned to SOC2 and ISM

workers/source/    # Legacy worker examples and source manifests
workers/target/    # FEAT_RME-aligned generated worker manifests
workers/reports/   # Compatibility scan reports and migration outputs

docs/ARCHITECTURE.md
  docs/WORKER_COMPAT.md  # Audit and implementation narrative
```

## Orchestration: 

| **Category**                 | **Description / Functionality**                                                                                                                                 | **Integration / Complement**                                                                                                                                                    | **Target Environment / Notes**                                                                      |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **Orchestration Layer**      | IĀTŌ-v7 acts as a deterministic execution wrapper. Converts `config.toml` manifests into canonical Nmap XML audit artifacts for host-path filesystem assurance. | Generates structured, parseable XML outputs suitable for integrity correlation.                                                                                                 | Optimized for WSL2/Minikube environments; reduces impact of metadata-heavy scans on 9P I/O latency. |
| **Endpoint Security Scope**  | Out-of-bounds for standard agents: no persistent monitoring, behavioral analysis, or runtime telemetry.                                                         | Complements existing endpoint posture tools by providing deterministic filesystem verification.                                                                                 | Targets regulated endpoints where standard agents may be insufficient.                              |
| **Front-end Integration**    | Works with F5 BIG-IP APM as the access policy enforcement gateway.                                                                                              | BIG-IP APM performs client-side posture checks (antivirus/firewall, file/process/registry validation, device identifiers). IĀTŌ-v7 fills the gap in deep backend host scanning. | Backend Linux servers (e.g., JBoss EAP 7) behind BIG-IP APM.                                        |
| **Audit & Compliance**       | Produces XML output for deterministic verification. Structured data can be correlated with BIG-IP APM session logs or endpoint inspection results.              | Supports compliance frameworks: Essential Eight, ISM, SOC 2. Enables layered, auditable integrity evidence across the application delivery path (edge → backend filesystem).    | Ensures formal, deterministic file/permissions/content verification for regulated environments.     |
| **Performance Optimization** | Reduces scan-induced latency by optimizing metadata-heavy filesystem checks.                                                                                    | Works efficiently with virtualized/containerized dev/test environments.                                                                                                         | WSL2 / Minikube recommended for evaluation/testing.                                                 |


### 2) Design Goals:
- **Deterministic orchestration:** equivalent manifest inputs must produce equivalent command lines, policy payloads, and XML artifact paths.
- **Audit-only runtime posture:** no network discovery side effects.
- **In-process validation:** integrity and policy checks are performed by NSE scripts during scan execution.
- **Operational observability:** per-operation latency accounting is captured for forensic auditability.
- **Schema-compliant hand-off:** generated XML is validated against the IĀTŌ‑V7 audit schema before acceptance.

### 3) Architecture: 
```text
config.toml
   │
   ▼
Manifest Parser ──► Deterministic Policy Builder ──► Nmap Command Planner
                                                      │
                                                      ▼
                                             Nmap + Custom NSE Scripts
                                                      │
                                                      ▼
                                          Canonical XML Artifact (-oX)
                                                      │
                                                      ▼
                                         Schema + Status Verification
                                                      │
                                                      ▼
                                         Clean/Dirty + Process Exit Code
```

#### 3.1 Module Responsibilities:

| **Stage / Module**             | **Responsibilities**                                                                                       | **Deterministic / Compliance Notes**                                         | **Telemetry / Output**                 |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------- |
| **1. Manifest Parser**         | Parse TOML, normalize explicit paths, reject unspecified defaults                                          | Ensures deterministic path resolution                                        | `manifest.parse.ms`                    |
| **2. Policy Builder**          | Generate stable, sorted policy for NSE scripts (hash, mode, ownership, integrity predicates)               | Lexicographic sorting, stable serialization                                  | `policy.write.ms`                      |
| **3. Command Planner**         | Construct constrained Nmap invocation (`-Pn -sn`, `-oX`, NSE script + args)                                | Fixed command argument order, timing template derived from I/O latency probe | `nmap.exec.ms`                         |
| **4. Execution + Telemetry**   | Run Nmap via `subprocess` or `asyncio`, track operation latency                                            | Stable runtime environment, pinned Nmap version, no mutable runtime options  | Append-only JSONL structured logs      |
| **5. Verification Gate**       | Parse XML produced by NSE, enforce Clean/Dirty semantics                                                   | Exit non-zero on policy deviation, schema mismatch, or NSE-reported Dirty    | `xml.validate.ms`, final exit code     |
| **Deterministic Behavior**     | Stable ordering, artifact mapping `(manifest fingerprint, target root, schema version)`, stable invocation | Essential for audit/compliance (Essential Eight, ISM, SOC 2)                 | N/A                                    |
| **NSE Contract**               | Custom Lua scripts: hash, ACL, ownership, structural integrity checks                                      | Must set failing status if any deviation                                     | XML `Clean`/`Dirty`                    |
| **Timing & I/O Strategy**      | Probe latency → map to Nmap `-T2..-T4`; explicit target paths only                                         | Prevent unbounded DFS traversal                                              | N/A                                    |
| **Implementation Constraints** | Python/Go, no extra parsers, minimal filesystem churn                                                      | Deterministic outputs in WSL2/Minikube                                       | N/A                                    |
| **Reference Integration**      | Entrypoint: `nmap_path_audit_orchestrator.py` <br> NSE logic: `path_audit.nse`                             | Integration-ready deterministic orchestration                                | N/A                                    |
| **Acceptance Criteria**        | Valid TOML → deterministic Nmap → canonical XML → Clean/Dirty → non-zero exit if deviation                 | Ensures full compliance and traceability                                     | Structured telemetry JSONL + exit code |

## Repository Layout

- `lean/`: Lean 4 formal models and executable tests.
- `docs/`: Architecture and notebook documentation.
- `workers/`: Legacy/new worker implementations.
- `scripts/`: Automation and tooling helpers.
- `data/`: Static data manifests and reference files.

## Quick Start (Linux)

This workflow is for Linux-based execution in regulated IT environments. Run all commands from the repository root.

### Entry point + destination (know this first)
- **Run command from repo root:** `iato-scan --config config.local.toml`.
- **Output destination:** XML artifact at `lean/iato_v7/nmap-path-state.xml` (audit evidence artifact).
- **Exit semantics:** `0 = Clean` (observed state matched declared intent), non-zero = Dirty/error.

### 1) Open Linux shell and clone

```bash
cd ~
git clone https://github.com/<whatheheckisthis>/Intent-to-Auditable-Trust-Object.git
cd Intent-to-Auditable-Trust-Object
```

### 2) Install dependencies (nmap is required)

```bash
sudo apt update
sudo apt install -y git curl python3 python3-pip build-essential nmap
command -v nmap && nmap --version | head -n 1
```

If you run inside Minikube/pod, install `python3` and `nmap` in that runtime as well, or execute from a Linux host that has access to the target mount points.

### 3) Install Lean toolchain dependencies

```bash
./scripts/install-formal-verification-deps.sh
./scripts/setup-lean-ci-deps.sh
```

### 4) Build + validate core models

```bash
cd lean/iato_v7
lake test
cd ../..

python3 scripts/scan_workers.py data/legacy_workers.csv
./scripts/lake_build.sh
```

### 5) Create `config.local.toml` with Linux defaults

> **Be careful:** `config.local.toml` is machine-local intent/evidence input. Keep it out of version control and avoid committing sensitive path/hash material.

```bash
cat > config.local.toml <<EOF
# Be careful: replace placeholder hashes before running non-test audits.
# Linux local config for IĀTŌ-V7
schema_version = "1.0.0"
project = "iato-v7"
release = "local"

[orchestrator]
engine = "nmap"
flags = ["-Pn", "-sn", "-n"]
output_format = "xml"

[audit]
root_path = "/"
target = "127.0.0.1"
nse_script = "lean/iato_v7/nse/path_audit.nse"
fail_on_deviation = true

[timing]
template = "T2"
max_template = "T3"
scan_interval_seconds = 0

[artifacts]
xml_output = "lean/iato_v7/nmap-path-state.xml"
policy_output = "lean/iato_v7/.nmap-path-policy.json"

[[targets]]
id = "linux-var-lib"
path = "/var/lib"
required = false
sha256 = "<expected_sha256_hex_or_manifest_hash>"
owner = "root"
group = "root"
mode = "0755"

[[targets]]
id = "linux-opt-app"
path = "/opt/app"
required = false
sha256 = "<expected_sha256_hex_or_manifest_hash>"
owner = "root"
group = "root"
mode = "0755"
EOF

# Adjust target paths and integrity expectations for your Linux environment.
# Be careful: do not commit real environment hashes or secret-bearing paths.
nano config.local.toml
```

### 6) Populate `sha256` values in `config.local.toml` (required before any scan)

`config.local.toml` comes first: define each `[[targets]]` path, required flag, owner/group, mode, and placeholder `sha256` values. Then run local Linux/WSL2 hash commands for those exact paths and replace each placeholder with the current result before any scan. Hashes must be computed locally on the audited system using trusted binaries (sha256sum, certutil, shasum) with no external transmission of file content or paths; uploading audited content or path details weakens evidence integrity for SOC2/ISM/Essential 8 workflows.

```bash
# Single file target
sha256sum /full/absolute/path/to/file

# Directory target (deterministic recursive manifest hash)
find /full/path/to/dir -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum
```

Path/behavior example (exact mapping expected):

```toml
[[targets]]
id = "jboss-service-unit"
path = "/etc/systemd/system/jboss.service"
required = true
sha256 = "<replace_with_current_64_hex_output>"
owner = "root"
group = "root"
mode = "0644"
```

```bash
sha256sum /etc/systemd/system/jboss.service
# Paste the 64-hex output into the matching `sha256` field above.
```

### 7) Add short alias (`iato-scan`) and persist it

```bash
alias iato-scan='python3 lean/iato_v7/scripts/nmap_path_audit_orchestrator.py'
echo "alias iato-scan='python3 lean/iato_v7/scripts/nmap_path_audit_orchestrator.py'" >> ~/.bashrc
source ~/.bashrc
```

Run environment reminders anytime:

```bash
./scripts/context-clues.sh
```

### 8) Run audit (dry-run first, then real run)

```bash
# Dry-run = preview deterministic command only
iato-scan --config config.local.toml --dry-run

# Real run = produce XML audit artifact
iato-scan --config config.local.toml
```

### Success / Failure indicators

```bash
# Exit code from last run
echo $? 

# XML artifact exists?
ls -lh lean/iato_v7/nmap-path-state.xml

# Optional quick inspection
head -n 20 lean/iato_v7/nmap-path-state.xml
```

- **Success:** exit code `0` and XML file exists.
- **Failure:** non-zero exit code, missing XML, or explicit mismatch/error output.

Fallback (direct Python invocation, same entrypoint):

```bash
python3 lean/iato_v7/scripts/nmap_path_audit_orchestrator.py --config config.local.toml --dry-run
python3 lean/iato_v7/scripts/nmap_path_audit_orchestrator.py --config config.local.toml
```

## Architecture Non-Goals:

To keep the scope explicit, the architecture defines non-goals **NG-001** through **NG-005**:

- **NG-001**: Not a replacement for a full organizational SDLC/security program.
- **NG-002**: Not a guarantee of complete runtime hardening in every environment.
- **NG-003**: Not full formal verification of all third-party or external system behavior.
- **NG-004**: Not an automatic compliance attestation without organization-specific controls/evidence.
- **NG-005**: Not a claim of certification, endorsement, or affiliation with **Common Criteria**.

***IATO-V7 does not assert affiliation with Common Criteria***.
