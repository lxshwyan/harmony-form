#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SHOWCASE_DIR="${PROJECT_DIR}/showcase-app"
HAR_FILE="${PROJECT_DIR}/form/build/default/outputs/default/form.har"

source "${SCRIPT_DIR}/env.sh"

if [[ ! -f "${HAR_FILE}" ]]; then
  echo "Release HAR is missing; run ./scripts/build-release.sh first." >&2
  exit 1
fi

cd "${SHOWCASE_DIR}"
"${OHPM}" clean
"${OHPM}" install --all

INSTALLED_FORM_DIR="$(find "${SHOWCASE_DIR}/oh_modules/.ohpm" -type d -path '*/oh_modules/@hmkit/form' -print -quit)"
INSTALLED_VALIDATOR_DIR="$(find "${SHOWCASE_DIR}/oh_modules/.ohpm" -type d -path '*/oh_modules/@hmkit/validator' -print -quit)"
if [[ -z "${INSTALLED_FORM_DIR}" ]]; then
  echo "Showcase did not install @hmkit/form." >&2
  exit 1
fi
VALIDATOR_VERSION="$(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
  "${INSTALLED_VALIDATOR_DIR}/oh-package.json5" 2>/dev/null | head -1)"
if [[ -z "${INSTALLED_VALIDATOR_DIR}" || ! "${VALIDATOR_VERSION}" =~ ^1\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Showcase resolved a validator version outside ^1.0.0." >&2
  exit 1
fi

HAR_INDEX_SUM="$(tar -xOzf "${HAR_FILE}" package/Index.d.ets | shasum -a 256 | awk '{print $1}')"
INSTALLED_INDEX_SUM="$(shasum -a 256 "${INSTALLED_FORM_DIR}/Index.d.ets" | awk '{print $1}')"
HAR_ABC_SUM="$(tar -xOzf "${HAR_FILE}" package/ets/modules.abc | shasum -a 256 | awk '{print $1}')"
INSTALLED_ABC_SUM="$(shasum -a 256 "${INSTALLED_FORM_DIR}/ets/modules.abc" | awk '{print $1}')"
if [[ "${HAR_INDEX_SUM}" != "${INSTALLED_INDEX_SUM}" || "${HAR_ABC_SUM}" != "${INSTALLED_ABC_SUM}" ]]; then
  echo "Showcase @hmkit/form install does not match current release HAR." >&2
  exit 1
fi

bash "${HVIGORW}" clean --no-daemon
bash "${HVIGORW}" assembleHap --mode module \
  -p product=default -p module=entry@default -p buildMode=release --no-daemon

test -f "${SHOWCASE_DIR}/entry/build/default/outputs/default/entry-default-unsigned.hap"
echo "Full-feature API 12 Showcase verified against the current HAR and validator ${VALIDATOR_VERSION}."
