# ARM Execution Correctness Architecture — ARMv8.5-A / ARMv9.2-A / Azure Cobalt

>This repository operates within an ARM virtualisation and execution correctness context targeting Azure Cobalt-class Neoverse infrastructure. The system is grounded in EL2-controlled execution, Stage-2 MMU enforcement, SVE2 register-file semantics, and QEMU/KVM architectural projection under adversarial microarchitectural assumptions.


## Global System 

All subsystems compose into a single global execution state:

```
S = ⟨S_EL2, S_Stage2, S_SVE2, S_QEMU, S_KVM⟩
```

Each component state is formally bounded. No component state is inferred, defaulted, or implicitly carried across VM entry/exit boundaries. Transitions between components are explicit, schema-driven, and verifiable against hardware register state at each boundary crossing.

---

## 1. ARM EL2 Hypervisor 

**EL2 is not trusted. It is a constrained enforcement layer.**

`HCR_EL2` is the primary control register governing the hypervisor execution domain. It determines trap routing, guest memory access policy, and the execution context boundary between EL1 and EL2. The following bit-field assignments are enforced as invariants:

| Field | Value | Constraint |
|---|---|---|
| `HCR_EL2.VM` | 1 | Stage-2 translation active; mandatory for isolation correctness |
| `HCR_EL2.RW` | 1 | EL1 executes AArch64; AArch32 guest execution not permitted |
| `HCR_EL2.TSC` | 1 | SMC instructions trap to EL2; EL1 cannot invoke secure monitor directly |
| `HCR_EL2.TWI` / `TWE` | conditional | WFI/WFE trap policy set per VCPU scheduling constraints |
| `HCR_EL2.TGE` | 0 | Guest OS retains EL1 execution; TGE=1 is not a valid configuration here |
| `HCR_EL2.VSE` | controlled | Virtual SError injection under explicit EL2 orchestration only |

EL2 save/restore obligations at VM exit are unconditional. The following EL2-owned register state is saved before returning to host EL1:

- `HCR_EL2`, `VTTBR_EL2`, `VTCR_EL2`
- `SCTLR_EL2`, `TCR_EL2`, `MAIR_EL2`
- `SPSR_EL2`, `ELR_EL2`, `SP_EL2`
- `DAIF` masking state — interrupt mask bits are restored atomically; partial restoration is not permitted
- SVE context (see §3)

`DAIF` masking policy: IRQ, FIQ, SError, and Debug exception masking must be coherent across the EL2→EL1 transition. DAIF bits are captured at VM exit and restored before re-entering the guest. No path through the hypervisor may leave DAIF in a partially masked state upon EL1 re-entry.

---

## 2. Stage-2 Memory Isolation 

**Stage-2 MMU does not provide protection. It is enforced isolation.**

Stage-2 translation produces a mandatory second-stage address mapping layered beneath EL1's own page tables. The mapping is:

```
IPA → PA
```

Intermediate Physical Addresses (IPA) produced by EL1 page-table walks are re-translated by the Stage-2 MMU before any physical memory access occurs. EL1 has no visibility into the IPA→PA mapping and cannot modify it.

### `VTTBR_EL2` and `VTCR_EL2`

`VTTBR_EL2` holds the base address of the Stage-2 translation table and the VMID. The VMID distinguishes TLB entries belonging to different virtual machines. VMID correctness is a strict requirement: TLB entries from one VM must not be visible to another. VMID width (8-bit or 16-bit) is determined by `VTCR_EL2.VS`.

`VTCR_EL2` encodes the Stage-2 table walk parameters:

| Field | Constraint |
|---|---|
| `VTCR_EL2.T0SZ` | IPA space size; must match guest RAM layout |
| `VTCR_EL2.SL0` | Starting level of Stage-2 walk; determined by T0SZ |
| `VTCR_EL2.IRGN0`, `ORGN0` | Inner/outer cacheability of Stage-2 walks |
| `VTCR_EL2.SH0` | Shareability domain for Stage-2 table walks |
| `VTCR_EL2.PS` | Physical address size; must match host PA range |
| `VTCR_EL2.VS` | VMID size (0=8-bit, 1=16-bit) |

