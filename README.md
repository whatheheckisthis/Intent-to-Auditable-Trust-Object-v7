<!--
Module      : IĀTŌ-V7
Path        : v7/README.md
Type        : Instantiation Layer
Parent      : IĀTŌ Security Controls Index
Layer       : Instantiation
Frameworks  : ISO 27001 A.12.1, NIST SP 800-53 CM-6, SOC 2 CC6.1
Invariant   : S_out := Verify(Sign_Ed25519(Hash_SHA256(F(S_in, C, O))))
Scope       : Filesystem state verification — read-only, deterministic, schema-bound
Binding     : Receives S_in from Orchestration layer; emits S_out to Evidence layer
Modified    : 2026-04-29T00:00:00Z
Schema-root : v7/schemas/
-->

# IĀTŌ-V7 — Filesystem State Assurance Instantiation

>v7 is a bounded instantiation of the IĀTŌ execution model applied to filesystem-state evaluation. It receives a filesystem snapshot `S_in` from the Orchestration layer, applies a deterministic evaluation function `F` parameterised by control schema `C` and operational context `O`, and emits a signed, hash-bound evidence artefact `S_out` to the Evidence layer. All behaviour is declared in `manifest.toml` and enforced by schema before execution. No runtime inference occurs. An orchestrator, a policy engine, a runtime monitor, or a general-purpose scanner. It does not write to the filesystem, resolve dynamic imports, accept environment variables, or produce outputs that are not schema-validated. It does not interpret control definitions — it applies them as supplied by the parent Orchestration layer.

---

## 1. Invariant

```
S_out := Verify(Sign_Ed25519(Hash_SHA256(F(S_in, C, O))))
```

| Symbol   | Definition                                                              |
| -------- | ----------------------------------------------------------------------- |
| `S_in`   | Immutable filesystem snapshot received from Orchestration layer         |
| `C`      | Control schema (`v7.schema.json`) — defines evaluation contract         |
| `O`      | Operational context declared in `manifest.toml` — static, pre-declared  |
| `F`      | Deterministic evaluator (`runner.js`) — pure function, no side effects  |
| `S_out`  | Signed, hash-bound evidence artefact emitted to Evidence layer          |

This invariant is the sole correctness criterion for v7. Any output that does not satisfy it is a verification failure.

---

## 2. Execution Model

| Property              | Constraint                                                          |
| --------------------- | ------------------------------------------------------------------- |
| Filesystem access     | Read-only. Write operations are a hard fault.                       |
| Environment variables | `ENV := ∅`. No environment variable is read or injected at runtime. |
| Time dependency       | `Δt = 0`. Output is not a function of wall-clock time.             |
| Dynamic imports       | Disallowed. All module resolution is static and locked at `npm ci`. |
| Runtime inference     | Disallowed. Behaviour is fully declared in `manifest.toml` and `C`. |
| Side effects          | None permitted. `F` is a pure function over `S_in`, `C`, `O`.      |
| Schema validation     | Enforced before execution begins. Invalid input halts the pipeline. |

`evaluated_at` in `output.schema.json` carries the static sentinel value `"STATIC"`. It is not a timestamp. Its presence satisfies the schema contract; it does not encode temporal state.



## 3. Component Mapping

| Component          | Layer    | Role                                                           |
| --------------------- | ------------- | -------------------------------------------------------------- |
| `manifest.toml`       | Instantiation | Declares execution intent; schema-bound; static               |
| `runner.js`           | Instantiation | Implements `F(S_in, C, O)`; pure deterministic evaluator       |
| `v7.schema.json`      | Schema        | Input contract; defines valid `S_in` and `C` structure         |
| `scan.schema.json`    | Schema        | Filesystem scan output contract                                |
| `mapping.schema.json` | Schema        | File-to-control mapping contract                               |
| `output.schema.json`  | Schema        | `S_out` evidence artefact contract                             |
| `pipeline.binding.json` | Orchestration | DAG binding; declares upstream/downstream stage relationships |
| `v7-scan.json`        | Evidence      | Emitted artefact; SHA-256 bound; Ed25519 signed                |

**Gate behaviour:**

| Gate                    | Failure action                                  |
| ----------------------- | ----------------------------------------------- |
| Input schema invalid    | Hard halt. The pipeline does not proceed.           |
| Evaluator non-zero exit | Hard halt. No output artefact is emitted.       |
| Output schema invalid   | Hard halt. Artefact is discarded.               |
| SHA-256 mismatch        | Hard halt. The evidence bundle is not signed.       |
| Any prior gate failed   | `emit-failure.js` records stage; pipeline exits.|



