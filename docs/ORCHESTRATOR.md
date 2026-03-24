# IĀTŌ‑V7 Orchestration Design

## 1) Purpose and Scope
The IĀTŌ‑V7 orchestration layer is a deterministic execution wrapper that converts a repository `config.toml` manifest into a canonical Nmap XML audit artifact for host-path filesystem assurance. It is optimized for WSL2/Minikube environments where metadata-heavy scans can amplify 9P I/O latency.

This document defines the target design (not a literal prompt), implementation expectations, and formal assurance behavior for the orchestration module.

## 2) Design Goals
- **Deterministic orchestration:** equivalent manifest inputs must produce equivalent command lines, policy payloads, and XML artifact paths.
- **Audit-only runtime posture:** no network discovery side effects.
- **In-process validation:** integrity and policy checks are performed by NSE scripts during scan execution.
- **Operational observability:** per-operation latency accounting is captured for forensic auditability.
- **Schema-compliant hand-off:** generated XML is validated against the IĀTŌ‑V7 audit schema before acceptance.

## 3) High-Level Architecture
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

### 3.1 Module Responsibilities
1. **Manifest Parser**
   - Parse TOML and normalize explicit path targets.
   - Reject unspecified defaults that can introduce nondeterminism.
2. **Policy Builder**
   - Emit a stable, sorted policy structure used by NSE scripts (hash, mode, owner/group constraints, integrity predicates).
3. **Command Planner**
   - Build a constrained Nmap command that always includes:
     - `-Pn -sn` (state isolation / host-discovery bypass)
     - `-oX <artifact>` (canonical machine-readable output)
     - explicit NSE script invocation and script-args
   - Derive timing template (`-T2`..`-T4`) from measured filesystem latency.
4. **Execution + Telemetry**
   - Run via `subprocess` or `asyncio`.
   - Track operation-level latency (manifest load, policy write, scan, XML validation).
5. **Verification Gate**
   - Parse XML status fields produced by NSE and enforce Clean/Dirty semantics.
   - Return non-zero exit on any policy deviation.

## 4) Deterministic Behavior Requirements
- **Stable ordering:** all configured paths and rules must be lexicographically sorted before policy serialization.
- **Stable artifact mapping:** XML output path is derived from a deterministic tuple:
  - `(manifest fingerprint, target root, schema version)`.
- **Stable invocation:** command argument order must be fixed.
- **Stable environment:** pin Nmap version and disallow mutable runtime options that alter scan semantics.

## 5) Nmap / NSE Contract
### 5.1 Mandatory Nmap Flags
- `-Pn -sn`: enforce local audit mode and skip ping/host discovery behavior.
- `-oX <path>`: emit canonical XML artifact.
- `--script <path_audit.nse>`: execute IĀTŌ‑V7 integrity checks in-process.
- `--script-args ...`: pass root path, policy file, schema version, project metadata.

### 5.2 NSE Script Duties
Custom Lua NSE scripts are authoritative for:
- cryptographic hash checks,
- ownership and permission checks,
- structural integrity predicates,
- producing machine-readable `Clean` or `Dirty` status in XML.

Any mismatch (hash, ACL/mode/ownership, forbidden mutation) must set a failing status consumable by the orchestrator.

## 6) Timing & I/O Strategy (WSL2/9P-Aware)
- Run a short, bounded I/O latency probe at startup (sample reads/stats on configured target paths).
- Map probe results to Nmap timing template:
  - low latency → `-T4`,
  - medium latency → `-T3`,
  - high latency / 9P contention → `-T2`.
- Never exceed bounded scan scope:
  - **no unbounded recursive DFS traversal**,
  - only explicit manifest target paths and rule entries.

## 7) Progress and Latency Telemetry
The orchestrator must asynchronously emit progress records with operation timestamps and durations, for example:
- `manifest.parse.ms`
- `policy.write.ms`
- `nmap.exec.ms`
- `xml.validate.ms`

Telemetry output should be append-only JSONL or structured logs suitable for later evidence packaging.

## 8) Verification and Exit Semantics
- **Exit code 0:** XML is schema-valid and NSE reports `Clean` for all evaluated targets.
- **Non-zero exit:** any of the following:
  - XML schema mismatch,
  - NSE-reported `Dirty` condition,
  - policy serialization or deterministic mapping failure,
  - orchestrator runtime failure (Nmap unavailable, malformed config, etc.).

## 9) Implementation Constraints
- **Language:** Python (`subprocess` or `asyncio`) or Go.
- **No external parser dependency at hand-off:** final decision should be made from canonical XML/NSE outputs without additional ad hoc transforms.
- **Environment priority:** minimize filesystem interrupts and metadata churn in WSL2/Minikube.

## 10) Reference Integration Path
A practical Python entrypoint is expected at:
- `lean/iato_v7/scripts/nmap_path_audit_orchestrator.py`

NSE policy logic is expected at:
- `lean/iato_v7/nse/path_audit.nse`

This design document defines the acceptance baseline for those components.

## 11) Acceptance Criteria
The orchestration layer is accepted when it demonstrably:
1. Converts a valid TOML manifest into a deterministic Nmap invocation.
2. Produces canonical XML via `-oX` and validates it against the IĀTŌ‑V7 schema.
3. Returns `Clean`/`Dirty` based on NSE in-process checks only.
4. Emits non-zero exit status for any integrity deviation.
5. Maintains bounded, explicit path scanning with latency-aware timing behavior.
