# Intent-to-Auditable-Trust-Object-v7

This repository is the v0.1.0 specification review. Each section of the execution model is checked against primary reference material. Findings are classified as **Correction** (factually incorrect; must be resolved before the section is considered conformant) or **Precision** (correct in intent; requires scoping or disambiguation to eliminate interpretive ambiguity).



## Reference Specifications

```
ARM DDI0487K     ARM Architecture Reference Manual — ARMv8-A (AArch64)
ARM DDI0608A     ARMv9-A Architecture Supplement
                 ARM Neoverse N2 Core TRM r0p1
                 ARM Neoverse V3 / CSS V3 Technical Reference Materials
                 Linux KVM/ARM64 API Documentation — docs.kernel.org/virt/kvm/api.html
                 QEMU ARM target — target/arm/
                 Microsoft Azure Cobalt 100 / 200 Infrastructure Documentation
                 FIPS 203 (CRYSTALS-Kyber), FIPS 204 (CRYSTALS-Dilithium)
```



## Repository Structure

```
.
├── README.md
├── findings/
│   ├── F-1-cobalt100-isa.md       ISA version correction — source citations
│   ├── F-2-vcpu-lifecycle.md      Corrected VCPU state machine
│   ├── F-3-vl-finalize.md         KVM_ARM_VCPU_FINALIZE vs KVM_SET_ONE_REG
│   └── F-4-tge-scope.md           HCR_EL2.TGE VHE scoping
└── refs/
    ├── ddi0487k-sections.md        DDI0487K section index by finding
    ├── kvm-api-extracts.md         KVM API documentation extracts
    └── substrate-errata.md         Cobalt 100 kernel errata patch reference
```



## Finding Index

| ID | Section | Class | Description |
|---|---|---|---|
| F-1 | §4, §7 — Cobalt 100 substrate | Correction | ISA version recorded as `ARMv8.5-A`; must be `ARMv9.0-A` |
| F-2 | §5 — VCPU lifecycle | Correction | `finalized` state absent; `configured → running` is not a valid direct transition for SVE-enabled VCPUs |
| F-3 | §3 — SVE2 VL negotiation | Precision | VL invariance is enforced by `KVM_ARM_VCPU_FINALIZE`; `KVM_SET_ONE_REG` sets the negotiated value but does not lock it |
| F-4 | §1 — `HCR_EL2.TGE` | Precision | `TGE = 1` is architecturally valid under VHE; the constraint must be explicitly scoped to this non-VHE design |



## §1 — ARM EL2 Hypervisor

**`HCR_EL2` field table.** All six entries (`VM`, `RW`, `TSC`, `TWI`/`TWE`, `TGE`, `VSE`) are present in `HCR_EL2` per DDI0487K. Constraint descriptions conform to specification.

**EL2 save/restore register list.** `HCR_EL2`, `VTTBR_EL2`, `VTCR_EL2`, `SCTLR_EL2`, `TCR_EL2`, `MAIR_EL2`, `SPSR_EL2`, `ELR_EL2`, `SP_EL2`, `DAIF` are all EL2 owned in a non-VHE hypervisor configuration. List conforms to specification.

**DAIF atomicity.** DAIF interrupt mask bits must be coherent across EL2→EL1 transitions. Partial restoration constitutes architecturally undefined behaviour. Constraint conforms to specification.

**F-4 — `HCR_EL2.TGE` constraint (Precision).** The document states `TGE = 0` with the annotation "TGE=1 is not a valid configuration here." The constraint is correct for this non-VHE design but is stated without qualification. `TGE = 1` is architecturally valid under VHE (`HCR_EL2.E2H = 1`), where the host OS executes in EL2 and EL0 exceptions route to EL2 rather than EL1. The annotation must be scoped:

```
HCR_EL2.TGE  |  0  |  Non-VHE design; guest executes in EL1.
                       TGE=1 is valid under VHE (HCR_EL2.E2H=1)
                       but is not used in this design.
```



## §2 — Stage-2 Memory Isolation

