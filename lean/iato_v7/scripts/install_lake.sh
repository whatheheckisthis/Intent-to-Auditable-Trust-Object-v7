#!/usr/bin/env bash
# Install or locate the Lean/Lake toolchain declared by lean-toolchain.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

ELAN_BIN="${ELAN_HOME}/bin/elan"
LEAN_BIN="${ELAN_HOME}/bin/lean"
LAKE_BIN="${ELAN_HOME}/bin/lake"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

print_versions() {
  echo "Lean toolchain: ${IATO_V7_TOOLCHAIN}"
  if have_cmd lean; then lean --version || true; fi
  if have_cmd lake; then lake --version || true; fi
  if [[ -x "${ELAN_BIN}" ]]; then "${ELAN_BIN}" --version || true; fi
}

if have_cmd lake && have_cmd lean; then
  print_versions
  exit 0
fi

mkdir -p "${ELAN_HOME}/bin"

if ! [[ -x "${ELAN_BIN}" ]]; then
  TMPDIR="$(mktemp -d)"
  cleanup() { rm -rf "${TMPDIR}"; }
  trap cleanup EXIT

  if have_cmd curl; then
    echo "Downloading elan installer from leanprover/elan..."
    if curl -fsSL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -o "${TMPDIR}/elan-init.sh"; then
      sh "${TMPDIR}/elan-init.sh" -y --default-toolchain none
    elif curl -fsSL https://github.com/leanprover/elan/releases/latest/download/elan-x86_64-unknown-linux-gnu.tar.gz -o "${TMPDIR}/elan.tar.gz"; then
      tar -xzf "${TMPDIR}/elan.tar.gz" -C "${TMPDIR}"
      "${TMPDIR}/elan-init" -y --default-toolchain none
    fi
  elif have_cmd wget; then
    echo "Downloading elan installer from leanprover/elan with wget..."
    if wget -qO "${TMPDIR}/elan-init.sh" https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh; then
      sh "${TMPDIR}/elan-init.sh" -y --default-toolchain none
    elif wget -qO "${TMPDIR}/elan.tar.gz" https://github.com/leanprover/elan/releases/latest/download/elan-x86_64-unknown-linux-gnu.tar.gz; then
      tar -xzf "${TMPDIR}/elan.tar.gz" -C "${TMPDIR}"
      "${TMPDIR}/elan-init" -y --default-toolchain none
    fi
  fi
fi

if ! [[ -x "${ELAN_BIN}" ]] && have_cmd apt-get; then
  echo "Falling back to apt-get install elan..."
  if ! (apt-get update && apt-get install -y elan); then
    echo "warning: apt-get fallback could not install elan" >&2
  fi
fi

if ! [[ -x "${ELAN_BIN}" ]] && have_cmd elan; then
  ELAN_BIN="$(command -v elan)"
fi

if ! [[ -x "${ELAN_BIN}" ]]; then
  echo "error: unable to install or locate elan; check network/proxy policy" >&2
  exit 127
fi

"${ELAN_BIN}" toolchain install "${IATO_V7_TOOLCHAIN}"
"${ELAN_BIN}" default "${IATO_V7_TOOLCHAIN}"
print_versions

if ! have_cmd lake && ! [[ -x "${LAKE_BIN}" ]]; then
  echo "error: lake was not installed by the selected Lean toolchain" >&2
  exit 127
fi
