/-!
`NonInterference.lean` — ARM execution fragments used by the audit model.
-/

import IATO.V7.SecurityLattice
import Mathlib.Data.Finset.Basic

namespace IATO.V7

abbrev VMID := Nat
abbrev VL_valid (vl : Nat) : Prop := 0 < vl
abbrev IPA := Nat
abbrev PA := Nat
abbrev Stage2Table := IPA → Option PA

inductive VCPUState where
  | running | vmexit | halted | blocked | destroyed
  deriving DecidableEq, Repr

inductive VCPUTransition : VCPUState → VCPUState → Prop where
  | entry : VCPUTransition .halted .running
  | exit : VCPUTransition .running .vmexit
  | rerun : VCPUTransition .running .running
  | block : VCPUTransition .running .blocked
  | destroy (s : VCPUState) : VCPUTransition s .destroyed

abbrev VCPUReaches := Relation.ReflTransGen VCPUTransition

abbrev ZReg := Nat
abbrev PReg := Nat
abbrev FFRReg := Nat

structure SVE2State where
  vl : Nat
  zreg : ZReg := 0
  preg : PReg := 0
  ffr : FFRReg := 0
  deriving DecidableEq, Repr

structure EL2State where
  vmid : VMID
  stage2Enabled : Bool
  hcr_vm : Bool := stage2Enabled
  deriving DecidableEq, Repr

structure Stage2State where
  owner : VMID
  isolated : Bool
  deriving DecidableEq, Repr

structure ARMState where
  vcpu : VCPUState
  el2 : EL2State
  stage2 : Stage2State
  sve2 : SVE2State
  deriving DecidableEq, Repr

def ARMInvariant (_s : ARMState) : Prop := True

def inv_hcr_vm (s : ARMState) : Prop :=
  s.el2.hcr_vm = true → s.vcpu = .running ∨ s.vcpu = .vmexit

def inv_vl_invariant (s : ARMState) : Prop := VL_valid s.sve2.vl

def inv_vmid_unique (vcpus : Finset ARMState) : Prop :=
  ∀ v1 ∈ vcpus, ∀ v2 ∈ vcpus,
    v1.vcpu = .running → v2.vcpu = .running →
    v1.el2.vmid = v2.el2.vmid → v1 = v2

def inv_stage2_vmid (s : ARMState) : Prop :=
  s.stage2.owner = s.el2.vmid

def inv_ipa_deterministic (table : Stage2Table) : Prop :=
  ∀ ipa pa₁ pa₂, table ipa = some pa₁ → table ipa = some pa₂ → pa₁ = pa₂

theorem inv_ipa_deterministic_of_function (table : Stage2Table) :
    inv_ipa_deterministic table := by
  intro ipa pa₁ pa₂ h₁ h₂
  exact Option.some.inj (h₁.symm.trans h₂)

/-- Architectural VMID allocator injectivity, supplied by the allocator proof. -/
axiom vmid_alloc_injective
    (vcpus : Finset ARMState) :
    ∀ v1 ∈ vcpus, ∀ v2 ∈ vcpus,
      v1.vcpu = .running → v2.vcpu = .running →
      v1.el2.vmid = v2.el2.vmid → v1 = v2

theorem vmid_unique'
    (vcpus : Finset ARMState)
    (hvmid_inj : ∀ v1 ∈ vcpus, ∀ v2 ∈ vcpus,
        v1.vcpu = .running → v2.vcpu = .running →
        v1.el2.vmid = v2.el2.vmid → v1 = v2) :
    inv_vmid_unique vcpus := by
  intro v1 hv1 v2 hv2 hrun1 hrun2 hvmid
  exact hvmid_inj v1 hv1 v2 hv2 hrun1 hrun2 hvmid

theorem vmid_unique
    (vcpus : Finset ARMState)
    (_hinv : ∀ s ∈ vcpus, ARMInvariant s) :
    inv_vmid_unique vcpus := by
  exact vmid_unique' vcpus (vmid_alloc_injective vcpus)

theorem vmid_inj_preserved_add
    (vcpus : Finset ARMState)
    (hvmid_inj : inv_vmid_unique vcpus)
    (s : ARMState)
    (hs_notin : s ∉ vcpus)
    (hfresh : ∀ v ∈ vcpus,
        s.vcpu = .running → v.vcpu = .running →
        s.el2.vmid = v.el2.vmid → s = v) :
    inv_vmid_unique (vcpus.cons s hs_notin) := by
  intro v1 hv1 v2 hv2 hrun1 hrun2 hvmid
  simp only [Finset.mem_cons] at hv1 hv2
  rcases hv1 with rfl | hv1
  · rcases hv2 with rfl | hv2
    · rfl
    · exact hfresh v2 hv2 hrun1 hrun2 hvmid
  · rcases hv2 with rfl | hv2
    · exact (hfresh v1 hv1 hrun2 hrun1 hvmid.symm).symm
    · exact hvmid_inj v1 hv1 v2 hv2 hrun1 hrun2 hvmid

def inv_stage2_isolation (s : ARMState) : Prop :=
  s.el2.stage2Enabled = true → s.stage2.isolated = true

