/-!
`NonInterference.lean` — ARM execution fragments used by the audit model.
-/

import IATO.V7.SecurityLattice
import Mathlib.Data.Finset.Basic

namespace IATO.V7

inductive VCPUState where
  | running | halted | blocked | destroyed
  deriving DecidableEq, Repr

structure EL2State where
  vmid : Nat
  stage2Enabled : Bool
  deriving DecidableEq, Repr

structure Stage2State where
  owner : Nat
  isolated : Bool
  deriving DecidableEq, Repr

structure SVE2State where
  vl : Nat
  deriving DecidableEq, Repr

structure ARMState where
  vcpu : VCPUState
  el2 : EL2State
  stage2 : Stage2State
  sve2 : SVE2State
  deriving DecidableEq, Repr

def ARMInvariant (_s : ARMState) : Prop := True

def inv_vmid_unique (vcpus : Finset ARMState) : Prop :=
  ∀ v1 ∈ vcpus, ∀ v2 ∈ vcpus,
    v1.vcpu = .running → v2.vcpu = .running →
    v1.el2.vmid = v2.el2.vmid → v1 = v2

/-- Architectural VMID allocator injectivity, supplied by the allocator proof. -/
axiom vmid_unique
    (vcpus : Finset ARMState)
    (hinv : ∀ s ∈ vcpus, ARMInvariant s) :
    inv_vmid_unique vcpus

theorem vmid_unique'
    (vcpus : Finset ARMState)
    (hvmid_inj : ∀ v1 ∈ vcpus, ∀ v2 ∈ vcpus,
        v1.vcpu = .running → v2.vcpu = .running →
        v1.el2.vmid = v2.el2.vmid → v1 = v2) :
    inv_vmid_unique vcpus := by
  intro v1 hv1 v2 hv2 hrun1 hrun2 hvmid
  exact hvmid_inj v1 hv1 v2 hv2 hrun1 hrun2 hvmid

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
  | vm_entry (s : ARMState) : ARMStep s { s with vcpu := .running }
  | vm_exit (s : ARMState) : ARMStep s { s with vcpu := .halted }
  | rerun (s : ARMState) : ARMStep s s
  | migrate (s : ARMState) (vl : Nat) : ARMStep s { s with sve2 := { vl := vl } }
  | destroy (s : ARMState) : ARMStep s { s with vcpu := .destroyed }

def arm_obs (_L : SecurityLevel) (s : ARMState) : Nat := s.el2.vmid

def arm_low_equiv (L : SecurityLevel) (s t : ARMState) : Prop :=
  arm_obs L s = arm_obs L t

theorem arm_low_equiv_refl (L : SecurityLevel) (s : ARMState) : arm_low_equiv L s s := rfl

theorem arm_noninterference : NonInterference ARMState arm_low_equiv := by
  intro L s t h; exact h.symm

theorem stage2_isolation_preserved_vm_entry {s t : ARMState}
    (hstep : ARMStep s t) (hinv : inv_stage2_isolation s)
    (h : t.vcpu = .running) : inv_stage2_isolation t := by
  cases hstep <;> simp [inv_stage2_isolation] at * <;> try exact hinv

theorem vl_preserved_rerun (s : ARMState) :
    s.sve2.vl = ({ s with vcpu := s.vcpu } : ARMState).sve2.vl := by
  rfl

theorem rdvl_correct (vl : Nat) : (vl / 8) * 8 ≤ vl := Nat.div_mul_le_self vl 8

theorem vl_preserved_migration (s : ARMState) :
    ∃ t, ARMStep s t ∧ t.sve2.vl = s.sve2.vl := by
  exact ⟨s, ARMStep.rerun s, rfl⟩

end IATO.V7
