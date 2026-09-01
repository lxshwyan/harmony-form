#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/env.sh"

cd "${PROJECT_DIR}"
bash "${HVIGORW}" assembleHar --mode module \
  -p product=default -p module=form@default -p buildMode=release --no-daemon
bash "${HVIGORW}" assembleHap --mode module \
  -p product=default -p module=entry@default -p buildMode=release --no-daemon