### Isolation Invariants

- A guest IPA that does not map to a valid Stage-2 PTE raises a Stage-2 translation fault, routed to EL2.
- No EL1 instruction may modify `VTTBR_EL2` or `VTCR_EL2`; attempts trap unconditionally.
- Memory-mapped device regions exposed to guests are backed by Stage-2 device-type mappings (`nGnRE` or `nGnRnE`); no guest IPA range receives Normal memory attributes for device MMIO.
- Inter-VM IPA aliasing is not permitted. VMID uniqueness is a prerequisite for correctness; VMID reuse without TLB invalidation (`VMALLS12E1IS`) is a fault condition, not a race.

---

## 3. SVE2 Vector Execution 

**SVE2 is not a performance. It is deterministic vector-state execution.**

### Feature Detection

SVE2 availability is verified against hardware capability registers before any SVE2 execution path is permitted:

```
ID_AA64PFR0_EL1.SVE  ≠ 0b0000  →  SVE present
ID_AA64ZFR0_EL1.SVEver == 0b0001  →  SVE2 confirmed
```

KVM capability check:

```
KVM_CAP_ARM_SVE  →  kernel SVE virtualisation support present
```

These checks are performed at VCPU creation time. A VCPU configured for SVE2 execution on a host that does not satisfy both conditions is a configuration fault; the VCPU is not created.

### SVE2 Register 

```
S_SVE2 = ⟨Z₀..₃₁, P₀..₁₅, FFR, VL⟩
```

| Component | Description |
|---|---|
| `Z₀..Z₃₁` | 32 vector registers, each VL bits wide |
| `P₀..P₁₅` | 16 predicate registers, each VL/8 bits wide |
| `FFR` | First-Fault Register, VL/8 bits, governs fault-first load semantics |
| `VL` | Vector Length in bits; must be a power-of-two multiple of 128, range [128, 2048] |

### VL Negotiation Invariance

VL is negotiated once at VCPU creation via `KVM_SET_ONE_REG` targeting `KVM_REG_ARM64_SVE_VLS`. Once set, VL is invariant for the lifetime of the VCPU. VL changes mid-execution are not permitted; any attempt to alter VL after the VCPU has entered the running state is a lifecycle violation (see §5).

`RDVL` behavioural correctness: `RDVL Xn, #1` executed in the guest must return the negotiated VL / 8 (bytes). The value returned must equal the VL advertised at VCPU creation. Divergence between the RDVL-observed VL and the configured VL is a correctness fault.

### SVE2 Context Save/Restore

`SVE_SAVE_EXTRA` ordering is mandatory. The save sequence is:

1. `Z₀..Z₃₁` — full VL-width vector register save
2. `P₀..P₁₅` — predicate register save
3. `FFR` — saved last; FFR is dependent on predicate state and must not be saved before predicates are stable

Restore proceeds in reverse order: FFR restored first is an ordering violation. The save area is allocated at VCPU creation time sized to `(32 × VL/8) + (16 × VL/64) + (VL/64)` bytes.

`ZCR_EL2` is set by EL2 to enforce the fixed VL: `ZCR_EL2.LEN = (VL/128) - 1`. Guest attempts to alter effective VL through `ZCR_EL1` are constrained by EL2's `ZCR_EL2.LEN` — the effective VL is `min(ZCR_EL1.LEN, ZCR_EL2.LEN)`.

---

## 4. QEMU Architecture

**QEMU is not an emulator. It is a bounded architectural projection.**

### Projection Constraint

```
Σ_host ∩ Σ_guest → Σ_stable
```

`Σ_host` is the feature set of the physical Neoverse substrate (N2 or V3). `Σ_guest` is the feature set requested by the guest VM configuration. `Σ_stable` is the intersection: the set of features that are simultaneously present on the host, exposed to the guest, and guaranteed to behave identically across all valid host substrates in the target fleet.