## 4. Scaffold

```
v7/
├── manifest. toml           # Declared execution intent (schema-bound, static)
├── runner.js               # Deterministic evaluator: F(S_in, C, O)
├── pipeline.binding.json   # DAG binding to parent Orchestration layer
└── schemas/
    ├── v7.schema.json      # Instantiation input contract
    ├── scan.schema.json    # Filesystem scan output contract
    ├── mapping.schema.json # File-to-control mapping contract
    └── output.schema.json  # S_out evidence artefact contract
```

> Schema files are relocated from `v7/*.schema.json` to `v7/schemas/` to match `Schema-root: v7/schemas/` declared in the module header. Update `runner.js` schema path arguments accordingly.



## 5. Constraint Enforcement

The following constraints are declared in `manifest.toml` and enforced structurally by `runner.js`. They are not advisory.

```toml
module            = "IĀTŌ-V7"
type              = "filesystem-instantiation"
mode              = "read-only-assurance"
invariant         = "S_out := Verify(Sign_Ed25519(Hash_SHA256(F(S_in, C, O))))"
scope             = "filesystem-state-verification"
execution         = "deterministic"
mutation          = "disallowed"
environment       = "stripped"
time_dependency   = false
dynamic_imports   = false
schema_validation = "pre-execution"
```

`runner.js` must enforce:

1. Schema validation of `S_in` against `v7.schema.json` before any evaluation begins.
2. No `process.env` access. No `Date`, `Math.random()`, or any non-deterministic primitive.
3. No `require()` or `import()` calls beyond the static dependency closure resolved by `npm ci`.
4. `fs` access restricted to read operations. Any write outside the declared output path is a fault.
5. Exit code `0` only on full invariant satisfaction. Any partial output state exists non-zero.



## 6. Output Model

All v7 outputs are immutable artefacts. Post-emission mutation invalidates the evidence chain.

| Property           | Mechanism                                                       |
| ------------------ | --------------------------------------------------------------- |
| Content binding    | SHA-256 digest of `v7-scan.json` written to `v7-scan.sha256`   |
| Authenticity       | Ed25519 signature over `v7-scan.json` written to `v7-scan.sig` |
| Schema conformance | Output validated against `output.schema.json` before signing   |
| CI provenance      | GitHub Actions run ID and commit SHA embedded in pipeline stage |
| Append-only        | Evidence directory is write-once per pipeline run; no overwrite |

`output.schema.json` enforces `additionalProperties: false`. Any field not declared in the schema is a schema violation, and the artefact is discarded.



## 7. Architecture 

<img width="1440" height="2258" alt="image" src="https://github.com/user-attachments/assets/fd0a485e-957a-42da-b037-ce38fdf35429" />



## 8. Boundary 

**Guarantees:**
- `F(S_in, C, O)` is evaluated deterministically against a schema-validated input snapshot.
- `S_out` satisfies `S_out := Verify(Sign_Ed25519(Hash_SHA256(F(S_in, C, O))))` or is not emitted.
- No filesystem state is modified during evaluation.
- No runtime context (environment, time, dynamic resolution) influences output.

**Forbids:**
- Mutation of `S_in` or any filesystem path during evaluation.
- Emission of `S_out` that does not pass `output.schema.json` validation.
- Execution that proceeds past a schema validation failure.
- Any output field not declared in `output.schema.json`.

**Failure:**

Failure means one of three conditions holds: `S_in` did not satisfy the input schema; `F` produced output that did not satisfy `output.schema.json`; or the cryptographic binding step could not be completed. In all three cases, the pipeline halts, no artefact is promoted to the Evidence layer, and `emit-failure.js` records the failing stage for upstream audit.


**Assumptions:** 

- Pipeline stage ordering (`needs: [orchestration-snapshot-emit]`) is inferred from `pipeline.binding.json`. Confirm the upstream stage name.
- Layer names (Index, Schema, Orchestration, Instantiation, Evidence) are inferred from the v7 spec. Confirm these match your canonical IĀTŌ index labels.
- `pipeline/sign-ed25519.js` is assumed to exist in the parent pipeline. If absent, the cryptographic binding step must be implemented.
- `v7/schemas/` relocation from `v7/.schema.json` is a structural correction for `Schema-root` consistency. Confirm no other modules reference the flat path.