**`VTTBR_EL2` / `VTCR_EL2` field table.** All fields (`T0SZ`, `SL0`, `IRGN0`, `ORGN0`, `SH0`, `PS`, `VS`) are present in `VTCR_EL2` per DDI0487K. `VS` at bit 19, 1-bit field, encoding 0 = 8-bit VMID / 1 = 16-bit VMID — conforms to specification. `T0SZ`/`SL0` consistency requirement is confirmed: inconsistent programming produces a Stage-2 level 0 translation fault.

**Isolation invariants.** All four invariants conform to specification:

- Stage-2 fault on unmapped IPA routed to EL2: confirmed.
- EL1 cannot modify `VTTBR_EL2` / `VTCR_EL2`; attempts trap unconditionally: confirmed.
- Device MMIO regions mapped as `nGnRE` or `nGnRnE`: required for device-type MMIO mappings, confirmed.
- VMID reuse without `VMALLS12E1IS` is a fault condition, not a race: confirmed.



## §3 — SVE2 Vector Execution

**Feature detection sequence.** The two-step check — `ID_AA64PFR0_EL1.SVE ≠ 0b0000` to confirm SVE, then `ID_AA64ZFR0_EL1.SVEver == 0b0001` to confirm SVE2 — is correct and necessary. Querying `ID_AA64ZFR0_EL1` when `ID_AA64PFR0_EL1.SVE == 0` produces unreliable results on SME-only hardware, where ZFR0 fields overlap with SME feature indicators. The ordering in the document is architecturally sound.

**SVE2 register state.** `⟨Z₀..₃₁, P₀..₁₅, FFR, VL⟩` — 32 Z-registers, 16 predicate registers, FFR, VL — constitutes the complete architectural SVE/SVE2 register state. Conforms to specification.

**F-3 — VL negotiation (Precision).** The document states: "VL is negotiated once at VCPU creation via `KVM_SET_ONE_REG` targeting `KVM_REG_ARM64_SVE_VLS`. Once set, VL is invariant for the lifetime of the VCPU." Two distinct operations are conflated. Per KVM API documentation:

- `KVM_REG_ARM64_SVE_VLS` becomes accessible after `KVM_ARM_VCPU_INIT`, not at VCPU creation.
- The register is writable until `KVM_ARM_VCPU_FINALIZE(KVM_ARM_VCPU_SVE)` is called.
- After finalisation, writes return `EPERM`.

`KVM_SET_ONE_REG` sets the negotiated value. `KVM_ARM_VCPU_FINALIZE` locks it. VL invariance is a property of the finalised state, not of the set operation. The lifecycle model in §5 must reflect this distinction (see F-2).

**SVE context save/restore ordering.** Z registers → predicate registers → FFR ordering is confirmed correct. FFR is dependent on predicate state; saving FFR before predicates are stable is semantically incorrect. Ordering conforms to specification.

**`ZCR_EL2.LEN` formula.** `ZCR_EL2.LEN = (VL/128) - 1` confirmed per SVE architecture specification. Effective VL = `(min(ZCR_EL1.LEN, ZCR_EL2.LEN) + 1) × 128` bits.

**Save area size.** `(32 × VL/8) + (16 × VL/64) + (VL/64)` bytes, decomposed as Z-registers + predicate registers + FFR. Conforms to specification.



## §4 — QEMU Architecture

**Projection constraint model.** `Σ_host ∩ Σ_guest → Σ_stable` intersection model conforms to QEMU CPU model negotiation and KVM ID register trap handling. Features not in `Σ_stable` returned as `0b0000` in guest ID register reads — confirmed against QEMU `target/arm/`.

**ID register masking list.** `ID_AA64PFR0_EL1`, `ID_AA64ZFR0_EL1`, `ID_AA64ISAR1_EL1`, `ID_AA64PFR1_EL1` — all four confirmed masked by QEMU for guest feature projection. Conforms to specification.

**F-1 — Cobalt 100 ISA version (Correction).** The document records `Azure Cobalt 100 — ARMv8.5-A — Neoverse N2`. This is incorrect. Neoverse N2 implements **ARMv9.0-A**.

