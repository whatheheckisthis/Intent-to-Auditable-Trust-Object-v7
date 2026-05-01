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



## IĀTŌ-V7 — Filesystem State Assurance Instantiation

>Bounded instantiation of the IĀTŌ assurance model defined as a schema constrained, state transformation system `S_in`, governed by a declared control schema `C` and operational context `O`. It computes a monotone evaluation `F: S → S` within a partially ordered state space.


## Execution Context

IĀTŌ-V7 is a container-native, POSIX-constrained, `CI`/`CD`-orchestrated execution system for deterministic filesystem state verification. Execution is defined over a prevalidated orchestration graph and operates as a stateless transformation of `S_in`.

The system does not implement or embed a conventional *(SDLC)* or *(MERN)* application lifecycle. No service runtime, persistent state, or internal initialisation mechanism is present. Execution is non-interactive and occurs solely within externally provisioned pipeline stages.

- Observable output is restricted to declared artefacts and `stdout`, both of which are schema-constrained and subject to validation. No additional output channels are permitted.

- Admissible implementations of the evaluator `F` are restricted to the AJIV equivalence class `[F]`, such that outputs are invariant-preserving, schema-conformant, and observationally equivalent at the `S_out` boundary.

- *SLSA Level 3+* supply chain: hermetic `CI`/`CD` pipeline, container image provenance, locked dependency closure resolved at build time, and integrity-verified build artefacts).
Supply chain integrity is further augmented via canary tokens embedded in artefact paths and pipeline outputs for tamper and exfiltration detection.



## Runtime 

| Property              | Constraint                                                          |
| --------------------- | ------------------------------------------------------------------- |
| Execution environment | Podman container (isolated, ephemeral)                              |
| Interface layer       | POSIX compliant shell (bash-driven orchestration)                   |
| System bootstrap      | None (no startup runtime, no service init layer)                    |
| State model           | Stateless between invocations; state exists only as `S_in` snapshot |
| Persistence           | None (no embedded DB, no SQLite, no local runtime store)            |
| Execution trigger     | CI/CD pipeline invocation (external orchestration only)             |


**Operational Constraints**

- No runtime initialisation or *“start-up”* phase exists.
- No dynamic dependency resolution at runtime.
- No interactive application lifecycle (system is batch-executed only).
- No embedded databases or local persistence layers are permitted.

- All dependencies must be resolved before execution - `CI`/`CD` pre-flight.
- Execution must succeed or fail within a single pass.

**Orchestration**

- Execution is script-driven, primarily via POSIX shell (bash)
- `CI`/`CD` system defines the execution externally
- All logic is resolved at orchestration, not runtime.
- Each invocation, container instantiation.
- No warm state, caching, or persistent runtime context exists.

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

*This invariant is the sole correctness criterion for v7. Any output that does not satisfy it is a verification failure.*


## 2. Execution Model

| Property              | Constraint                                                          |
| --------------------- | ------------------------------------------------------------------- |
| Filesystem access     | Read-only. Write operations are a hard fault.                       |
| Environment variables | `ENV := ∅`. denotes that the evaluation function defined over a closed state space  |
| Time dependency       | `Δt = 0`. Output is not a function of wall-clock time.             |
| Dynamic imports       | Disallowed. All module resolution is static and locked at `npm ci`. |
| Runtime inference     | Disallowed. Behaviour is fully declared in `manifest.toml` and `C`. |
| Side effects          | None permitted. `F` is a pure function over `S_in`, `C`, `O`.      |
| Schema validation     | Enforced before execution begins. Invalid input halts the pipeline. |

`evaluated_at` in `output.schema.json` carries the static sentinel value `"STATIC"`. It is not a timestamp. Its presence satisfies 

*The schema contract; it does not encode temporal state.*


## 3. Component Mapping

| Component          | Layer    | Role                                                           |
| --------------------- | ------------- | -------------------------------------------------------------- |
| `manifest.toml`       | Instantiation | Declares execution intent; schema-bound; static               |
| `runner.js`           | Instantiation | Implements `F(S_in, C, O)`; pure deterministic evaluator       |
| `v7.schema.json`      | Schema        | Input contract; defines valid `S_in` and `C` structure         |
| `scan.schema.json`    | Schema        | Filesystem scan output contract                                |
| `mapping.schema.json` | Schema        | File to control mapping contract                               |
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

>Schema files are relocated from `v7/*.schema.json` to `v7/schemas/` to match `Schema-root: v7/schemas/` declared in the module header. Update `runner.js` schema path arguments accordingly.



## 5. Constraint Enforcement

*The following constraints are declared in `manifest.toml` and enforced structurally by `runner.js`. They are not advisory.*

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

*All v7 outputs are immutable artefacts. Post-emission mutation invalidates the evidence chain.*

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

### 8.1 Execution Guarantees

| Principle              | Rule                                                                                     |
| ---------------------- | ---------------------------------------------------------------------------------------- |
| Determinism            | `F(S_in, C, O)` is evaluated deterministically against a schema-validated input snapshot |
| Cryptographic validity | `S_out` is only emitted if: `Verify(Sign_Ed25519(Hash_SHA256(F(S_in, C, O)))) == true`   |
| Immutability           | No filesystem state is modified during evaluation                                        |
| Context isolation      | No runtime factors (time, environment, dynamic resolution) affect output                 |



### 8.2 Hard Constraints 

| Area              | Constraint                                                           |
| ----------------- | -------------------------------------------------------------------- |
| Input integrity   | `S_in` must not be mutated; no filesystem path mutation allowed      |
| Schema compliance | Output must fully conform to `output.schema.json`                    |
| Execution control | Processing must halt immediately after any schema validation failure |
| Output strictness | No undeclared fields beyond `output.schema.json` are permitted       |



### 8.3 Failure Model

| Failure Type          | Condition                                           |
| --------------------- | --------------------------------------------------- |
| Input schema failure  | `S_in` does not satisfy input schema                |
| Output schema failure | `F` produces invalid `output.schema.json` structure |
| Cryptographic failure | Signing or hashing verification cannot complete     |



### 8.4 Failure Handling Pipeline

| Stage           | Behavior                                                          |
| --------------- | ----------------------------------------------------------------- |
| Halt            | Pipeline stops immediately upon failure                           |
| Promotion block | No artifact is promoted to Evidence layer                         |
| Audit logging   | `emit-failure.js` records failing stage for upstream traceability |

---

>This specification is under ongoing implementation. All behavior described herein is enforced as structural invariants rather than runtime heuristics. Mutation is strictly disallowed outside declared transition boundaries, as executed within a prevalidated directed acyclic graph (DAG).

*The system is interpreted under formal methods alignment, including:*

- Order-theoretic abstractions over state transitions
- Lattice semantics for partial ordering of execution states
- Galois connections between specification space and execution space
- Fixed-point semantics for stabilised evaluation under constraint closure
- Non-interference / relational equivalence for isolation guarantees
schema-constrained state systems governing all admissible transitions

*AJIV (Assumed Justified Implementation Variance)* 
- Defines the admissible equivalence class over implementations of the evaluator `F`, such that all members preserve invariant satisfaction and are observationally indistinguishable at the boundary of `S_out`.

*All execution paths are therefore treated as monotone, bounded transformations over a constrained state lattice, with validation enforcing closure properties prior to any observable emission.*

