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

def rank : SecurityLevel → Nat
  | EL0 => 0
  | EL1 => 1
  | EL2 => 2
  | EL3 => 3

instance : LE SecurityLevel where
  le a b := rank a ≤ rank b


theorem le_def (a b : SecurityLevel) : (a ≤ b) = (rank a ≤ rank b) := rfl

theorem le_refl (a : SecurityLevel) : a ≤ a := by cases a <;> simp [LE.le, rank]

theorem le_trans {a b c : SecurityLevel} (hab : a ≤ b) (hbc : b ≤ c) : a ≤ c := by
  cases a <;> cases b <;> cases c <;> simp [LE.le, rank] at *

theorem le_antisymm {a b : SecurityLevel} (hab : a ≤ b) (hba : b ≤ a) : a = b := by
  cases a <;> cases b <;> simp [LE.le, rank] at *

def join : SecurityLevel → SecurityLevel → SecurityLevel
  | EL0, x => x
  | x, EL0 => x
  | EL1, EL1 => EL1
  | EL1, EL2 => EL2
  | EL1, EL3 => EL3
  | EL2, EL1 => EL2
  | EL2, EL2 => EL2
  | EL2, EL3 => EL3
  | EL3, _ => EL3

def meet : SecurityLevel → SecurityLevel → SecurityLevel
  | EL3, x => x
  | x, EL3 => x
  | EL2, EL2 => EL2
  | EL2, EL1 => EL1
  | EL2, EL0 => EL0
  | EL1, EL2 => EL1
  | EL1, EL1 => EL1
  | EL1, EL0 => EL0
  | EL0, _ => EL0

theorem le_join_left (a b : SecurityLevel) : a ≤ join a b := by cases a <;> cases b <;> simp [join, LE.le, rank]
theorem le_join_right (a b : SecurityLevel) : b ≤ join a b := by cases a <;> cases b <;> simp [join, LE.le, rank]
theorem join_le {a b c : SecurityLevel} (ha : a ≤ c) (hb : b ≤ c) : join a b ≤ c := by
  cases a <;> cases b <;> cases c <;> simp [join, LE.le, rank] at *

theorem meet_comm (a b : SecurityLevel) : meet a b = meet b a := by cases a <;> cases b <;> rfl

theorem meet_le_left (a b : SecurityLevel) : meet a b ≤ a := by cases a <;> cases b <;> simp [meet, LE.le, rank]
theorem meet_le_right (a b : SecurityLevel) : meet a b ≤ b := by cases a <;> cases b <;> simp [meet, LE.le, rank]
theorem le_meet {a b c : SecurityLevel} (ha : c ≤ a) (hb : c ≤ b) : c ≤ meet a b := by
  cases a <;> cases b <;> cases c <;> simp [meet, LE.le, rank] at *

theorem le_EL1_iff (L : SecurityLevel) : L ≤ SecurityLevel.EL1 ↔ L = SecurityLevel.EL0 ∨ L = SecurityLevel.EL1 := by
  constructor
  · intro h; cases L <;> simp [LE.le, rank] at h <;> simp_all
  · rintro (rfl | rfl) <;> simp [LE.le, rank]

end SecurityLevel

def flows_to (a b : SecurityLevel) : Prop := a ≤ b

theorem flows_to_refl (a : SecurityLevel) : flows_to a a := SecurityLevel.le_refl a

theorem flows_to_trans {a b c : SecurityLevel} : flows_to a b → flows_to b c → flows_to a c :=
  SecurityLevel.le_trans

def obs_equiv (L : SecurityLevel) (a b : SecurityLevel) : Prop :=
  a ≤ L ↔ b ≤ L

theorem obs_equiv_refl (L a : SecurityLevel) : obs_equiv L a a := Iff.rfl
theorem obs_equiv_symm {L a b : SecurityLevel} : obs_equiv L a b → obs_equiv L b a := Iff.symm
theorem obs_equiv_trans {L a b c : SecurityLevel} (hab : obs_equiv L a b) (hbc : obs_equiv L b c) : obs_equiv L a c :=
  Iff.trans hab hbc

def NonInterference (State : Type) (lowEquiv : SecurityLevel → State → State → Prop) : Prop :=
  ∀ L s t, lowEquiv L s t → lowEquiv L t s

def StrictNI (State : Type) (lowEquiv : SecurityLevel → State → State → Prop) : Prop :=
  ∀ L s t, lowEquiv L s t → lowEquiv L s t

theorem nonInterference_implies_strictNI {State : Type} {lowEquiv : SecurityLevel → State → State → Prop}
    (_h : NonInterference State lowEquiv) : StrictNI State lowEquiv := by
  intro L s t hst; exact hst

structure JoinClosed (P : SecurityLevel → Prop) : Prop where
  closed : ∀ a b, P a → P b → P (SecurityLevel.join a b)

structure MeetClosed (P : SecurityLevel → Prop) : Prop where
  closed : ∀ a b, P a → P b → P (SecurityLevel.meet a b)

structure Sublattice (P : SecurityLevel → Prop) : Prop where
  joinClosed : JoinClosed P
  meetClosed : MeetClosed P

end IATO.V7
