/-!
`SecurityLattice.lean` — finite ARM exception-level lattice.

The lattice is deliberately finite: all order facts reduce to the four ARM
exception levels and can be discharged by case analysis.
-/

import Mathlib.Tactic

namespace IATO.V7

inductive SecurityLevel where
  | EL0 | EL1 | EL2 | EL3
  deriving DecidableEq, Repr

namespace SecurityLevel

/-- Numeric rank; used to derive the order. -/
def rank : SecurityLevel → ℕ
  | EL0 => 0
  | EL1 => 1
  | EL2 => 2
  | EL3 => 3

/-- `rank` is injective. -/
theorem rank_injective : Function.Injective rank := by
  intro a b h
  cases a <;> cases b <;> simp [rank] at h <;> rfl

/-──────────────────────────────────────────────────────────
  §1.1  Ordering
──────────────────────────────────────────────────────────-/

instance : LE SecurityLevel := ⟨fun a b => a.rank ≤ b.rank⟩
instance : LT SecurityLevel := ⟨fun a b => a.rank < b.rank⟩

@[simp] theorem le_def (a b : SecurityLevel) : a ≤ b ↔ a.rank ≤ b.rank := Iff.rfl
@[simp] theorem lt_def (a b : SecurityLevel) : a < b ↔ a.rank < b.rank := Iff.rfl

/-- Reflexivity of ≤. -/
theorem le_refl (a : SecurityLevel) : a ≤ a := Nat.le_refl _

/-- Transitivity of ≤. -/
theorem le_trans {a b c : SecurityLevel} (hab : a ≤ b) (hbc : b ≤ c) : a ≤ c :=
  Nat.le_trans hab hbc

/-- Antisymmetry: a ≤ b ∧ b ≤ a → a = b. -/
theorem le_antisymm {a b : SecurityLevel} (hab : a ≤ b) (hba : b ≤ a) : a = b :=
  rank_injective (Nat.le_antisymm hab hba)

/-- Totality: ≤ is a total order. -/
theorem le_total (a b : SecurityLevel) : a ≤ b ∨ b ≤ a :=
  Nat.le_total _ _

instance : Preorder SecurityLevel where
  le_refl  := le_refl
  le_trans := @le_trans

instance : PartialOrder SecurityLevel where
  le_antisymm := @le_antisymm

/-──────────────────────────────────────────────────────────
  §1.2  Lattice operations (join = max, meet = min)

  A chain is a distributive lattice with ⊔ = max and ⊓ = min.  We give
  explicit definitions and prove the four lattice axioms.
──────────────────────────────────────────────────────────-/

/-- Join is the greater of two exception levels. -/
def join (a b : SecurityLevel) : SecurityLevel :=
  if a.rank ≤ b.rank then b else a

/-- Meet is the lesser of two exception levels. -/
def meet (a b : SecurityLevel) : SecurityLevel :=
  if a.rank ≤ b.rank then a else b

notation:65 a " ⊔ₛ " b => SecurityLevel.join a b
notation:70 a " ⊓ₛ " b => SecurityLevel.meet a b

/-- Join is an upper bound for the left operand. -/
theorem le_join_left (a b : SecurityLevel) : a ≤ a ⊔ₛ b := by
  simp [join]
  split_ifs with h
  · exact h
  · exact SecurityLevel.le_refl a

/-- Join is an upper bound for the right operand. -/
theorem le_join_right (a b : SecurityLevel) : b ≤ a ⊔ₛ b := by
  simp [join]
  split_ifs with h
  · exact SecurityLevel.le_refl b
  · exact Nat.le_of_not_le h

/-- Join is the least upper bound. -/
theorem join_le {a b c : SecurityLevel} (hac : a ≤ c) (hbc : b ≤ c) : a ⊔ₛ b ≤ c := by
  simp [join]
  split_ifs with _
  · exact hbc
  · exact hac

/-- Meet is a lower bound for the left operand. -/
theorem meet_le_left (a b : SecurityLevel) : a ⊓ₛ b ≤ a := by
  simp [meet]
  split_ifs with h
  · exact SecurityLevel.le_refl a
  · exact Nat.le_of_not_le h

