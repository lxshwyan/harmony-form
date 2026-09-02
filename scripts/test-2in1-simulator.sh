#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAP_FILE="${PROJECT_DIR}/showcase-app/entry/build/default/outputs/default/entry-default-unsigned.hap"
BUNDLE="com.hmkit.form.showcase"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hmkit-form-2in1.XXXXXX")"
LAYOUT_FILE="${TEMP_DIR}/layout.json"
REMOTE_LAYOUT="/data/local/tmp/hmkit-form-2in1.json"
trap 'rm -rf "${TEMP_DIR}"' EXIT

fail() { echo "2in1 simulator assertion failed: $1" >&2; exit 1; }
dump_layout() {
  hdc shell uitest dumpLayout -b "${BUNDLE}" -p "${REMOTE_LAYOUT}" >/dev/null
  hdc file recv "${REMOTE_LAYOUT}" "${LAYOUT_FILE}" >/dev/null
}
bounds_for_id() {
  jq -r --arg id "$1" '.. | objects | select(.attributes? and (.attributes.id // "") == $id) | .attributes.bounds' \
    "${LAYOUT_FILE}" | head -1
}
top_for_id() {
  local bounds
  bounds="$(bounds_for_id "$1")"
  [[ "${bounds}" =~ \[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\] ]] || fail "missing bounds for $1"
  echo "${BASH_REMATCH[2]}"
}
click_id() {
  local bounds
  bounds="$(bounds_for_id "$1")"
  [[ "${bounds}" =~ \[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\] ]] || fail "missing bounds for $1"
  hdc shell uitest uiInput click "$(( (BASH_REMATCH[1] + BASH_REMATCH[3]) / 2 ))" \
    "$(( (BASH_REMATCH[2] + BASH_REMATCH[4]) / 2 ))" >/dev/null
}
is_focused_id() {
  jq -e --arg id "$1" \
    '.. | objects | select(.attributes? and (.attributes.id // "") == $id and ((.attributes.focused // "false") | tostring) == "true")' \
    "${LAYOUT_FILE}" >/dev/null
}
scroll_until_id() {
  for _attempt in 1 2 3 4 5 6 7 8; do
    dump_layout
    [[ -n "$(bounds_for_id "$1")" ]] && return
    hdc shell uitest uiInput swipe 1500 1700 1500 500 900 >/dev/null
  done
  fail "could not scroll to $1"
}

[[ -s "${HAP_FILE}" ]] || fail "release Showcase HAP missing"
command -v jq >/dev/null || fail "jq is unavailable"
[[ -n "$(hdc list targets | tr -d '\r' | head -1)" ]] || fail "no HDC target connected"

DEVICE_TYPE="$(hdc shell param get const.product.devicetype | tr -d '\r[:space:]')"
[[ "${DEVICE_TYPE}" == "2in1" ]] || fail "connected target is ${DEVICE_TYPE:-unknown}, expected 2in1"

hdc install -r "${HAP_FILE}" >/dev/null
hdc shell aa start -a EntryAbility -b "${BUNDLE}" >/dev/null
sleep 1
scroll_until_id 'hmkit_form_profile.name'
dump_layout

jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "showcase_title")' \
  "${LAYOUT_FILE}" >/dev/null || fail "Showcase title did not render"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "showcase_prefix_profile.name")' \
  "${LAYOUT_FILE}" >/dev/null || fail "Builder prefix did not render"
[[ "$(top_for_id 'hmkit_form_profile.name')" -eq "$(top_for_id 'hmkit_form_profile.age')" ]] || \
  fail "wide 2in1 window did not place span-6 fields in one row"

click_id 'showcase_2in1_compact'
sleep 1
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "showcase_2in1_layout_status" and .attributes.text == "窄窗单列预览")' \
  "${LAYOUT_FILE}" >/dev/null || fail "compact window preview status did not update"
[[ "$(top_for_id 'hmkit_form_profile.name')" -ne "$(top_for_id 'hmkit_form_profile.age')" ]] || \
  fail "compact 2in1 preview did not return span-6 fields to one column"

click_id 'showcase_2in1_compact'
sleep 1
dump_layout
[[ "$(top_for_id 'hmkit_form_profile.name')" -eq "$(top_for_id 'hmkit_form_profile.age')" ]] || \
  fail "restored 2in1 width did not recover the two-column layout"

click_id 'hmkit_form_profile.name'
sleep 1
dump_layout
is_focused_id 'hmkit_form_profile.name' || fail "coordinate click did not focus the name field"
hdc shell uitest uiInput keyEvent 2049 >/dev/null
sleep 1
dump_layout
is_focused_id 'hmkit_form_profile.age' || fail "Tab did not move focus to the age field"

echo "MateBook Pro 2in1 responsive and keyboard verification passed."