Features present in `Σ_host \ Σ_stable` are masked from the guest. Features in `Σ_guest \ Σ_host` are rejected at VCPU creation time; they are not emulated.

### Feature Masking via ID Registers

QEMU enforces `Σ_stable` by controlling the values returned by guest reads of ID registers:

- `ID_AA64PFR0_EL1` — controls SVE, GIC, RAS, and DIT field exposure
- `ID_AA64ZFR0_EL1` — controls SVE2, SHA3, SM4, F32MM, F64MM feature exposure
- `ID_AA64ISAR1_EL1` — controls PAC algorithm field (QARMA5 / QARMA3 / implementation-defined)
- `ID_AA64PFR1_EL1` — controls MTE, SSBS, BT, RNDS field exposure

Any ID register field that is not in `Σ_stable` is returned as 0b0000 to the guest. A guest that behaves differently when a feature field is zero versus absent must not rely on fields outside `Σ_stable`.

### Heterogeneous Neoverse Substrate Handling

| Substrate | ARM Version | Microarchitecture | Key `Σ` host Additions |
|---|---|---|---|
| Azure Cobalt 100 | ARMv8.5-A | Neoverse N2 | SVE2 (256-bit), MTE, PAC (QARMA5), BRBE |
| Azure Cobalt 200 | ARMv9.2-A | Neoverse V3 | SVE2 (512-bit), PAC (QARMA3), RME/CCA, MTE3 |

`Σ_stable` is computed as the intersection across all target substrates in the deployment fleet. A feature present only on V3 (e.g., QARMA3 PAC, Realm Management Extension) is excluded from `Σ_stable` unless the fleet is V3-homogeneous.

---

## 5. KVM VCPU Lifecycle 

### VCPU State Machine

```
S_VCPU = ⟨created, configured, running, vmexit, migrating, destroyed⟩
```

```
created      →  configured   :  KVM_SET_ONE_REG applied; feature negotiation complete
configured   →  running      :  KVM_RUN issued; VM entry executed
running      →  vmexit       :  trap, fault, interrupt, or HVC causes exit
vmexit       →  running      :  exit reason handled; KVM_RUN reissued
vmexit       →  migrating    :  VCPU state serialised for live migration
migrating    →  configured   :  VCPU state deserialised on target host
configured   →  destroyed    :  VCPU fd closed; all associated state freed
```

State transitions not listed above are illegal. A VCPU in `running` state cannot transition directly to `migrating`; it must first exit to `vmexit`. A VCPU in `destroyed` state has no valid transitions.

### VM Entry / Exit Correctness

VM entry (`KVM_RUN`) requires that all of the following are true:

- `HCR_EL2.VM == 1`
- `VTTBR_EL2` points to a valid, VMID-tagged Stage-2 table
- `VTCR_EL2` fields are consistent with the IPA space size
- SVE context is fully saved from a prior exit or zero-initialised on first entry
- DAIF state is coherent with the interrupt routing policy

VM exits the exit reason in `kvm_run->exit_reason`. Exit reasons map to specific architectural events:

| Exit Reason | Architectural Cause |
|---|---|
| `KVM_EXIT_MMIO` | Stage-2 fault on device MMIO IPA |
| `KVM_EXIT_HVC` | Guest HVC instruction; hypercall dispatch |
| `KVM_EXIT_SYSTEM_EVENT` | PSCI call or system reset |
| `KVM_EXIT_IRQ` | Virtual IRQ injection acknowledgement |
| `KVM_EXIT_EXCEPTION` | Unhandled synchronous exception |

Each exit is handled atomically with respect to VCPU state. Partial exit handling — where some register state is consumed but a response is not issued — is a correctness violation.

---

## 6. Microarchitecture

**Correctness includes non-observability under microarchitectural side channels.**

### Threat Model

