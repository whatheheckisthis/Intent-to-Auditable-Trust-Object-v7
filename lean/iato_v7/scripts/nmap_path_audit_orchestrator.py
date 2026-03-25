#!/usr/bin/env python3
"""IATO-V7 deterministic filesystem audit orchestrator.

Produces three delivery artefacts per run:
1) Canonical XML audit artefact
2) Deterministic JSON policy snapshot derived from TOML intent
3) Append-only MCP orchestration log (JSONL)
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pwd
import grp
import stat
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any
import xml.etree.ElementTree as ET

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python <3.11 fallback
    import tomli as tomllib

REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_CONFIG = REPO_ROOT / "config.toml"
DEFAULT_XML_OUT = REPO_ROOT / "lean/iato_v7/nmap-path-state.xml"
DEFAULT_POLICY_OUT = REPO_ROOT / "lean/iato_v7/.nmap-path-policy.json"
DEFAULT_LOG_OUT = REPO_ROOT / "lean/iato_v7/mcp-orchestration.jsonl"


class ConfigError(RuntimeError):
    """Raised when the manifest is invalid."""


@dataclass(frozen=True)
class TargetRule:
    rule_id: str
    path: str
    required: bool
    sha256: str | None
    owner: str | None
    group: str | None
    mode: str | None


@dataclass(frozen=True)
class Manifest:
    schema_version: str
    project: str
    release: str
    root_path: str
    target: str
    fail_on_deviation: bool
    xml_output: Path
    policy_output: Path
    log_output: Path
    targets: tuple[TargetRule, ...]


def _read_toml(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise ConfigError(f"config not found: {path}")
    return tomllib.loads(path.read_text(encoding="utf-8"))


def _require_str(container: dict[str, Any], key: str, context: str) -> str:
    value = container.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ConfigError(f"missing/invalid string: {context}.{key}")
    return value.strip()


def _resolve_artifact(path_value: str, fallback: Path) -> Path:
    candidate = Path(path_value)
    if not str(candidate):
        return fallback
    return candidate if candidate.is_absolute() else (REPO_ROOT / candidate)


def _normalize_mode(mode: str | None) -> str | None:
    if mode is None:
        return None
    normalized = mode.strip()
    if len(normalized) == 3 and normalized.isdigit():
        normalized = f"0{normalized}"
    if len(normalized) != 4 or not normalized.isdigit():
        raise ConfigError(f"invalid mode '{mode}', expected 3/4 digit octal string")
    return normalized


def parse_manifest(path: Path) -> Manifest:
    raw = _read_toml(path)

    schema_version = _require_str(raw, "schema_version", "root")
    project = _require_str(raw, "project", "root")
    release = _require_str(raw, "release", "root")

    audit = raw.get("audit")
    artifacts = raw.get("artifacts")
    targets_raw = raw.get("targets")

    if not isinstance(audit, dict):
        raise ConfigError("missing [audit] table")
    if not isinstance(artifacts, dict):
        raise ConfigError("missing [artifacts] table")
    if not isinstance(targets_raw, list) or not targets_raw:
        raise ConfigError("missing [[targets]] entries")

    root_path = _require_str(audit, "root_path", "audit")
    target = _require_str(audit, "target", "audit")
    fail_on_deviation = bool(audit.get("fail_on_deviation", True))

    xml_output = _resolve_artifact(str(artifacts.get("xml_output", DEFAULT_XML_OUT)), DEFAULT_XML_OUT)
    policy_output = _resolve_artifact(
        str(artifacts.get("policy_output", DEFAULT_POLICY_OUT)), DEFAULT_POLICY_OUT
    )
    log_output = _resolve_artifact(str(artifacts.get("log_output", DEFAULT_LOG_OUT)), DEFAULT_LOG_OUT)

    parsed_targets: list[TargetRule] = []
    for idx, raw_target in enumerate(targets_raw):
        if not isinstance(raw_target, dict):
            raise ConfigError(f"targets[{idx}] must be a table")
        rule_id = _require_str(raw_target, "id", f"targets[{idx}]")
        target_path = _require_str(raw_target, "path", f"targets[{idx}]")
        required = bool(raw_target.get("required", True))
        sha256 = raw_target.get("sha256")
        owner = raw_target.get("owner")
        group_name = raw_target.get("group")
        mode = _normalize_mode(raw_target.get("mode"))

        if sha256 is not None and (not isinstance(sha256, str) or len(sha256.strip()) != 64):
            raise ConfigError(f"targets[{idx}].sha256 must be a 64-char hex string")

        parsed_targets.append(
            TargetRule(
                rule_id=rule_id,
                path=target_path,
                required=required,
                sha256=sha256.strip() if isinstance(sha256, str) else None,
                owner=owner.strip() if isinstance(owner, str) else None,
                group=group_name.strip() if isinstance(group_name, str) else None,
                mode=mode,
            )
        )

    return Manifest(
        schema_version=schema_version,
        project=project,
        release=release,
        root_path=root_path,
        target=target,
        fail_on_deviation=fail_on_deviation,
        xml_output=xml_output,
        policy_output=policy_output,
        log_output=log_output,
        targets=tuple(sorted(parsed_targets, key=lambda rule: (rule.rule_id, rule.path))),
    )


def compute_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve_target_path(root_path: str, configured_path: str) -> Path:
    candidate = Path(configured_path)
    if candidate.is_absolute():
        return candidate
    return Path(root_path) / candidate


def expected_uid(owner: str | None) -> int | None:
    if owner is None:
        return None
    if owner.isdigit():
        return int(owner)
    return pwd.getpwnam(owner).pw_uid


def expected_gid(group_name: str | None) -> int | None:
    if group_name is None:
        return None
    if group_name.isdigit():
        return int(group_name)
    return grp.getgrnam(group_name).gr_gid


def evaluate_targets(manifest: Manifest) -> tuple[list[dict[str, Any]], int]:
    evaluated: list[dict[str, Any]] = []
    deviation_count = 0

    for rule in manifest.targets:
        target_path = resolve_target_path(manifest.root_path, rule.path)
        deviations: list[str] = []
        observed: dict[str, Any] = {
            "exists": target_path.exists(),
            "sha256": None,
            "uid": None,
            "gid": None,
            "mode": None,
            "size": None,
        }

        if observed["exists"]:
            st = target_path.stat()
            observed["uid"] = st.st_uid
            observed["gid"] = st.st_gid
            observed["mode"] = format(stat.S_IMODE(st.st_mode), "04o")
            observed["size"] = st.st_size
            if target_path.is_file():
                observed["sha256"] = compute_sha256(target_path)

        if rule.required and not observed["exists"]:
            deviations.append("missing_required_path")
        if rule.sha256 and observed["exists"] and observed["sha256"] != rule.sha256:
            deviations.append("sha256_mismatch")
        if rule.mode and observed["exists"] and observed["mode"] != rule.mode:
            deviations.append("mode_mismatch")
        if rule.owner is not None and observed["exists"]:
            if observed["uid"] != expected_uid(rule.owner):
                deviations.append("owner_mismatch")
        if rule.group is not None and observed["exists"]:
            if observed["gid"] != expected_gid(rule.group):
                deviations.append("group_mismatch")

        deviation_count += len(deviations)
        evaluated.append(
            {
                "id": rule.rule_id,
                "path": str(target_path),
                "configured_path": rule.path,
                "required": rule.required,
                "expected": {
                    "sha256": rule.sha256,
                    "owner": rule.owner,
                    "group": rule.group,
                    "mode": rule.mode,
                },
                "observed": observed,
                "deviations": deviations,
                "status": "Clean" if not deviations else "Dirty",
            }
        )

    return evaluated, deviation_count


def write_policy_snapshot(manifest: Manifest) -> None:
    payload = {
        "schema_version": manifest.schema_version,
        "project": manifest.project,
        "release": manifest.release,
        "root_path": manifest.root_path,
        "target": manifest.target,
        "rules": [
            {
                "id": t.rule_id,
                "path": t.path,
                "required": t.required,
                "sha256": t.sha256,
                "owner": t.owner,
                "group": t.group,
                "mode": t.mode,
            }
            for t in manifest.targets
        ],
    }
    manifest.policy_output.parent.mkdir(parents=True, exist_ok=True)
    manifest.policy_output.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


def write_canonical_xml(manifest: Manifest, evaluated: list[dict[str, Any]], deviation_count: int) -> None:
    status = "Clean" if deviation_count == 0 else "Dirty"
    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()

    root = ET.Element(
        "iato_path_audit",
        {
            "schema_version": manifest.schema_version,
            "project": manifest.project,
            "release": manifest.release,
            "generated_at": generated_at,
        },
    )
    ET.SubElement(
        root,
        "summary",
        {
            "status": status,
            "evaluated_targets": str(len(evaluated)),
            "deviation_count": str(deviation_count),
        },
    )

    targets_el = ET.SubElement(root, "targets")
    for item in sorted(evaluated, key=lambda row: (row["id"], row["configured_path"])):
        t_el = ET.SubElement(
            targets_el,
            "target",
            {
                "id": item["id"],
                "path": item["path"],
                "configured_path": item["configured_path"],
                "required": str(item["required"]).lower(),
                "status": item["status"],
            },
        )
        ET.SubElement(
            t_el,
            "expected",
            {k: "" if v is None else str(v) for k, v in item["expected"].items()},
        )
        ET.SubElement(
            t_el,
            "observed",
            {k: "" if v is None else str(v) for k, v in item["observed"].items()},
        )
        deviations_el = ET.SubElement(t_el, "deviations")
        for code in item["deviations"]:
            ET.SubElement(deviations_el, "deviation", {"code": code})

    ET.indent(root, space="  ")
    xml_text = ET.tostring(root, encoding="unicode")

    manifest.xml_output.parent.mkdir(parents=True, exist_ok=True)
    manifest.xml_output.write_text('<?xml version="1.0" encoding="UTF-8"?>\n' + xml_text + "\n", encoding="utf-8")


def validate_xml_schema(xml_path: Path) -> None:
    tree = ET.parse(xml_path)
    root = tree.getroot()
    if root.tag != "iato_path_audit":
        raise ConfigError("xml schema validation failed: root element must be iato_path_audit")

    required_root_attrs = ["schema_version", "project", "release", "generated_at"]
    for attr in required_root_attrs:
        if attr not in root.attrib or not root.attrib[attr]:
            raise ConfigError(f"xml schema validation failed: missing root attribute '{attr}'")

    summary = root.find("summary")
    if summary is None:
        raise ConfigError("xml schema validation failed: missing summary node")

    if summary.get("status") not in {"Clean", "Dirty"}:
        raise ConfigError("xml schema validation failed: summary status must be Clean or Dirty")


def append_mcp_log(
    manifest: Manifest,
    command_chain: list[str],
    exit_state: str,
    deviation_flag: bool,
) -> None:
    script_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    payload = {
        "timestamp": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "script_version_hash": script_hash,
        "command_chain": command_chain,
        "exit_state": exit_state,
        "deviation_flag": deviation_flag,
    }
    manifest.log_output.parent.mkdir(parents=True, exist_ok=True)
    with manifest.log_output.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="IATO-V7 deterministic path audit")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    command_chain = [
        "load_manifest",
        "write_policy_snapshot",
        "evaluate_targets",
        "write_canonical_xml",
        "validate_xml_schema",
    ]

    try:
        manifest = parse_manifest(args.config)

        print("[iato-v7] deterministic orchestration context:")
        print(f"  config={args.config}")
        print(f"  xml_output={manifest.xml_output}")
        print(f"  policy_output={manifest.policy_output}")
        print(f"  log_output={manifest.log_output}")
        print(f"  declared_targets={len(manifest.targets)}")

        if args.dry_run:
            append_mcp_log(manifest, command_chain, "dry_run", False)
            return 0

        write_policy_snapshot(manifest)
        evaluated, deviation_count = evaluate_targets(manifest)
        write_canonical_xml(manifest, evaluated, deviation_count)
        validate_xml_schema(manifest.xml_output)

        dirty = deviation_count > 0
        if dirty and manifest.fail_on_deviation:
            append_mcp_log(manifest, command_chain, "dirty", True)
            return 3

        append_mcp_log(manifest, command_chain, "clean", False)
        return 0
    except Exception as exc:  # pragma: no cover - runtime guard
        print(f"[iato-v7] orchestration failure: {exc}", file=sys.stderr)
        # best effort log write when config parses cleanly
        try:
            manifest = parse_manifest(args.config)
            append_mcp_log(manifest, command_chain, "error", True)
        except Exception:
            pass
        return 2


if __name__ == "__main__":
    sys.exit(main())
