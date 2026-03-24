# Worker Compatibility

This guide documents the worker compatibility audit flow and implementation narrative used during migration to IATO-V7.

## Scope

- **Input**: `workers/source/` contains legacy worker examples and source manifests.
- **Output**: `workers/target/` contains FEAT_RME-aligned manifests generated after compatibility checks.
- **Evidence**: `workers/reports/` contains scan reports and migration outputs for auditor review.

## Compatibility Criteria

A worker is considered compatible with the reference architecture when:

1. Its normalized domain is valid (`root`, `secure`, `normal`, or `peripheral`).
2. Its dependency set is well-formed (no empty dependency names).
3. Its domain/dependency combination does not conflict with secure reference workers.

## Audit Narrative

1. **Ingest** legacy records (CSV or pre-modeled records).
2. **Normalize** domains and dependencies.
3. **Scan** each worker against reference constraints.
4. **Report** compatible vs. incompatible workers into `workers/reports/scan_report.json`.
5. **Migrate** incompatible workers using generated remediation plan messages.
6. **Emit** FEAT_RME-aligned target manifests under `workers/target/`.

## Implementation Notes

- Lean scanner logic resides in:
  - `lean/iato_v7/IATO/V7/Scanner.lean`
  - `lean/iato_v7/IATO/V7/Architecture.lean`
- Supporting scripts live in:
  - `scripts/scan_workers.py`
  - `scripts/migrate.sh`

These components collectively produce traceable, repeatable compatibility outcomes suitable for internal assurance and external audit preparation.
