/-!
`ComplianceGalois.lean` — abstraction/concretisation bridge for ARM states.
-/

import IATO.V7.NonInterference

namespace IATO.V7

open ARMSecurity

structure Spec where
  allowed : SecurityLevel → Prop
  downClosed : ∀ {L L' : SecurityLevel}, allowed L → L' ≤ L → allowed L'

instance : Membership SecurityLevel Spec where
  mem L S := S.allowed L

instance : LE Spec where
  le A B := ∀ ⦃L : SecurityLevel⦄, L ∈ A → L ∈ B

theorem Spec.le_refl (S : Spec) : S ≤ S := by intro L h; exact h

def stateLevel (s : ARMState) : SecurityLevel :=
  match s.vcpu with
  | .destroyed => .EL0
  | .running => .EL1
  | .halted => .EL1
  | .blocked => .EL1

/-- Abstraction from an ARM state to the levels justified by its evidence. -/
def α (s : ARMState) : Spec where
  allowed L := L ≤ stateLevel s
  downClosed := by
    intro L L' hL hL'le
    exact SecurityLevel.le_trans hL'le hL

/-- Concretisation: states whose abstraction contains the required evidence. -/
def γ (S : Spec) : Set ARMState :=
  {s | S ≤ α s}

theorem galois_connection (s : ARMState) (S : Spec) :
    S ≤ α s ↔ s ∈ γ S := Iff.rfl

theorem galois_extensive (S : Spec) (s : ARMState) (hs : s ∈ γ S) : S ≤ α s := hs

theorem galois_reductive (s : ARMState) : s ∈ γ (α s) := by
  intro L h; exact h

inductive Reachable (init : ARMState) : ARMState → Prop where
  | refl : Reachable init init
  | step {s t : ARMState} : Reachable init s → ARMStep s t → Reachable init t

def Compliant (init : ARMState) (S : Spec) : Prop :=
  ∀ s, Reachable init s → s ∈ γ S

abbrev Refines (init : ARMState) (S : Spec) : Prop := Compliant init S

def ConflictClosed (S : Spec) : Prop :=
  ∀ {a b}, a ∈ S → b ∈ S → SecurityLevel.meet a b ∈ S

theorem downClosed_implies_conflictClosed (S : Spec) : ConflictClosed S := by
  intro a b ha hb
  exact S.downClosed ha (SecurityLevel.meet_le_left a b)

def topSpec : Spec where
  allowed _ := True
  downClosed := by intro; trivial

def bottomSpec : Spec where
  allowed _ := False
  downClosed := by intro _ _ h _; exact False.elim h

theorem top_conflictClosed : ConflictClosed topSpec := by
  intro; trivial

def specJoin (A B : Spec) : Spec where
  allowed L := L ∈ A ∨ L ∈ B
  downClosed := by
    intro L L' h hle
    rcases h with hA | hB
    · exact Or.inl (A.downClosed hA hle)
    · exact Or.inr (B.downClosed hB hle)

theorem join_conflictClosed (A B : Spec) (hA : ConflictClosed A) (hB : ConflictClosed B)
    (hcross : ∀ {a b}, a ∈ A → b ∈ B → SecurityLevel.meet a b ∈ A ∨ SecurityLevel.meet a b ∈ B) :
    ConflictClosed (specJoin A B) := by
  intro a b ha hb
  rcases ha with ha | ha <;> rcases hb with hb | hb
  · exact Or.inl (hA ha hb)
  · exact hcross ha hb
  · rcases hcross hb ha with h | h
    · exact Or.inl (by simpa [SecurityLevel.meet_comm] using h)
    · exact Or.inr (by simpa [SecurityLevel.meet_comm] using h)
  · exact Or.inr (hB ha hb)

theorem α_vm_entry_mono (s : ARMState) : α s ≤ α { s with vcpu := .running } := by
  intro L h
  cases s.vcpu <;> cases L <;> simp [α, stateLevel, LE.le, SecurityLevel.rank] at *

theorem α_vm_exit_mono (s : ARMState) : α s ≤ α { s with vcpu := .halted } := by
  intro L h
  cases s.vcpu <;> cases L <;> simp [α, stateLevel, LE.le, SecurityLevel.rank] at *

theorem α_rerun_mono (s : ARMState) : α s ≤ α s := Spec.le_refl (α s)

theorem α_migrate_mono (s : ARMState) (vl : Nat) : α s ≤ α { s with sve2 := { vl := vl } } := by
  intro L h; simpa [α, stateLevel] using h

theorem α_mono_all_steps (s t : ARMState) (hstep : ARMStep s t) :
    α s ≤ α t ∨ t.vcpu = .destroyed := by
  cases hstep with
  | vm_entry s => exact Or.inl (α_vm_entry_mono s)
  | vm_exit s => exact Or.inl (α_vm_exit_mono s)
  | rerun s => exact Or.inl (α_rerun_mono s)
  | migrate s vl => exact Or.inl (α_migrate_mono s vl)
  | destroy s => exact Or.inr rfl

theorem compliance_inductive_strong
    {init : ARMState}
    {S : Spec}
    (hinit : init ∈ γ S)
    (hmono : ∀ s t : ARMState,
        Reachable init s →
        ARMStep s t →
        α s ≤ α t) :
    Compliant init S := by
  intro s hs
  induction hs with
  | refl => exact hinit
  | step hreach hstep ih =>
      intro L hSL
      exact hmono _ _ hreach hstep (ih hSL)

theorem compliance_inductive
    {init : ARMState}
    {S : Spec}
    (hinit : init ∈ γ S)
    (hmono : ∀ s t : ARMState, ARMStep s t → α s ≤ α t) :
    Compliant init S := by
  apply compliance_inductive_strong hinit
  intro s t _ hstep
  exact hmono s t hstep

theorem compliance_fully_preserved
    {init : ARMState}
    {S : Spec}
    (hinit : init ∈ γ S)
    (hno_destroy : ∀ s, Reachable init s → s.vcpu ≠ .destroyed) :
    Compliant init S := by
  apply compliance_inductive_strong hinit
  intro s t hs_reach hstep
  rcases α_mono_all_steps s t hstep with hle | hdest
  · exact hle
  · exfalso
    exact hno_destroy t (Reachable.step hs_reach hstep) hdest

theorem compliant_iff_refines (init : ARMState) (S : Spec) :
    Compliant init S ↔ Refines init S := Iff.rfl

theorem compliance_implies_ni_EL1 {init : ARMState} {S : Spec}
    (_hc : Compliant init S) : NonInterference ARMStep arm_obs SecurityLevel.EL1 :=
  arm_noninterference SecurityLevel.EL1

theorem ni_compliance_joint_satisfiable :
    ∃ init S, NonInterference ARMStep arm_obs SecurityLevel.EL1 ∧ Compliant init S := by
  let init : ARMState :=
    { vcpu := .running, el2 := { vmid := 0, stage2Enabled := true },
      stage2 := { owner := 0, isolated := true }, sve2 := { vl := 128 } }
  refine ⟨init, bottomSpec, arm_noninterference SecurityLevel.EL1, ?_⟩
  intro s _
  intro L hbot
  exact False.elim hbot

end IATO.V7