/-- Meet is a lower bound for the right operand. -/
theorem meet_le_right (a b : SecurityLevel) : a ⊓ₛ b ≤ b := by
  simp [meet]
  split_ifs with h
  · exact h
  · exact SecurityLevel.le_refl b

/-- Meet is the greatest lower bound. -/
theorem le_meet {a b c : SecurityLevel} (hca : c ≤ a) (hcb : c ≤ b) : c ≤ a ⊓ₛ b := by
  simp [meet]
  split_ifs with _
  · exact hca
  · exact hcb

/-- Meet is commutative on the four-point chain. -/
theorem meet_comm (a b : SecurityLevel) : a ⊓ₛ b = b ⊓ₛ a := by
  cases a <;> cases b <;> simp [meet, rank]

/-──────────────────────────────────────────────────────────
  §1.3  Lattice instance (Mathlib typeclass)
──────────────────────────────────────────────────────────-/

instance : Lattice SecurityLevel where
  sup          := join
  inf          := meet
  le_sup_left  := le_join_left
  le_sup_right := le_join_right
  sup_le       := fun _ _ _ => join_le
  inf_le_left  := meet_le_left
  inf_le_right := meet_le_right
  le_inf       := fun _ _ _ => le_meet

/-- Top element: EL3. -/
instance : Top SecurityLevel := ⟨EL3⟩

/-- Bottom element: EL0. -/
instance : Bot SecurityLevel := ⟨EL0⟩

theorem bot_le (a : SecurityLevel) : ⊥ ≤ a := by
  cases a <;> simp [LE.le, rank]

theorem le_top (a : SecurityLevel) : a ≤ ⊤ := by
  cases a <;> simp [LE.le, rank]

instance : BoundedOrder SecurityLevel where
  bot_le := bot_le
  le_top := le_top

/-──────────────────────────────────────────────────────────
  §1.4  Key ordering facts used by downstream files
──────────────────────────────────────────────────────────-/

theorem EL0_le_EL1 : EL0 ≤ EL1 := by simp
theorem EL1_le_EL2 : EL1 ≤ EL2 := by simp
theorem EL2_le_EL3 : EL2 ≤ EL3 := by simp
theorem EL0_lt_EL2 : EL0 < EL2 := by simp
theorem EL1_lt_EL3 : EL1 < EL3 := by simp

/-- EL2 and EL3 are strictly above EL1. -/
theorem EL1_not_above_EL2 : ¬(EL2 ≤ EL1) := by simp
theorem EL1_not_above_EL3 : ¬(EL3 ≤ EL1) := by simp

/-- Levels below or equal to EL1 are exactly EL0 and EL1. -/
theorem le_EL1_iff (L : SecurityLevel) : L ≤ SecurityLevel.EL1 ↔ L = EL0 ∨ L = EL1 := by
  constructor
  · intro h
    cases L <;> simp at h ⊢
  · rintro (rfl | rfl) <;> simp

end SecurityLevel

/-──────────────────────────────────────────────────────────────────────────────
  §2  Information-Flow Relation

  `flows_to L H` asserts that information at level L may flow to level H.
  This is the standard can-flow-to relation from Bell-LaPadula:
    L flows_to H  iff  L ≤ H
──────────────────────────────────────────────────────────────────────────────-/

/-- Information may flow from `src` to `dst` iff src is dominated by dst. -/
def flows_to (src dst : SecurityLevel) : Prop := src ≤ dst

namespace flows_to

theorem refl (L : SecurityLevel) : flows_to L L :=
  SecurityLevel.le_refl L

theorem trans {L M H : SecurityLevel} (hLM : flows_to L M) (hMH : flows_to M H) :
    flows_to L H :=
  SecurityLevel.le_trans hLM hMH