The microarchitectural threat model covers speculative execution attacks that violate the isolation guarantees enforced by EL2 Stage-2 translation and VCPU scheduling. The following attack classes are in scope:

**Spectre (branch predictor leakage)**
- Spectre-v1 (bounds-check bypass): speculative load of out-of-bounds address populates cache lines in attacker-observable state.
- Spectre-v2 (branch target injection): attacker poisons the Branch Target Buffer (BTB) or indirect branch predictor to redirect speculative execution into a gadget within EL2 or a co-scheduled VCPU's EL1 context.
- Spectre-BHB (Branch History Buffer): attacker-controlled BHB history influences branch predictor state in EL2; relevant on Neoverse N2 and V3.

**Meltdown (privilege boundary violation)**
- Speculative reads of EL2-mapped memory from EL1 context before permission checks complete. Mitigated by KPTI (Kernel Page-Table Isolation) equivalent at EL2; EL1 page tables do not contain EL2 mappings.

**Cache timing attacks**
- Prime+Probe and Flush+Reload attacks on shared LLC partitions between VCPUs. Neoverse N2/V3 LLC is not partitioned per VMID; co-residency assumptions must not be used as isolation guarantees.

**Branch predictor leakage at EL2 context switch**
- BTB, RSB (Return Stack Buffer), and BHB state are VCPU local in intent but not guaranteed to be architecturally flushed across EL2 context switches without explicit mitigation.

### Mitigation Constraints

| Threat | Mitigation | Register/Mechanism |
|---|---|---|
| Spectre-v2 / BHB | CSV2 / FEAT_CSV2_2 enforcement; `CLEARBHB` on EL2 entry | `ID_AA64PFR0_EL1.CSV2` |
| Spectre-v2 (EL2 indirect branches) | EL2 retpoline or `FEAT_BTI` enforcement | `SCTLR_EL2.BT` |
| Meltdown | EL1 page tables contain no EL2 mappings; enforced by KVM | Stage-2 table structure |
| Cache timing | vCPU pinning policy; co-residency constraints declared | Scheduling invariant |
| RSB underflow | RSB stuffing on EL2 entry | EL2 entry path |

Non-interference is a system-level property, not a per-component property. A correctness claim that holds at the architectural level (Stage-2 isolation) but fails at the microarchitectural level (cache timing leakage) is not a correctness claim.

### BRBE Obligations

Branch Record Buffer Extension (BRBE) is present on Neoverse N2 (ARMv8.5-A, `FEAT_BRBE`). BRBE records branch history in a ring buffer accessible at EL1. EL2 must ensure:

- `BRBIDR0_EL1` fields are not used to infer EL2 execution paths from guest context.
- BRBE is disabled (`BRBCR_EL1.E0BRE == 0`, `BRBCR_EL1.EXCEPTION == 0`) before VM entry if the guest is not explicitly permitted BRBE access.
- BRBE state is not shared across VCPU boundaries; it is either flushed or contextually isolated at each VM exit.

---

## 7. Azure Cobalt Infrastructure Constraints

### Azure Cobalt 100 — Neoverse N2 / ARMv8.5-A

Relevant ISA extensions present on this substrate:

| Feature | Register Field | Constraint |
|---|---|---|
| SVE2 (256-bit max VL) | `ID_AA64ZFR0_EL1.SVEver = 0b0001` | VL negotiation must not exceed 256 bits on N2 |
| MTE (Memory Tagging Extension) | `ID_AA64PFR1_EL1.MTE = 0b0011` | MTE save/restore required at VM exit if guest MTE enabled |
| PAC (QARMA5) | `ID_AA64ISAR1_EL1.APA = 0b0001` | QARMA5 pointer authentication; key registers EL2-owned |
| BRBE | `ID_AA64DFR0_EL1.BRBE ≠ 0` | Branch records must be isolated across the VCPU boundary |
| FEAT_CSV2_2 | `ID_AA64PFR0_EL1.CSV2 = 0b0010` | Hardware Spectre-v2 BHB mitigation present |

