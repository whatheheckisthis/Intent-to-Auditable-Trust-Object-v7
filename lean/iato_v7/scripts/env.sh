#!/usr/bin/env bash
# Portable Lean/Lake environment for IATO-V7.
# Source this file before invoking Lake directly, or use build_lake.sh.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd -- "${PROJECT_DIR}/../.." && pwd)"

export IATO_V7_REPO_ROOT="${IATO_V7_REPO_ROOT:-${REPO_ROOT}}"
export IATO_V7_LEAN_DIR="${IATO_V7_LEAN_DIR:-${PROJECT_DIR}}"
export ELAN_HOME="${ELAN_HOME:-${HOME}/.elan}"
export PATH="${ELAN_HOME}/bin:${PATH}"
export LEAN_ABORT_ON_PANIC="${LEAN_ABORT_ON_PANIC:-1}"
export LAKE_NO_CACHE="${LAKE_NO_CACHE:-0}"
export IATO_V7_TOOLCHAIN="${IATO_V7_TOOLCHAIN:-$(cat "${PROJECT_DIR}/lean-toolchain")}"
export LEAN_PATH="${LEAN_PATH:-${PROJECT_DIR}/.lake/packages}"
export LEAN="${LEAN:-${ELAN_HOME}/bin/lean}"
export LAKE="${LAKE:-${ELAN_HOME}/bin/lake}"
