#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAR_FILE="${PROJECT_DIR}/form/build/default/outputs/default/form.har"

source "${SCRIPT_DIR}/env.sh"

cd "${PROJECT_DIR}"
"${SCRIPT_DIR}/verify.sh"
"${SCRIPT_DIR}/verify-external-consumer.sh"
"${SCRIPT_DIR}/verify-showcase.sh"
"${SCRIPT_DIR}/verify-validator-pilot.sh"
"${SCRIPT_DIR}/check-api-freeze.sh"

PACKAGE_JSON="$(tar -xOzf "${HAR_FILE}" package/oh-package.json5)"
if grep -Eq '"@hmkit/validator"[[:space:]]*:[[:space:]]*"file:' <<<"${PACKAGE_JSON}"; then
  echo "Release HAR contains a local validator dependency." >&2
  exit 1
fi

if rg -n --hidden \
  -g '!**/build/**' -g '!**/oh_modules/**' -g '!**/.hvigor/**' -g '!**/.test/**' \
  -g '!*.lock' -g '!*.ohpmignore' -g '!release-dry-run.sh' \
  '(-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|password[[:space:]]*[:=][[:space:]]*[^[:space:]]+)' \
  "${PROJECT_DIR}"; then
  echo "Potential credential material found." >&2
  exit 1
fi

"${OHPM}" prepublish "${HAR_FILE}"

if [[ "${HMKIT_RUN_SIMULATOR:-0}" == "1" ]]; then
  "${SCRIPT_DIR}/test-simulator.sh"
  "${SCRIPT_DIR}/test-showcase-simulator.sh"
fi

echo "Release dry-run passed. No package was published."
