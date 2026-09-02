#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALIDATOR_DIR="$(cd "${PROJECT_DIR}/../harmony-validator" && pwd)"
HAR_FILE="${PROJECT_DIR}/form/build/default/outputs/default/form.har"
PILOT_HAP="${VALIDATOR_DIR}/entry/build/default/outputs/default/entry-default-unsigned.hap"

source "${SCRIPT_DIR}/env.sh"

[[ -s "${HAR_FILE}" ]] || { echo "Validator pilot: release form HAR missing" >&2; exit 1; }
[[ -x "${VALIDATOR_DIR}/scripts/verify.sh" ]] || { echo "Validator pilot repository is unavailable" >&2; exit 1; }

cd "${VALIDATOR_DIR}"
"${OHPM}" clean
INSTALL_OUTPUT="$("${OHPM}" install --all 2>&1)"
printf '%s\n' "${INSTALL_OUTPUT}"
if grep -Fq 'Found version conflict' <<<"${INSTALL_OUTPUT}"; then
  echo "Validator pilot install reported a dependency conflict." >&2
  exit 1
fi

INSTALLED_FORM_DIR="$(find "${VALIDATOR_DIR}/oh_modules/.ohpm" -type d -path '*/oh_modules/@hmkit/form' -print -quit)"
INSTALLED_VALIDATOR_DIR="$(find "${VALIDATOR_DIR}/oh_modules/.ohpm" -type d -path '*/oh_modules/@hmkit/validator' -print -quit)"
[[ -n "${INSTALLED_FORM_DIR}" ]] || { echo "Validator pilot did not install @hmkit/form" >&2; exit 1; }
[[ -n "${INSTALLED_VALIDATOR_DIR}" ]] || { echo "Validator pilot did not install registry @hmkit/validator" >&2; exit 1; }
VALIDATOR_VERSION="$(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
  "${INSTALLED_VALIDATOR_DIR}/oh-package.json5" | head -1)"
[[ "${VALIDATOR_VERSION}" =~ ^1\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] || {
  echo "Validator pilot resolved a validator version outside ^1.0.0." >&2
  exit 1
}

HAR_INDEX_SUM="$(tar -xOzf "${HAR_FILE}" package/Index.d.ets | shasum -a 256 | awk '{print $1}')"
INSTALLED_INDEX_SUM="$(shasum -a 256 "${INSTALLED_FORM_DIR}/Index.d.ets" | awk '{print $1}')"
HAR_ABC_SUM="$(tar -xOzf "${HAR_FILE}" package/ets/modules.abc | shasum -a 256 | awk '{print $1}')"
INSTALLED_ABC_SUM="$(shasum -a 256 "${INSTALLED_FORM_DIR}/ets/modules.abc" | awk '{print $1}')"
if [[ "${HAR_INDEX_SUM}" != "${INSTALLED_INDEX_SUM}" || "${HAR_ABC_SUM}" != "${INSTALLED_ABC_SUM}" ]]; then
  echo "Validator pilot install does not match the current form HAR." >&2
  exit 1
fi

"${VALIDATOR_DIR}/scripts/verify.sh"
bash "${HVIGORW}" assembleHap --mode module \
  -p product=default -p module=entry@default -p buildMode=release --no-daemon
[[ -s "${PILOT_HAP}" ]] || { echo "Validator pilot release HAP missing" >&2; exit 1; }

if [[ "${HMKIT_RUN_SIMULATOR:-0}" == "1" ]]; then
  "${VALIDATOR_DIR}/scripts/test-form-pilot.sh"
fi

echo "Independent validator real-form pilot verified against the current HAR and validator ${VALIDATOR_VERSION}."
