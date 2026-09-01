#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONSUMER_DIR="${PROJECT_DIR}/external-consumer"

source "${SCRIPT_DIR}/env.sh"

if [[ ! -f "${PROJECT_DIR}/form/build/default/outputs/default/form.har" ]]; then
  echo "Release HAR is missing; run ./scripts/build-release.sh first." >&2
  exit 1
fi

cd "${CONSUMER_DIR}"
"${OHPM}" clean
"${OHPM}" install --all

INSTALLED_FORM_DIR="$(find "${CONSUMER_DIR}/oh_modules/.ohpm" -type d -path '*/oh_modules/@hmkit/form' -print -quit)"
INSTALLED_VALIDATOR_DIR="$(find "${CONSUMER_DIR}/oh_modules/.ohpm" -type d -path '*/oh_modules/@hmkit/validator' -print -quit)"
if [[ -z "${INSTALLED_FORM_DIR}" ]]; then
  echo "Installed @hmkit/form package was not found." >&2
  exit 1
fi
if [[ -z "${INSTALLED_VALIDATOR_DIR}" ]] || \
  ! grep -Eq '"version"[[:space:]]*:[[:space:]]*"1\.0\.0"' "${INSTALLED_VALIDATOR_DIR}/oh-package.json5"; then
  echo "Independent consumer did not resolve @hmkit/validator 1.0.0." >&2
  exit 1
fi

HAR_INDEX_SUM="$(tar -xOzf "${PROJECT_DIR}/form/build/default/outputs/default/form.har" package/Index.d.ets | shasum -a 256 | awk '{print $1}')"
INSTALLED_INDEX_SUM="$(shasum -a 256 "${INSTALLED_FORM_DIR}/Index.d.ets" | awk '{print $1}')"
HAR_ABC_SUM="$(tar -xOzf "${PROJECT_DIR}/form/build/default/outputs/default/form.har" package/ets/modules.abc | shasum -a 256 | awk '{print $1}')"
INSTALLED_ABC_SUM="$(shasum -a 256 "${INSTALLED_FORM_DIR}/ets/modules.abc" | awk '{print $1}')"

if [[ "${HAR_INDEX_SUM}" != "${INSTALLED_INDEX_SUM}" || "${HAR_ABC_SUM}" != "${INSTALLED_ABC_SUM}" ]]; then
  echo "Installed @hmkit/form does not match the current release HAR." >&2
  exit 1
fi

bash "${HVIGORW}" clean --no-daemon
bash "${HVIGORW}" assembleHap --mode module \
  -p product=default -p module=entry@default -p buildMode=release --no-daemon

test -f "${CONSUMER_DIR}/entry/build/default/outputs/default/entry-default-unsigned.hap"
echo "Independent API 12 consumer verified against the current HAR and validator 1.0.0."
