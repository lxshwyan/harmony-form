#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${PROJECT_DIR}/external-consumer"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hmkit-form-registry-consumer.XXXXXX")"
CONSUMER_DIR="${TEMP_DIR}/consumer"
BUNDLE="com.hmkit.form.externalconsumer"
LAYOUT_FILE="${TEMP_DIR}/layout.json"
REMOTE_LAYOUT="/data/local/tmp/hmkit-form-registry-consumer.json"

source "${SCRIPT_DIR}/env.sh"

cleanup() {
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

fail() {
  echo "Registry consumer verification failed: $1" >&2
  exit 1
}

rsync -a \
  --exclude build \
  --exclude oh_modules \
  --exclude .hvigor \
  --exclude .test \
  "${SOURCE_DIR}/" "${CONSUMER_DIR}/"

perl -0pi -e 's{"\@hmkit/form"\s*:\s*"file:[^"]+"}{"\@hmkit/form": "0.1.0"}' \
  "${CONSUMER_DIR}/entry/oh-package.json5"

grep -Eq '"@hmkit/form"[[:space:]]*:[[:space:]]*"0\.1\.0"' \
  "${CONSUMER_DIR}/entry/oh-package.json5" || fail "registry dependency was not configured"
if grep -Rq '"@hmkit/form"[[:space:]]*:[[:space:]]*"file:' "${CONSUMER_DIR}"; then
  fail "temporary consumer still contains a file: form dependency"
fi

cd "${CONSUMER_DIR}"
"${OHPM}" clean
"${OHPM}" install --all

INSTALLED_FORM_DIR="$(find "${CONSUMER_DIR}/oh_modules/.ohpm" -type d -path '*/oh_modules/@hmkit/form' -print -quit)"
INSTALLED_VALIDATOR_DIR="$(find "${CONSUMER_DIR}/oh_modules/.ohpm" -type d -path '*/oh_modules/@hmkit/validator' -print -quit)"
[[ -n "${INSTALLED_FORM_DIR}" ]] || fail "@hmkit/form was not installed"
[[ -n "${INSTALLED_VALIDATOR_DIR}" ]] || fail "@hmkit/validator was not installed"

grep -Eq '"version"[[:space:]]*:[[:space:]]*"0\.1\.0"' \
  "${INSTALLED_FORM_DIR}/oh-package.json5" || fail "installed form version is not 0.1.0"
grep -Fq '"repository":"https://github.com/lxshwyan/harmony-form.git"' \
  "${INSTALLED_FORM_DIR}/oh-package.json5" || fail "installed form repository metadata is incorrect"
grep -Eq '"version"[[:space:]]*:[[:space:]]*"1\.0\.0"' \
  "${INSTALLED_VALIDATOR_DIR}/oh-package.json5" || fail "validator 1.0.0 was not resolved"

if find "${INSTALLED_FORM_DIR}" -type f -name '*.ets' ! -name '*.d.ets' -print -quit | grep -q .; then
  fail "registry package contains ArkTS implementation source"
fi

bash "${HVIGORW}" clean --no-daemon
bash "${HVIGORW}" assembleHap --mode module \
  -p product=default -p module=entry@default -p buildMode=release --no-daemon

HAP_FILE="${CONSUMER_DIR}/entry/build/default/outputs/default/entry-default-unsigned.hap"
[[ -s "${HAP_FILE}" ]] || fail "release HAP was not produced"

if [[ "${HMKIT_RUN_SIMULATOR:-0}" == "1" ]]; then
  command -v hdc >/dev/null || fail "hdc is unavailable"
  command -v jq >/dev/null || fail "jq is unavailable"
  [[ -n "$(hdc list targets | head -1)" ]] || fail "no HDC target is connected"

  hdc install -r "${HAP_FILE}" >/dev/null
  hdc shell aa start -a EntryAbility -b "${BUNDLE}" >/dev/null
  sleep 1

  dump_layout() {
    hdc shell uitest dumpLayout -b "${BUNDLE}" -p "${REMOTE_LAYOUT}" >/dev/null
    hdc file recv "${REMOTE_LAYOUT}" "${LAYOUT_FILE}" >/dev/null
  }
  bounds_for_id() {
    jq -r --arg id "$1" \
      '.. | objects | select(.attributes? and (.attributes.id // "") == $id) | .attributes.bounds' \
      "${LAYOUT_FILE}" | head -1
  }
  click_id() {
    local bounds
    bounds="$(bounds_for_id "$1")"
    [[ "${bounds}" =~ \[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\] ]] || fail "bounds are unavailable for $1"
    hdc shell uitest uiInput click "$(( (BASH_REMATCH[1] + BASH_REMATCH[3]) / 2 ))" \
      "$(( (BASH_REMATCH[2] + BASH_REMATCH[4]) / 2 ))" >/dev/null
  }
  input_text_id() {
    local bounds
    bounds="$(bounds_for_id "$1")"
    [[ "${bounds}" =~ \[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\] ]] || fail "bounds are unavailable for $1"
    hdc shell uitest uiInput inputText "$(( (BASH_REMATCH[1] + BASH_REMATCH[3]) / 2 ))" \
      "$(( (BASH_REMATCH[2] + BASH_REMATCH[4]) / 2 ))" "$2" >/dev/null
  }

  dump_layout

  jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_profile.name")' \
    "${LAYOUT_FILE}" >/dev/null || fail "registry form field did not render"
  jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "consumer_slot_prefix_profile.name")' \
    "${LAYOUT_FILE}" >/dev/null || fail "registry Builder slot did not render"
  jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "consumer_array_0")' \
    "${LAYOUT_FILE}" >/dev/null || fail "registry FormArray did not render"

  click_id 'hmkit_form_next'
  sleep 1
  dump_layout

  jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "consumer_error_summary")' \
    "${LAYOUT_FILE}" >/dev/null || fail "invalid step did not render the error summary"

  input_text_id 'hmkit_form_profile.name' 'RegistryUser'
  hdc shell uitest uiInput keyEvent Back >/dev/null
  sleep 1
  dump_layout
  click_id 'hmkit_form_roles_0_row'
  click_id 'hmkit_form_next'
  sleep 1
  dump_layout

  jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_step_service")' \
    "${LAYOUT_FILE}" >/dev/null || fail "valid first step did not navigate to the service step"
  click_id 'hmkit_form_level'
  dump_layout
  click_id 'consumer_slot_submit'
  sleep 1
  dump_layout
  jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "consumer_submit_status" and ((.attributes.text // "") | startswith("submitted:RegistryUser")))' \
    "${LAYOUT_FILE}" >/dev/null || fail "valid registry submit did not notify the host"
fi

echo "Registry @hmkit/form@0.1.0 consumer verified with @hmkit/validator@1.0.0."
