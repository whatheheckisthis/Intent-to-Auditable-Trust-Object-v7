# Cyber Risk Management Controls Document

**Document ID:** IATO-CRM-001  
**Version:** 1.0  
**Owner:** Security & GRC  
**Approved By:** Engineering Leadership / Risk Committee  
**Effective Date:** 2026-02-16  
**Review Frequency:** Quarterly (or upon material change)

---

## 1. Purpose

This document defines the cyber risk management control framework for the **Intent-to-Auditable-Trust-Object (IATO)** repository. It establishes governance, control objectives, implementation expectations, and evidence requirements using standard GRC language aligned to recognized frameworks (SOC 2, OWASP ASVS, and ASD Essential Eight).

## 2. Scope

This controls document applies to:
- Source code, automation scripts, and deployment artifacts in this repository.
- Development, security, operations, and governance workflows that create, modify, deploy, or monitor repository assets.
- Control evidence generated from CI/CD, observability systems, and change-management records.

Out of scope:
- External third-party systems not integrated with repository workflows.
- Organizational policy domains unrelated to cyber risk (e.g., finance-only controls).

## 3. Governance and Accountability

| Role | Accountability | Core Responsibilities |
|---|---|---|
| Control Owner | Accountable | Defines control design, approves exceptions, validates operating effectiveness |
| Control Operator | Responsible | Executes control activities and maintains operational evidence |
| Security/GRC | Accountable/Consulted | Maps controls to framework requirements, coordinates assessments |
| Platform/SRE | Responsible | Maintains technical guardrails, telemetry, incident readiness |
| Internal Audit | Independent Assurance | Evaluates control design and operating effectiveness |

## 4. Risk Management Methodology

### 4.1 Risk Lifecycle
1. **Identify** threats, vulnerabilities, and trust-boundary changes.
2. **Assess** impact and likelihood using a defined risk rating matrix.
3. **Treat** via control implementation, risk transfer, avoidance, or acceptance.
4. **Monitor** through continuous control testing and telemetry.
5. **Report** to stakeholders with exception status and residual risk.

### 4.2 Risk Rating Model

| Likelihood \ Impact | Low | Medium | High |
|---|---:|---:|---:|
| Low | Low | Low | Medium |
| Medium | Low | Medium | High |
| High | Medium | High | Critical |

Risk acceptance for **High** and **Critical** residual risk requires documented approval by the designated risk authority.

## 5. Control Objectives and Control Set

### 5.1 Identity and Access Management (IAM)
**Objective:** Restrict access to authorized users and enforce least privilege.

Key controls:
- Role-based access control with periodic recertification.
- MFA for privileged and remote access paths.
- Joiner-Mover-Leaver workflow with timely deprovisioning.
- Break-glass access with explicit logging and post-use review.

Evidence examples:
- Access review records, IAM policy diffs, authentication logs, ticket approvals.

### 5.2 Secure Configuration and Hardening
**Objective:** Ensure secure baseline configurations and controlled change.

Key controls:
- Baseline configuration standards for runtime and infrastructure.
- Configuration drift monitoring and remediation.
- Formal approval for production-impacting configuration changes.

Evidence examples:
- Configuration scan results, hardening checklists, approved change tickets.

### 5.3 Vulnerability and Patch Management
**Objective:** Reduce exploitability through timely remediation.

Key controls:
- Continuous vulnerability identification for code and dependencies.
- Risk-based remediation SLAs and exception workflow.
- Emergency patch process for actively exploited vulnerabilities.

Evidence examples:
- Vulnerability scan reports, remediation tickets, SLA aging reports.

### 5.4 Logging, Monitoring, and Detection
**Objective:** Provide timely detection of anomalous and malicious activity.

Key controls:
- Centralized collection of logs/metrics/traces.
- Alerting thresholds aligned to business and security risk.
- Detection coverage reviews for high-risk assets.

Evidence examples:
- Alert runbooks, SIEM dashboards, incident trigger logs.

### 5.5 Incident Response and Recovery
**Objective:** Contain incidents, restore service, and capture lessons learned.

Key controls:
- Documented incident response plan and severity matrix.
- Tabletop exercises and simulation cadence.
- Recovery testing against RTO/RPO commitments.

Evidence examples:
- Incident timelines, post-incident reviews, backup/restore test outcomes.

### 5.6 Auditability and Evidence Integrity
**Objective:** Produce complete, tamper-evident evidence supporting assurance activities.

Key controls:
- Immutable evidence storage with retention requirements.
- Cryptographic hashing and chain-of-custody metadata.
- Control-to-evidence mapping maintained and reviewable.

Evidence examples:
- Hash manifests, retention policy artifacts, control mapping exports.

## 6. Compliance Mapping

| Control Domain | SOC 2 | OWASP ASVS | Essential Eight |
|---|---|---|---|
| IAM | CC6.1, CC6.2, CC6.3 | V2, V3 | MFA, Restrict Admin Privileges |
| Configuration Hardening | CC5.2, CC8.1 | V1, V14 | Application Control, User Application Hardening |
| Vulnerability/Patching | CC7.1, CC7.2 | V1.2, V14.2 | Patch Applications, Patch Operating Systems |
| Monitoring/Detection | CC7.2, CC7.3 | V7, V10 | Monitoring |
| Incident/Recovery | CC7.4, CC7.5 | V1.14, V10.3 | Backups |
| Evidence/Governance | CC3.2, CC4.1 | V1.1, V13 | Governance |

## 7. Control Testing and Assurance

- **Design Effectiveness Reviews:** Validate control design against risk scenarios at least annually.
- **Operating Effectiveness Testing:** Perform periodic sampling of control execution and evidence completeness.
- **Continuous Control Monitoring:** Automate checks in CI/CD where practical.
- **Issue Management:** Log deficiencies, assign owners, and track remediation through closure.

## 8. Exceptions and Risk Acceptance

Control exceptions must include:
- Business justification.
- Risk impact statement and compensating controls.
- Expiry date and review cadence.
- Named approver and remediation plan.

Expired exceptions must be remediated or formally renewed before continued operation.

## 9. Metrics and Reporting

Recommended KPI/KRI set:
- Percentage of controls passing scheduled tests.
- Mean time to remediate critical vulnerabilities.
- Percentage of privileged accounts recertified within cycle.
- Mean time to detect (MTTD) and mean time to respond (MTTR).
- Number of open exceptions past expiry.

Reports should be distributed to engineering leadership, security, and GRC stakeholders on a defined cadence.

## 10. Document Control and Maintenance

- This document is version controlled in-repo.
- Material changes require owner review and approval.
- Review history should be maintained through pull request records and commit metadata.

---

## Appendix A: Minimum Evidence Record

| Field | Requirement |
|---|---|
| control_id | Required |
| service_or_asset | Required |
| environment | Required |
| timestamp_utc | Required |
| control_result | Required |
| evidence_uri | Required |
| hash_sha256 | Required |
| mapped_framework_refs | Required |
| exception_id | Conditional |
| approver | Conditional |
