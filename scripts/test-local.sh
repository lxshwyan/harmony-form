#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/env.sh"

cd "${PROJECT_DIR}"
RESULT_FILE="form/.test/default/intermediates/test/coverage_data/test_result.txt"
rm -f "${RESULT_FILE}"
bash "${HVIGORW}" test --mode module \
  -p product=default -p module=form@default --no-daemon

if [[ ! -f "${RESULT_FILE}" ]]; then
  echo "Hypium result not found: ${RESULT_FILE}" >&2
  exit 1
fi

SUMMARY="$(tail -n 1 "${RESULT_FILE}")"
echo "${SUMMARY}"
if [[ ! "${SUMMARY}" =~ ^Tests\ run:\ [1-9][0-9]*,\ Failure:\ 0,\ Error:\ 0,\ Pass:\ [1-9][0-9]*,\ Ignore:\ 0$ ]]; then
  echo "Hypium tests did not fully pass." >&2
  exit 1
fi
