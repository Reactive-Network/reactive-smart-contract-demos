#!/usr/bin/env bash
# Mirror .github/workflows/test.yml — Foundry build and test.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

export FOUNDRY_PROFILE="${FOUNDRY_PROFILE:-ci}"

if ! command -v forge >/dev/null 2>&1; then
  curl -L https://foundry.paradigm.xyz | bash
  export PATH="${HOME}/.foundry/bin:${PATH}"
  foundryup
fi

git submodule update --init --recursive

forge --version
forge build --sizes
forge test -vvv

echo "Foundry build and tests passed"