Supporting sources: ARM Neoverse N2 product documentation and Hot Chips 2021 proceedings confirm the ARMv9.0-A ISA baseline. The Linux kernel errata subscription patch (February 2024, Easwar Hariharan) identifies the Cobalt 100 MIDR as `r0p0` of Neoverse N2 (`MICROSOFT_CPU_PART_AZURE_COBALT_100 = 0xD49`), placing it directly on the N2 microarchitecture. The common confusion source is the N2 compiler flag profile (`-march=armv8.6-a`), which reflects the extension profile, not the ISA version.

```diff
- Azure Cobalt 100  |  ARMv8.5-A  |  Neoverse N2
+ Azure Cobalt 100  |  ARMv9.0-A  |  Neoverse N2
```

This correction applies identically to the §7 infrastructure table.

**Cobalt 200 ISA version.** `Azure Cobalt 200 — ARMv9.2-A — Neoverse V3` conforms to specification. Confirmed by Microsoft Ignite 2025 announcement and ARM Neoverse CSS V3 technical reference materials.



## §5 — KVM VCPU Lifecycle

**VM entry preconditions.** All five preconditions conform to specification:

```
HCR_EL2.VM == 1
VTTBR_EL2 valid and VMID-tagged
VTCR_EL2 consistent with IPA space
SVE context initialised or zero on first entry
DAIF coherent with interrupt routing policy
```

**VM exit reason table.** `KVM_EXIT_MMIO`, `KVM_EXIT_HVC`, `KVM_EXIT_SYSTEM_EVENT`, `KVM_EXIT_IRQ`, `KVM_EXIT_EXCEPTION` — all confirmed present and correctly described per KVM API documentation.

**F-2 — VCPU state machine (Correction).** The document records:

```
created → configured → running → vmexit → migrating → destroyed
```

The `configured → running` edge is not a valid direct transition for SVE-enabled VCPUs. `KVM_ARM_VCPU_FINALIZE(KVM_ARM_VCPU_SVE)` must be called before `KVM_RUN` is issued; without it, `KVM_RUN` returns an error. A `finalized` state is required between `configured` and `running`. The `migrating → configured` back-edge is also incorrect: a deserialised VCPU re-enters the `finalized` state on the target host, not `configured`.

Corrected state machine:

```
created      →  configured   :  KVM_ARM_VCPU_INIT applied;
                                 KVM_SET_ONE_REG(KVM_REG_ARM64_SVE_VLS) set
configured   →  finalized    :  KVM_ARM_VCPU_FINALIZE called;
                                 VLS immutable; subsequent writes return EPERM
finalized    →  running      :  KVM_RUN issued; VM entry executed
running      →  vmexit       :  trap, fault, interrupt, or HVC
vmexit       →  running      :  exit reason handled; KVM_RUN reissued
vmexit       →  migrating    :  VCPU state serialised for live migration
migrating    →  finalized    :  VCPU state deserialised on target host
finalized    →  destroyed    :  VCPU fd closed; all associated state released
```

Invariant `I₄` (`VL invariant ∀ t ≥ t_configured`) must read `t_finalized`.



## §6 — Microarchitecture

**Threat characterisation.** Spectre-v1 (bounds-check bypass), Spectre-v2 (branch target injection), Spectre-BHB (branch history buffer leakage), Meltdown (speculative EL2-mapped memory read from EL1 context), and cache timing attacks (Prime+Probe, Flush+Reload) — all correctly characterised. Scope and mechanism descriptions conform to published CVE and microarchitecture literature.

**Mitigation table.** `CLEARBHB` / `FEAT_CSV2_2` for BHB: confirmed. `ID_AA64PFR0_EL1.CSV2 = 0b0010` for `FEAT_CSV2_2`: confirmed. BTI enforcement via `SCTLR_EL2.BT`: confirmed. RSB stuffing at EL2 entry as mitigation for RSB underflow: confirmed. EL1 page tables containing no EL2 mappings as Meltdown mitigation: confirmed. All mitigations conform to specification.

**BRBE obligations.** Disable or flush obligations at VM entry are architecturally correct. `BRBCR_EL1.E0BRE` and `BRBCR_EL1.EXCEPTION` are the correct fields to clear. Disabling or flushing BRBE state prior to VM entry when guest BRBE access has not been explicitly granted conforms to correct security posture.



## §7 — Azure Cobalt Infrastructure

