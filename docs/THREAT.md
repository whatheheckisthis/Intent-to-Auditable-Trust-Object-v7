# IĀTŌ-V7 — Threat Model

## 1. Purpose
Defines adversaries, trust boundaries, and security claims for the IĀTŌ-V7 trust path.

## 2. System Overview
DMA permission exists iff a valid, unexpired, non-replayed, SPDM-bound credential is validated at EL2 and written into SMMU STE by EL2 code.

## 3. Trust Boundaries
- **B1 EL2/EL1**: SMC credential blobs cross; SMMU MMIO, PCR state, nonce store do not.
- **B2 Python/C**: raw credential + stream ID in; PA range/perms out.
- **B3 EL2/TPM**: sealed trust metadata crosses; private key does not.
- **B4 EL2/SPDM**: SPDM protocol messages cross; only session binding metadata is exported.

## 4. Adversary Model
- **A1 Compromised EL1 kernel**: can craft SMC inputs, cannot directly write SMMU tables.
- **A2 Credential forger**: can replay observations, cannot forge valid signature without key.
- **A3 Timing observer**: can measure outer scripts, not sub-millisecond EL2 internals.
- **A4 PCR manipulator**: can drift PCR post-enrollment; verification must fail.
- **A5 SPDM MITM**: can relay/modify traffic, cannot forge authenticated device identity.

## 5. Security Claims
Core invariants are enforced jointly by EL2 C (SMC boundary/rate-limits/SMMU writes) and Python validator (semantic checks/binding checks), with host and integration tests covering both layers.

## 6. Explicit Non-Goals
No protection is claimed for physical/JTAG attackers, compromised EL3 firmware, side-channel resistant cryptography internals, full DoS prevention, SMP race-proofing, or at-rest filesystem key integrity.

## 7. Audit Trail
The journal and test result artifacts record validation outcomes, STE transitions, sweep events, and relevant identity bindings per provision request.

## 8. Assumptions
QEMU SMMUv3, swtpm, and SPDM responder correctness; EL2 exclusivity; guest lacks SMMU MMIO mappings; sane timer frequency configuration.
