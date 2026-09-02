#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAP_FILE="${PROJECT_DIR}/showcase-app/entry/build/default/outputs/default/entry-default-unsigned.hap"
BUNDLE="com.hmkit.form.showcase"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hmkit-form-showcase.XXXXXX")"
LAYOUT_FILE="${TEMP_DIR}/layout.json"
REMOTE_LAYOUT="/data/local/tmp/hmkit-form-showcase.json"
trap 'rm -rf "${TEMP_DIR}"' EXIT

fail() { echo "Showcase simulator assertion failed: $1" >&2; exit 1; }
dump_layout() {
  hdc shell uitest dumpLayout -b "${BUNDLE}" -p "${REMOTE_LAYOUT}" >/dev/null
  hdc file recv "${REMOTE_LAYOUT}" "${LAYOUT_FILE}" >/dev/null
}
bounds_for_id() {
  jq -r --arg id "$1" '.. | objects | select(.attributes? and (.attributes.id // "") == $id) | .attributes.bounds' \
    "${LAYOUT_FILE}" | head -1
}
click_id() {
  local bounds
  bounds="$(bounds_for_id "$1")"
  [[ "${bounds}" =~ \[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\] ]] || fail "missing bounds for $1"
  hdc shell uitest uiInput click "$(( (BASH_REMATCH[1] + BASH_REMATCH[3]) / 2 ))" \
    "$(( (BASH_REMATCH[2] + BASH_REMATCH[4]) / 2 ))" >/dev/null
}
scroll_until_id() {
  for _attempt in 1 2 3 4 5 6 7 8; do
    local bounds
    dump_layout
    bounds="$(bounds_for_id "$1")"
    if [[ "${bounds}" =~ \[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\] ]] &&
      (( BASH_REMATCH[2] >= 120 && BASH_REMATCH[4] <= 2500 )); then
      return
    fi
    if [[ "$2" == "up" ]]; then
      hdc shell uitest uiInput swipe 660 450 660 1600 700 >/dev/null
    else
      hdc shell uitest uiInput swipe 660 1600 660 420 700 >/dev/null
    fi
  done
  fail "could not scroll to $1"
}

[[ -s "${HAP_FILE}" ]] || fail "release Showcase HAP missing"
[[ -n "$(hdc list targets | head -1)" ]] || fail "no HDC target connected"
hdc install -r "${HAP_FILE}" >/dev/null
hdc shell aa start -a EntryAbility -b "${BUNDLE}" >/dev/null
sleep 1
scroll_until_id 'showcase_title' up
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "showcase_title" and ((.attributes.text // "") | contains("Showcase")))' \
  "${LAYOUT_FILE}" >/dev/null || fail "title did not render"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "showcase_prefix_profile.name")' \
  "${LAYOUT_FILE}" >/dev/null || fail "prefix slot or inferred field did not render"

scroll_until_id 'hmkit_form_next' down
click_id 'hmkit_form_next'
sleep 1
hdc shell uitest uiInput keyEvent Back >/dev/null
scroll_until_id 'hmkit_form_error_summary' up
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_error_summary")' \
  "${LAYOUT_FILE}" >/dev/null || fail "error summary did not render after step validation"

scroll_until_id 'showcase_add_contact' down
click_id 'showcase_add_contact'
sleep 1
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "showcase_contact_1")' \
  "${LAYOUT_FILE}" >/dev/null || fail "FormArray append did not render"

scroll_until_id 'showcase_refill' down
click_id 'showcase_refill'
sleep 1
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "showcase_status" and .attributes.text == "已回填受控 values")' \
  "${LAYOUT_FILE}" >/dev/null || fail "controlled refill status did not update"

scroll_until_id 'showcase_theme' up
click_id 'showcase_theme'
sleep 1
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "showcase_theme" and .attributes.text == "浅色")' \
  "${LAYOUT_FILE}" >/dev/null || fail "theme switch did not update"

echo "Pura 90 full-feature Showcase runtime verification passed."
