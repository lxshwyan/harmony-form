#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/env.sh"

cd "${PROJECT_DIR}"
bash "${HVIGORW}" clean --no-daemon
"${SCRIPT_DIR}/test-local.sh"
"${SCRIPT_DIR}/build-release.sh"
"${SCRIPT_DIR}/scan-har.sh"

HAP_FILE="${PROJECT_DIR}/entry/build/default/outputs/default/entry-default-unsigned.hap"
if [[ ! -s "${HAP_FILE}" ]]; then
  echo "Release demo HAP not found or empty: ${HAP_FILE}" >&2
  exit 1
fi

echo "@hmkit/form verification passed."