**Azure Boost datapath implications**: Azure Boost offloads NVMe and network I/O from the CPU. Device MMIO regions for Azure Boost-attached devices are mapped into Stage-2 as device-type (`nGnRE`) with no Normal-memory cacheable mappings. Guest DMA to Azure Boost paths does not bypass Stage-2; IOMMU-equivalent constraints are enforced at the platform level, not by the guest OS.

### Azure Cobalt 200 — Neoverse V3 / ARMv9.2-A

| Feature | Register Field | Constraint |
|---|---|---|
| SVE2 (512-bit max VL) | `ID_AA64ZFR0_EL1.SVEver = 0b0001` | VL negotiation may target up to 512 bits on V3 |
| PAC (QARMA3) | `ID_AA64ISAR2_EL1.APA3 = 0b0001` | QARMA3 replaces QARMA5; key register layout differs |
| MTE3 | `ID_AA64PFR1_EL1.MTE = 0b0100` | MTE3 adds asymmetric tagging; save/restore path must handle MTE3 tag storage extension |
| RME / CCA | `ID_AA64PFR0_EL1.RME ≠ 0` | Realm Management Extension present; EL3 Realm dispatcher active |
| FEAT_BTI | `ID_AA64PFR1_EL1.BT ≠ 0` | Branch Target Identification; EL2 indirect branches must respect BTI landing pads |

### PAC QARMA3 Transition Impacts

Cobalt 200 (V3) uses QARMA3 as the pointer authentication cipher. QARMA3 produces different PAC field values for the same key and pointer than QARMA5. Binaries that assume QARMA5 cipher properties — or that compare raw PAC fields across heterogeneous hosts — are incorrect on V3. Key registers (`APDAKey_EL1`, `APIAKey_EL1`, etc.) are EL2-owned and saved/restored at VM exit; the cipher algorithm is host-determined and is not negotiable by the guest.

### MTE3 Save/Restore Correctness

MTE3 introduces asymmetric tag checking (`FEAT_MTE_ASYM_FAULT`). The tag storage region is extended relative to MTE2. Save/restore at VM exit must account for:

- `TFSRE0_EL1` and `TFSR_EL1` — Tag Fault Status Registers, saved as part of EL1 state
- MTE tag memory region — physically separate from data pages; must be included in VCPU migration payload
- `SCTLR_EL1.TCF` / `TCF0` — tag checking fault mode; must be saved and restored coherently with tag memory state

An MTE3-enabled VCPU migrated to a host that does not support `FEAT_MTE_ASYM_FAULT` is a configuration fault; migration is rejected.

### Realm/CCA Trust-Domain Expansion

Cobalt 200 hosts with RME enabled operate a four-level privilege model: EL3 (Root), EL2 (Secure/Normal Hypervisor), Realm EL1/EL0, and Normal EL1/EL0. This repository operates in the Normal world; the Realm Management Monitor (RMM) at Realm EL2 is not modified by this work. However, the following constraints apply:

- Stage-2 mappings for Normal-world guests may not alias Realm Physical Address Space (PAS) ranges.
- `VTTBR_EL2` in the Normal world cannot reference Realm or Secure PAS; physical address space partitioning is enforced by the Granule Protection Table (GPT) maintained by EL3.
- RME-aware QEMU must not project `ID_AA64PFR0_EL1.RME` into `Σ_stable` unless the entire fleet is V3 and the guest is explicitly configured for Realm workloads.

---

## 8. Execution Correctness Model

**A formalised state view.**

### Composed State

```
S = ⟨S_EL2, S_Stage2, S_SVE2, S_QEMU, S_KVM⟩

S_EL2     = ⟨HCR_EL2, VTTBR_EL2, VTCR_EL2, DAIF, ELR_EL2, SPSR_EL2⟩
S_Stage2  = ⟨VMID, IPA→PA_table, fault_log⟩
S_SVE2    = ⟨Z₀..₃₁, P₀..₁₅, FFR, VL⟩
S_QEMU    = ⟨Σ_stable, ID_reg_mask, VCPU_cfg⟩
S_KVM     = ⟨S_VCPU, exit_reason, run_state⟩
```