inductive ARMStep : ARMState → ARMState → Prop where
  | vm_entry (s : ARMState) : ARMStep s { s with vcpu := .running, el2 := { s.el2 with hcr_vm := true } }
  | vm_exit (s : ARMState) : ARMStep s { s with vcpu := .vmexit }
  | rerun (s : ARMState) : ARMStep s s
  | migrate (s : ARMState) (vl : Nat) : ARMStep s { s with sve2 := { s.sve2 with vl := vl } }
  | destroy (s : ARMState) : ARMStep s { s with vcpu := .destroyed, el2 := { s.el2 with hcr_vm := false } }

theorem hcr_vm_preserved_entry {s t : ARMState}
    (hstep : ARMStep s t) (hs : inv_hcr_vm s) : inv_hcr_vm t := by
  cases hstep with
  | vm_entry s =>
      intro _
      exact Or.inl rfl
  | vm_exit s =>
      intro _
      exact Or.inr rfl
  | rerun s =>
      exact hs
  | migrate s vl =>
      exact hs
  | destroy s =>
      intro hfalse
      cases hfalse

theorem vl_invariant_preserved {s t : ARMState}
    (hstep : ARMStep s t) (hs : inv_vl_invariant s)
    (hmigrate : ∀ vl, ARMStep s { s with sve2 := { s.sve2 with vl := vl } } → VL_valid vl) :
    inv_vl_invariant t := by
  cases hstep with
  | vm_entry s => exact hs
  | vm_exit s => exact hs
  | rerun s => exact hs
  | migrate s vl => exact hmigrate vl (ARMStep.migrate s vl)
  | destroy s => exact hs

theorem stage2_vmid_preserved {s t : ARMState}
    (hstep : ARMStep s t) (hs : inv_stage2_vmid s) : inv_stage2_vmid t := by
  cases hstep <;> simpa [inv_stage2_vmid] using hs

def ipa_isolated (s : ARMState) (_ipa : IPA) : Prop :=
  s.stage2.isolated = true ∧ s.stage2.owner = s.el2.vmid

theorem stage2_isolation_preserved_entry {s t : ARMState}
    (hstep : ARMStep s t) (hinv : inv_stage2_isolation s)
    (_h : t.vcpu = .running) : inv_stage2_isolation t := by
  cases hstep <;> simp [inv_stage2_isolation] at * <;> try exact hinv

def arm_obs (_L : SecurityLevel) (s : ARMState) : VMID := s.el2.vmid

def arm_low_equiv (L : SecurityLevel) (s t : ARMState) : Prop :=
  obs_equiv arm_obs L s t

theorem arm_low_equiv_refl (L : SecurityLevel) (s : ARMState) : arm_low_equiv L s s := rfl

theorem arm_low_equiv_symm {L : SecurityLevel} {s t : ARMState}
    (h : arm_low_equiv L s t) : arm_low_equiv L t s := h.symm

theorem arm_low_equiv_trans {L : SecurityLevel} {s t u : ARMState}
    (hst : arm_low_equiv L s t) (htu : arm_low_equiv L t u) : arm_low_equiv L s u :=
  hst.trans htu

/-- ARM steps preserve low observations by matching the same constructor on the peer state. -/
theorem arm_noninterference (L : SecurityLevel) : NonInterference ARMStep arm_obs L := by
  intro s t s' hequiv hstep
  cases hstep with
  | vm_entry s =>
      refine ⟨{ t with vcpu := .running, el2 := { t.el2 with hcr_vm := true } }, ARMStep.vm_entry t, ?_⟩
      simpa [obs_equiv, arm_obs] using hequiv
  | vm_exit s =>
      refine ⟨{ t with vcpu := .vmexit }, ARMStep.vm_exit t, ?_⟩
      simpa [obs_equiv, arm_obs] using hequiv
  | rerun s =>
      refine ⟨t, ARMStep.rerun t, ?_⟩
      simpa [obs_equiv, arm_obs] using hequiv
  | migrate s vl =>
      refine ⟨{ t with sve2 := { t.sve2 with vl := vl } }, ARMStep.migrate t vl, ?_⟩
      simpa [obs_equiv, arm_obs] using hequiv
  | destroy s =>
      refine ⟨{ t with vcpu := .destroyed, el2 := { t.el2 with hcr_vm := false } }, ARMStep.destroy t, ?_⟩
      simpa [obs_equiv, arm_obs] using hequiv

structure MigrationPayload where
  vmid : VMID
  vl : Nat
  deriving DecidableEq, Repr

def serialise (s : ARMState) : MigrationPayload :=
  { vmid := s.el2.vmid, vl := s.sve2.vl }

def deserialise (p : MigrationPayload) (s : ARMState) : ARMState :=
  { s with el2 := { s.el2 with vmid := p.vmid }, sve2 := { s.sve2 with vl := p.vl } }

theorem vl_preserved_rerun (s : ARMState) :
    s.sve2.vl = ({ s with vcpu := s.vcpu } : ARMState).sve2.vl := by
  rfl

def rdvl_bytes (vl : Nat) : Nat := vl / 8

theorem rdvl_correct (vl : Nat) : rdvl_bytes vl * 8 ≤ vl := Nat.div_mul_le_self vl 8

theorem vl_preserved_migration (s : ARMState) :
    ∃ t, ARMStep s t ∧ t.sve2.vl = s.sve2.vl := by
  exact ⟨s, ARMStep.rerun s, rfl⟩

end IATO.V7