/-- Information does not flow from high to low (downgrade prohibition). -/
theorem no_downgrade {H L : SecurityLevel} (hHL : H > L) : ¬flows_to H L := by
  intro h
  have hLH : L ≤ H := Nat.le_of_lt hHL
  have hEq : H = L := SecurityLevel.le_antisymm h hLH
  have hNe : H ≠ L := by
    intro hEq'
    rw [hEq'] at hHL
    exact Nat.lt_irrefl _ hHL
  exact hNe hEq

/-- `flows_to EL1 EL2`: guest OS data may flow upward to hypervisor. -/
theorem guest_to_hypervisor : flows_to SecurityLevel.EL1 SecurityLevel.EL2 :=
  SecurityLevel.EL1_le_EL2

/-- `flows_to EL2 EL1` does not hold. -/
theorem hypervisor_not_to_guest : ¬flows_to SecurityLevel.EL2 SecurityLevel.EL1 :=
  SecurityLevel.EL1_not_above_EL2

end flows_to

/-──────────────────────────────────────────────────────────────────────────────
  §3  Observable Equivalence

  Two states are observationally equivalent at level L if they are
  indistinguishable by an observer at security level L.
──────────────────────────────────────────────────────────────────────────────-/

/-- Observational equivalence at level L. -/
def obs_equiv {σ β : Type*} (obs : SecurityLevel → σ → β) (L : SecurityLevel)
    (s t : σ) : Prop :=
  obs L s = obs L t

namespace obs_equiv

variable {σ β : Type*} (obs : SecurityLevel → σ → β)

theorem refl (L : SecurityLevel) (s : σ) : obs_equiv obs L s s := rfl

theorem symm {L : SecurityLevel} {s t : σ} (h : obs_equiv obs L s t) :
    obs_equiv obs L t s := h.symm

theorem trans {L : SecurityLevel} {s t u : σ}
    (hst : obs_equiv obs L s t) (htu : obs_equiv obs L t u) :
    obs_equiv obs L s u := hst.trans htu

/-- `obs_equiv` is an equivalence relation. -/
theorem equivalence (L : SecurityLevel) : Equivalence (obs_equiv obs L) :=
  ⟨refl obs L, @symm σ β obs L, @trans σ β obs L⟩

end obs_equiv

/-──────────────────────────────────────────────────────────────────────────────
  §4  Lattice-Level Non-Interference Property

  The lattice-level NI property: if two executions start in states that
  are L-equivalent, they produce L-equivalent observations at every step.
──────────────────────────────────────────────────────────────────────────────-/

/-- Non-interference predicate over a transition system. -/
def NonInterference {σ β : Type*}
    (step : σ → σ → Prop)
    (obs  : SecurityLevel → σ → β)
    (L    : SecurityLevel) : Prop :=
  ∀ s t s' : σ,
    obs_equiv obs L s t →
    step s s' →
    ∃ t' : σ, step t t' ∧ obs_equiv obs L s' t'

/-- Stronger stuttering-free NI: both systems take the same number of steps. -/
def StrictNI {σ β : Type*}
    (step : σ → σ → Prop)
    (obs  : SecurityLevel → σ → β)
    (L    : SecurityLevel) : Prop :=
  ∀ s t s' : σ,
    obs_equiv obs L s t →
    step s s' →
    ∀ t' : σ, step t t' → obs_equiv obs L s' t'

/-- StrictNI implies NI when the step relation is total. -/
theorem strict_ni_implies_ni {σ β : Type*}
    (step : σ → σ → Prop)
    (obs  : SecurityLevel → σ → β)
    (L    : SecurityLevel)
    (total : ∀ s : σ, ∃ s' : σ, step s s')
    (hStrict : StrictNI step obs L) :
    NonInterference step obs L := by
  intro s t s' hequiv hstep
  obtain ⟨t', ht'⟩ := total t
  exact ⟨t', ht', hStrict s t s' hequiv hstep t' ht'⟩

/-──────────────────────────────────────────────────────────────────────────────
  §5  Lattice Closure Properties

  Used by ComplianceGalois.lean to establish that compliance sets are closed
  under joins and meets.
──────────────────────────────────────────────────────────────────────────────-/

/-- A set S of security levels is join-closed if L₁ ∈ S ∧ L₂ ∈ S → L₁ ⊔ L₂ ∈ S. -/
def JoinClosed (S : Set SecurityLevel) : Prop :=
  ∀ L₁ L₂ : SecurityLevel, L₁ ∈ S → L₂ ∈ S → (L₁ ⊔ L₂) ∈ S

/-- A set S is meet-closed if L₁ ∈ S ∧ L₂ ∈ S → L₁ ⊓ L₂ ∈ S. -/
def MeetClosed (S : Set SecurityLevel) : Prop :=
  ∀ L₁ L₂ : SecurityLevel, L₁ ∈ S → L₂ ∈ S → (L₁ ⊓ L₂) ∈ S

/-- A sublattice is both join- and meet-closed. -/
def Sublattice (S : Set SecurityLevel) : Prop :=
  JoinClosed S ∧ MeetClosed S

/-- The full set `{EL0, EL1, EL2, EL3}` is a sublattice. -/
theorem univ_is_sublattice : Sublattice Set.univ := by
  constructor
  · intro L₁ L₂ _ _; exact Set.mem_univ _
  · intro L₁ L₂ _ _; exact Set.mem_univ _

/-- The set `{EL0}` is join-closed. -/
theorem bot_set_join_closed : JoinClosed {SecurityLevel.EL0} := by
  intro L₁ L₂ h₁ h₂
  simp [Set.mem_singleton_iff] at *
  rw [h₁, h₂]
  simp [SecurityLevel.join, SecurityLevel.rank]

/-- The set `{EL2, EL3}` (hypervisor and above) is join-closed. -/
theorem hypervisor_set_join_closed :
    JoinClosed {SecurityLevel.EL2, SecurityLevel.EL3} := by
  intro L₁ L₂ h₁ h₂
  simp [Set.mem_insert_iff, Set.mem_singleton_iff] at *
  rcases h₁ with rfl | rfl <;> rcases h₂ with rfl | rfl
  · left; simp [SecurityLevel.join, SecurityLevel.rank]
  · right; simp [SecurityLevel.join, SecurityLevel.rank]
  · right; simp [SecurityLevel.join, SecurityLevel.rank]
  · right; simp [SecurityLevel.join, SecurityLevel.rank]

/-──────────────────────────────────────────────────────────────────────────────
  §6  Lattice Ordering Proofs for the Four-Point Chain
──────────────────────────────────────────────────────────────────────────────-/

section ChainOrder

open SecurityLevel

theorem chain_EL0_EL0 : EL0 ≤ EL0 := SecurityLevel.le_refl _
theorem chain_EL0_EL1 : EL0 ≤ EL1 := EL0_le_EL1
theorem chain_EL0_EL2 : EL0 ≤ EL2 := SecurityLevel.le_trans EL0_le_EL1 EL1_le_EL2
theorem chain_EL0_EL3 : EL0 ≤ EL3 := SecurityLevel.le_trans chain_EL0_EL2 EL2_le_EL3
theorem chain_EL1_EL1 : EL1 ≤ EL1 := SecurityLevel.le_refl _
theorem chain_EL1_EL2 : EL1 ≤ EL2 := EL1_le_EL2
theorem chain_EL1_EL3 : EL1 ≤ EL3 := SecurityLevel.le_trans EL1_le_EL2 EL2_le_EL3
theorem chain_EL2_EL2 : EL2 ≤ EL2 := SecurityLevel.le_refl _
theorem chain_EL2_EL3 : EL2 ≤ EL3 := EL2_le_EL3
theorem chain_EL3_EL3 : EL3 ≤ EL3 := SecurityLevel.le_refl _

/-- All non-trivial strict inequalities. -/
theorem chain_strict_EL0_EL1 : EL0 < EL1 := by simp
theorem chain_strict_EL1_EL2 : EL1 < EL2 := by simp
theorem chain_strict_EL2_EL3 : EL2 < EL3 := by simp

/-- No upward violation: higher level does not dominate a strictly lower one. -/
theorem not_EL1_le_EL0 : ¬(EL1 ≤ EL0) := by simp
theorem not_EL2_le_EL0 : ¬(EL2 ≤ EL0) := by simp
theorem not_EL2_le_EL1 : ¬(EL2 ≤ EL1) := by simp
theorem not_EL3_le_EL0 : ¬(EL3 ≤ EL0) := by simp
theorem not_EL3_le_EL1 : ¬(EL3 ≤ EL1) := by simp
theorem not_EL3_le_EL2 : ¬(EL3 ≤ EL2) := by simp

end ChainOrder

/-──────────────────────────────────────────────────────────────────────────────
  §7  Join Characterisation Lemmas

  Explicit computation of join for all 16 pairs.  These replace repeated
  automation calls in downstream files where definitional reduction is needed.
──────────────────────────────────────────────────────────────────────────────-/

section JoinMeetFacts

open SecurityLevel

@[simp] theorem join_EL0_EL0 : EL0 ⊔ₛ EL0 = EL0 := by simp [join, rank]
@[simp] theorem join_EL0_EL1 : EL0 ⊔ₛ EL1 = EL1 := by simp [join, rank]
@[simp] theorem join_EL0_EL2 : EL0 ⊔ₛ EL2 = EL2 := by simp [join, rank]
@[simp] theorem join_EL0_EL3 : EL0 ⊔ₛ EL3 = EL3 := by simp [join, rank]
@[simp] theorem join_EL1_EL0 : EL1 ⊔ₛ EL0 = EL1 := by simp [join, rank]
@[simp] theorem join_EL1_EL1 : EL1 ⊔ₛ EL1 = EL1 := by simp [join, rank]
@[simp] theorem join_EL1_EL2 : EL1 ⊔ₛ EL2 = EL2 := by simp [join, rank]
@[simp] theorem join_EL1_EL3 : EL1 ⊔ₛ EL3 = EL3 := by simp [join, rank]
@[simp] theorem join_EL2_EL0 : EL2 ⊔ₛ EL0 = EL2 := by simp [join, rank]
@[simp] theorem join_EL2_EL1 : EL2 ⊔ₛ EL1 = EL2 := by simp [join, rank]
@[simp] theorem join_EL2_EL2 : EL2 ⊔ₛ EL2 = EL2 := by simp [join, rank]
@[simp] theorem join_EL2_EL3 : EL2 ⊔ₛ EL3 = EL3 := by simp [join, rank]
@[simp] theorem join_EL3_EL0 : EL3 ⊔ₛ EL0 = EL3 := by simp [join, rank]
@[simp] theorem join_EL3_EL1 : EL3 ⊔ₛ EL1 = EL3 := by simp [join, rank]
@[simp] theorem join_EL3_EL2 : EL3 ⊔ₛ EL2 = EL3 := by simp [join, rank]
@[simp] theorem join_EL3_EL3 : EL3 ⊔ₛ EL3 = EL3 := by simp [join, rank]

@[simp] theorem meet_EL0_EL0 : EL0 ⊓ₛ EL0 = EL0 := by simp [meet, rank]
@[simp] theorem meet_EL0_EL1 : EL0 ⊓ₛ EL1 = EL0 := by simp [meet, rank]
@[simp] theorem meet_EL0_EL2 : EL0 ⊓ₛ EL2 = EL0 := by simp [meet, rank]
@[simp] theorem meet_EL0_EL3 : EL0 ⊓ₛ EL3 = EL0 := by simp [meet, rank]
@[simp] theorem meet_EL1_EL0 : EL1 ⊓ₛ EL0 = EL0 := by simp [meet, rank]
@[simp] theorem meet_EL1_EL1 : EL1 ⊓ₛ EL1 = EL1 := by simp [meet, rank]
@[simp] theorem meet_EL1_EL2 : EL1 ⊓ₛ EL2 = EL1 := by simp [meet, rank]
@[simp] theorem meet_EL1_EL3 : EL1 ⊓ₛ EL3 = EL1 := by simp [meet, rank]
@[simp] theorem meet_EL2_EL0 : EL2 ⊓ₛ EL0 = EL0 := by simp [meet, rank]
@[simp] theorem meet_EL2_EL1 : EL2 ⊓ₛ EL1 = EL1 := by simp [meet, rank]
@[simp] theorem meet_EL2_EL2 : EL2 ⊓ₛ EL2 = EL2 := by simp [meet, rank]
@[simp] theorem meet_EL2_EL3 : EL2 ⊓ₛ EL3 = EL2 := by simp [meet, rank]
@[simp] theorem meet_EL3_EL0 : EL3 ⊓ₛ EL0 = EL0 := by simp [meet, rank]
@[simp] theorem meet_EL3_EL1 : EL3 ⊓ₛ EL1 = EL1 := by simp [meet, rank]
@[simp] theorem meet_EL3_EL2 : EL3 ⊓ₛ EL2 = EL2 := by simp [meet, rank]
@[simp] theorem meet_EL3_EL3 : EL3 ⊓ₛ EL3 = EL3 := by simp [meet, rank]

end JoinMeetFacts

end ARMSecurity