**Cobalt 100 ISA version.** `ARMv8.5-A` must be corrected to `ARMv9.0-A`. See F-1 in §4.

**Cobalt 100 feature register table.**

| Feature | Register Field | Status |
|---|---|---|
| SVE2, 256-bit max VL | `ID_AA64ZFR0_EL1.SVEver = 0b0001` | Conforms |
| MTE (MTE2) | `ID_AA64PFR1_EL1.MTE = 0b0011` | Conforms |
| PAC QARMA5 | `ID_AA64ISAR1_EL1.APA = 0b0001` | Conforms |
| BRBE | `ID_AA64DFR0_EL1.BRBE ≠ 0` | Conforms |
| FEAT_CSV2_2 | `ID_AA64PFR0_EL1.CSV2 = 0b0010` | Conforms |

**Cobalt 200 feature register table.**

| Feature | Register Field | Status |
|---|---|---|
| SVE2, 512-bit max VL | `ID_AA64ZFR0_EL1.SVEver = 0b0001` | Conforms |
| PAC QARMA3 | `ID_AA64ISAR2_EL1.APA3 = 0b0001` | Conforms |
| MTE3 (FEAT_MTE_ASYM_FAULT) | `ID_AA64PFR1_EL1.MTE = 0b0100` | Conforms |
| RME / CCA | `ID_AA64PFR0_EL1.RME ≠ 0` | Conforms |
| FEAT_BTI | `ID_AA64PFR1_EL1.BT ≠ 0` | Conforms |

**PAC QARMA3 transition.** QARMA3 produces different PAC field values than QARMA5 for the same key and pointer combination. Cross-host PAC field comparison is invalid on heterogeneous fleets. Characterisation conforms to specification.

**MTE3 save/restore.** `TFSRE0_EL1`, `TFSR_EL1`, `SCTLR_EL1.TCF`/`TCF0`, and the MTE tag memory region are all required MTE3 save/restore additions. Migration rejection for an MTE3-enabled VCPU targeting a host without `FEAT_MTE_ASYM_FAULT` conforms to correct behaviour.

**RME / CCA Realm world constraints.** Normal-world `VTTBR_EL2` cannot reference Realm or Secure PAS. Physical address space partitioning is enforced by the Granule Protection Table maintained at EL3. Conforms to RME architecture specification.



## §8 — Execution Correctness Model

**Invariants I₁–I₁₀.** All ten invariants are architecturally grounded and conform to their respective reference specifications. Notational corrections arising from F-2:

- `I₄`: `t_configured` must read `t_finalized`.
- `I₈`: Non-unique VMIDs produce TLB aliasing; `VMALLS12E1IS` is required on VMID reuse. Conforms.
- `I₉`: No EL1 address may map to Realm or Secure PAS on V3/RME hosts. Conforms.
- `I₁₀`: BRBE must be disabled or flushed before each VM entry where guest BRBE access has not been granted. Conforms.

**NTT vectorised execution.** `SQRDMLAH` and indexed `MUL Zd.H` for butterfly operations, `P0..P3` gating active lanes, FFR excluded from NTT inner loops, VL-invariance as a prerequisite for transform correctness, and constant-time predicated execution — all consistent with SVE2 NTT implementations for CRYSTALS-Kyber (FIPS 203) and CRYSTALS-Dilithium (FIPS 204).



## Conformance Index

| Section | Status | Finding |
|---|---|---|
| §1 EL2 Hypervisor | Conforms with precision | F-4 |
| §2 Stage-2 Isolation | Conforms | — |
| §3 SVE2 Execution | Conforms with precision | F-3 |
| §4 QEMU Architecture | Non-conformant | F-1 |
| §5 KVM VCPU Lifecycle | Non-conformant | F-2 |
| §6 Microarchitecture | Conforms | — |
| §7 Azure Cobalt | Non-conformant | F-1 |
| §8 Correctness Model | Conforms with notation | I₄ per F-2 |

No structural errors identified in the theoretical framework (§8), Stage-2 isolation model (§2), or side-channel threat model (§6). The observational quotient framing in the companion `obs-equiv` writeup maps directly onto the microarchitectural correctness boundary defined in §6 and §8. That relationship is confirmed to be consistent across both documents.