### Invariants

The following invariants must hold at all times. A state `S` in which any invariant is false is an error state; execution is halted, not continued.

```
I₁:  HCR_EL2.VM = 1                              ∀ VCPUs in {running, vmexit}
I₂:  VTCR_EL2.PS ≥ host_pa_range                 at VCPU creation
I₃:  VL ∈ {128, 256, 512, 1024, 2048} ∧ VL ≤ VL_max(substrate)
I₄:  VL is invariant ∀ t ≥ t_configured
I₅:  Σ_stable = Σ_host ∩ Σ_guest
I₆:  SVE_SAVE_EXTRA ordering: Z, then P, then FFR
I₇:  DAIF restored atomically at EL1 re-entry
I₈:  VMID(VTTBR_EL2) is unique across all running VCPUs
I₉:  No EL1 address in Stage-2 table maps to Realm or Secure PAS (on V3/RME hosts)
I₁₀: BRBE disabled or flushed before each VM entry if guest BRBE access not granted
```

### Vectorised Execution

Number-Theoretic Transform (NTT) operations targeting post-quantum cryptographic primitives (lattice-based schemes: CRYSTALS-Kyber, CRYSTALS-Dilithium) are executed using SVE2 vectorised instruction sequences. Correctness constraints:

- NTT butterfly operations use `SQRDMLAH` (SVE2 saturating multiply-add) and `MUL Zd.H, Zn.H, Zm.H[idx]` with indexed element access.
- Predicate registers `P0..P3` gate active lanes; FFR is not used in NTT inner loops (no fault-first loads on NTT coefficient arrays).
- VL-invariance is a prerequisite for NTT correctness: the transform length must be a fixed multiple of VL. A VL change mid-transform is a correctness violation (see I₄).
- Constant-time execution is required: no data-dependent branch, no data-dependent memory access pattern. SVE2 predicated execution must not introduce timing variation through predicate-dependent cache line fetch.

### Correctness Boundary

Execution correctness is defined as:

1. **Architectural correctness** — all register-observable state transitions conform to the ARM Architecture Reference Manual (DDI0487) and KVM/ARM documentation.
2. **Isolation correctness** — no guest can observe the memory or register state of any other guest or of EL2, through any architectural mechanism.
3. **Microarchitectural non-interference** — no guest can infer the memory access patterns or branch behaviour of any other guest or of EL2 through cache timing, branch predictor state, or buffer-based side channels, under the mitigations declared in §6.
4. **Projection correctness** — the feature set advertised to the guest by QEMU (`Σ_stable`) is a strict subset of the features physically present on every target substrate; no feature is advertised that is not present and behaving correctly on all hosts in the fleet.

A system state that satisfies (1) and (2) but violates (3) is not correct. Microarchitectural non-interference is a first-class correctness obligation, not a secondary hardening concern.

---

## Reference Specifications

- ARM Architecture Reference Manual — ARMv8-A (DDI0487K)
- ARM Architecture Reference Manual — ARMv9-A supplement
- ARM Neoverse N2 Core Technical Reference Manual
- ARM Neoverse V3 Core Technical Reference Manual
- Linux KVM/ARM64 documentation — `Documentation/virt/kvm/arm/`
- QEMU ARM target documentation — `target/arm/.`
- IETF / NIST Post-Quantum Cryptography standards — CRYSTALS-Kyber (FIPS 203), CRYSTALS-Dilithium (FIPS 204)
- Microsoft Azure Cobalt infrastructure documentation

---

*This repository contains no application-layer code, no cloud product integration, and no DevOps tooling. All artefacts are systems-level execution correctness artefacts targeting ARM EL2 hypervisor behaviour, Stage-2 MMU semantics, SVE2 register-file correctness, and QEMU architectural projection on Azure Cobalt-class Neoverse infrastructure.*
