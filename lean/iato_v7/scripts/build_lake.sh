#!/usr/bin/env bash
# Deterministic Lean/Lake build entrypoint for IATO-V7.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

RUN_UPDATE=1
RUN_TEST=1
TARGETS=()

for arg in "$@"; do
  case "${arg}" in
    --no-update) RUN_UPDATE=0 ;;
    --no-test) RUN_TEST=0 ;;
    *) TARGETS+=("${arg}") ;;
  esac
done

"${SCRIPT_DIR}/install_lake.sh"

cd "${IATO_V7_LEAN_DIR}"

if (( RUN_UPDATE )); then
  "${LAKE}" update
fi

if ((${#TARGETS[@]})); then
  "${LAKE}" build "${TARGETS[@]}"
else
  "${LAKE}" build
fi

if (( RUN_TEST )); then
  "${LAKE}" test
fi
