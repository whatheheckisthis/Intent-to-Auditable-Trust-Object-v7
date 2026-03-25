# Intent-to-Auditable-Trust-Object (IĀTŌ-V7)

Terminal-native host-path auditing. Reproducible XML artefacts. Traceable JBoss EAP 7 migration for SOC environments.

[![Build](https://img.shields.io/badge/build-passing-brightgreen)](lean/iato_v7/lakefile.lean)
[![Essential%208](https://img.shields.io/badge/Essential%208-ML4-blue)](docs/cyber-risk-controls.md)
[![SOC2](https://img.shields.io/badge/SOC2-CC6.1%20%7C%20CC6.6-orange)](docs/ARCHITECTURE.md)
[![ISM](https://img.shields.io/badge/ISM-0457--0460-green)](docs/threat-model.md)

---

## What This Is

IĀTŌ-V7 is a fixed-scope uplift tool. It closes a defined gap — the absence of deterministic, auditable filesystem evidence — in environments migrating legacy JBoss EAP 7 workers toward Essential Eight ML4 and ISM compliance posture.

It does not ship features. It does not accumulate abstractions. Each engagement produces three artefacts, each directly mapped to a control objective, and nothing else. The measure of maturity here is not capability surface — it is the reduction of unverified assumptions between declared intent and observed state.

Simplicity is load-bearing. Every layer that cannot be traced to a control mapping is a liability, not an asset.

---

## Delivery Artefacts

Each artefact is versioned, schema-validated, and repository-linked before hand-off.

### 1. Canonical XML Audit Artefact

Deterministic, schema-validated XML produced per scan run. Captures observed filesystem state against declared intent. Exits `0` on Clean, non-zero on any deviation. Ready for direct submission as compliance evidence.

**Output:** `lean/iato_v7/nmap-path-state.xml`

| Framework | Control | Basis |
|---|---|---|
| SOC 2 | `CC6.1` | Observed state verified against declared control posture |
| SOC 2 | `CC6.6` | Per-path ownership and mode verification as access restriction evidence |
| SOC 2 | `PI1.3` | Deterministic output confirms consistent, auditable processing |
| ISM | `0457` | Privileged boundary and worker domain isolation assurance |
| ISM | `0458` | Administrative separation enforced at migration execution boundary |
| Essential Eight ML4 | Application Control | Binary and configuration state verified before worker promotion |

---

### 2. TOML Manifest (Declared-Intent Register)

Versioned, machine-readable declaration of expected filesystem state: paths, hash expectations, ownership, mode. The source-of-truth input to every scan. Evidence that intent was defined before execution — not reconstructed after the fact.

**Output:** `config.local.toml` — schema-governed, machine-local, not version-controlled

| Framework | Control | Basis |
|---|---|---|
| SOC 2 | `CC2.1` | Structured information supporting internal control |
| SOC 2 | `CC8.1` | Promotion proceeds only after manifest-defined intent is verified |
| ISM | `0038` | Security documentation maintained and accessible to relevant personnel |
| Essential Eight ML4 | — | Control objectives documented and independently verifiable |
| NIST SSDF | `PO.5` | Supporting tooling enforces declared state before execution |

---

### 3. MCP Orchestration Log

Append-only JSONL produced per session. Each entry carries timestamp, script version hash, command chain, exit state, and deviation flag. The audit trail for every administrative action taken during a scan run.

**Format:** `timestamp | script_version_hash | command_chain | exit_state | deviation_flag`

| Framework | Control | Basis |
|---|---|---|
| SOC 2 | `CC7.2` | Per-operation audit trail for system component monitoring |
| SOC 2 | `CC7.3` | Timestamped command records as security event evidence |
| ISM | `0582` | Audit logs maintained for all administrative actions |
| Essential Eight ML4 | — | Logging sufficient to reconstruct events and support independent audit |

---

## Architecture

```text
config.toml
   │
   ▼
Manifest Parser ──► Policy Builder ──► Command Planner
                                            │
                                            ▼
                                   Nmap + NSE Scripts
                                            │
                                            ▼
                                   Canonical XML (-oX)
                                            │
                                            ▼
                                   Schema Verification
                                            │
                                            ▼
                                   Clean/Dirty + Exit Code
```

| Component | Role |
|---|---|
| **TOML Manifest** | Declared-intent register |
| **Nmap** | Stateless, high-concurrency scan orchestrator |
| **NSE Scripts** | In-process hash, ACL, ownership, and integrity validation |
| **XML Artefact** | Schema-validated compliance evidence |
| **MCP Log** | Append-only administrative audit trail |

**Design constraints** — not aspirational, load-bearing:

- Equivalent manifest inputs produce equivalent command lines, policy payloads, and artefact paths. Always.
- No network discovery side effects. Audit-only runtime posture.
- Integrity checks run in-process during scan execution. No post-hoc reconciliation.
- No abstractions that cannot be traced to a control mapping. Complexity that cannot be audited is technical debt disguised as architecture.

---

## Compliance Coverage

| Framework | Controls | Artefacts |
|---|---|---|
| Essential Eight ML4 | Privilege separation, application control, patch governance | 1, 2 |
| SOC 2 TSC | `CC2.1`, `CC6.1`, `CC6.6`, `CC7.2`, `CC7.3`, `CC8.1`, `PI1.3` | 1, 2, 3 |
| ISM (ASD) | `0038`, `0457`–`0460`, `0582` | 1, 2, 3 |
| NIST SSDF | `PO.5`, `PW.4`, `RV.1` | 1, 2 |

---

## Quick Start (Linux)

**Run:** `iato scan --config config.local.toml`  
**Output:** `lean/iato_v7/nmap-path-state.xml` + `lean/iato_v7/mcp-orchestration.jsonl`  
**Exit:** `0 = Clean`, non-zero = Dirty or error

### Setup

```bash
# Clone
git clone https://github.com/<whatheheckisthis>/Intent-to-Auditable-Trust-Object.git
cd Intent-to-Auditable-Trust-Object

# Dependencies
sudo apt update && sudo apt install -y git curl python3 python3-pip build-essential

# Lean toolchain
./scripts/install-formal-verification-deps.sh
./scripts/setup-lean-ci-deps.sh

# Build and validate
cd lean/iato_v7 && lake test && cd ../..
python3 scripts/scan_workers.py data/legacy_workers.csv
./scripts/lake_build.sh

# Alias
alias iato='./bin/iato'
echo "alias iato='./bin/iato'" >> ~/.bashrc
source ~/.bashrc
```

### Configure

> `config.local.toml` is machine-local declared intent. Do not commit. Do not transmit path or hash material externally — doing so weakens evidence integrity.

```bash
cat > config.local.toml <<EOF
schema_version = "1.0.0"
project = "iato-v7"
release = "local"

[audit]
root_path = "/"
target = "127.0.0.1"
fail_on_deviation = true

[artifacts]
xml_output = "lean/iato_v7/nmap-path-state.xml"
policy_output = "lean/iato_v7/.nmap-path-policy.json"
log_output = "lean/iato_v7/mcp-orchestration.jsonl"

[[targets]]
id = "jboss-service-unit"
path = "/etc/systemd/system/jboss.service"
required = true
sha256 = "<replace_with_sha256sum_output>"
owner = "root"
group = "root"
mode = "0644"
EOF
```

Compute hashes locally before any scan run:

```bash
# Single file
sha256sum /etc/systemd/system/jboss.service

# Directory (deterministic recursive)
find /path/to/dir -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum
```

### Run

```bash
iato scan --config config.local.toml --dry-run   # Preview command only
iato scan --config config.local.toml             # Produce artefacts
echo $?                                           # 0 = Clean
```

---

## Non-Goals

- **NG-001:** Not a replacement for a full organisational SDLC or security programme.
- **NG-002:** Not a runtime hardening guarantee across all environments.
- **NG-003:** Not formal verification of third-party or external system behaviour.
- **NG-004:** Not automatic compliance attestation — organisation-specific controls and evidence are required.
- **NG-005:** Not affiliated with or endorsed by Common Criteria.

---

*Cross-reference: `docs/ARCHITECTURE.md` — system invariants and design rationale*  
*Cross-reference: `docs/WORKER_COMPAT.md` — audit and implementation narrative*  
*Cross-reference: `docs/cyber-risk-controls.md` — Essential Eight control coverage*
