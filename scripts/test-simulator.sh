#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAP_FILE="${PROJECT_DIR}/entry/build/default/outputs/default/entry-default-unsigned.hap"
BUNDLE="com.hmkit.formdemo"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hmkit-form-simulator.XXXXXX")"
LAYOUT_FILE="${TEMP_DIR}/layout.json"
REMOTE_LAYOUT="/data/local/tmp/hmkit-form-simulator.json"

cleanup() {
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

fail() {
  echo "Simulator assertion failed: $1" >&2
  exit 1
}

dump_layout() {
  hdc shell uitest dumpLayout -b "${BUNDLE}" -p "${REMOTE_LAYOUT}" >/dev/null
  hdc file recv "${REMOTE_LAYOUT}" "${LAYOUT_FILE}" >/dev/null
}

bounds_for_id() {
  local control_id="$1"
  jq -r --arg id "${control_id}" \
    '.. | objects | select(.attributes? and (.attributes.id // "") == $id) | .attributes.bounds' \
    "${LAYOUT_FILE}" | head -1
}

top_for_id() {
  local control_id="$1"
  local bounds
  bounds="$(bounds_for_id "${control_id}")"
  [[ "${bounds}" =~ \[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\] ]] || fail "missing bounds for ${control_id}"
  echo "${BASH_REMATCH[2]}"
}

click_id() {
  local control_id="$1"
  local bounds
  bounds="$(bounds_for_id "${control_id}")"
  [[ "${bounds}" =~ \[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\] ]] || fail "missing bounds for ${control_id}"
  local x=$(( (BASH_REMATCH[1] + BASH_REMATCH[3]) / 2 ))
  local y=$(( (BASH_REMATCH[2] + BASH_REMATCH[4]) / 2 ))
  hdc shell uitest uiInput click "${x}" "${y}" >/dev/null
}

input_text_id() {
  local control_id="$1"
  local value="$2"
  local bounds
  bounds="$(bounds_for_id "${control_id}")"
  [[ "${bounds}" =~ \[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\] ]] || fail "missing bounds for ${control_id}"
  local x=$(( (BASH_REMATCH[1] + BASH_REMATCH[3]) / 2 ))
  local y=$(( (BASH_REMATCH[2] + BASH_REMATCH[4]) / 2 ))
  hdc shell uitest uiInput inputText "${x}" "${y}" "${value}" >/dev/null
}

scroll_until_id() {
  local control_id="$1"
  local direction="$2"
  for _attempt in 1 2 3 4 5 6; do
    dump_layout
    if [[ -n "$(bounds_for_id "${control_id}")" ]]; then
      return
    fi
    if [[ "${direction}" == "2" ]]; then
      hdc shell uitest uiInput swipe 660 1500 660 400 1000 >/dev/null
    elif [[ "${direction}" == "3" ]]; then
      hdc shell uitest uiInput swipe 660 400 660 1500 1000 >/dev/null
    else
      hdc shell uitest uiInput dircFling "${direction}" 800 100 >/dev/null
    fi
  done
  fail "could not scroll to ${control_id}"
}

[[ -f "${HAP_FILE}" ]] || fail "release HAP missing; run ./scripts/build-release.sh"
[[ -n "$(hdc list targets | head -1)" ]] || fail "no HDC target connected"

hdc install -r "${HAP_FILE}" >/dev/null
hdc shell aa start -a EntryAbility -b "${BUNDLE}" >/dev/null
scroll_until_id 'hmkit_form_username' 3
dump_layout

jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_username")' \
  "${LAYOUT_FILE}" >/dev/null || fail "core scene did not render"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_slot_prefix_username" and .attributes.text == "@")' \
  "${LAYOUT_FILE}" >/dev/null || fail "prefix Builder slot did not render"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_slot_suffix_username" and .attributes.text == "必填")' \
  "${LAYOUT_FILE}" >/dev/null || fail "suffix Builder slot did not render"
[[ "$(top_for_id 'hmkit_form_username')" -ne "$(top_for_id 'hmkit_form_age')" ]] || \
  fail "narrow responsive layout did not keep fields in one column"

click_id 'hmkit_layout_toggle'
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_layout_status" and .attributes.text == "tablet 双列预览")' \
  "${LAYOUT_FILE}" >/dev/null || fail "responsive preview did not switch layout configuration"
[[ "$(top_for_id 'hmkit_form_username')" -eq "$(top_for_id 'hmkit_form_age')" ]] || \
  fail "wide responsive layout did not place two span-6 fields in one row"

click_id 'hmkit_theme_toggle'
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_username" and .attributes.backgroundColor == "#FF202124")' \
  "${LAYOUT_FILE}" >/dev/null || fail "dark theme did not reach the form control"

scroll_until_id 'hmkit_form_interests_0_row' 2
click_id 'hmkit_form_interests_0_row'
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_interests" and .attributes.checked == "true")' \
  "${LAYOUT_FILE}" >/dev/null || fail "checkbox row did not update the controlled string array"

scroll_until_id 'hmkit_slot_help_city' 3
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_slot_help_city" and ((.attributes.text // "") | startswith("提示：")))' \
  "${LAYOUT_FILE}" >/dev/null || fail "help Builder slot did not render"

scroll_until_id 'hmkit_form_serviceLevel_2' 2
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_slot_label_serviceLevel" and ((.attributes.text // "") | contains("服务等级")))' \
  "${LAYOUT_FILE}" >/dev/null || fail "label Builder slot did not render"
click_id 'hmkit_form_serviceLevel_2'
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_core_values" and ((.attributes.text // "") | contains("\"serviceLevel\":\"urgent\"")))' \
  "${LAYOUT_FILE}" >/dev/null || fail "custom renderer did not update the controlled model"

scroll_until_id 'hmkit_slot_submit' 2
click_id 'hmkit_slot_submit'
sleep 1
hdc shell uitest uiInput keyEvent Back >/dev/null
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_slot_error_username" and ((.attributes.text // "") | contains("请输入用户名")))' \
  "${LAYOUT_FILE}" >/dev/null || fail "custom submit did not preserve validation, focus, and error slot lifecycle"

scroll_until_id 'hmkit_scene_1' 3
click_id 'hmkit_scene_1'
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_priority" and .attributes.enabled == "false")' \
  "${LAYOUT_FILE}" >/dev/null || fail "conditional disabled state is incorrect"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_contact_0_row" and .attributes.clickable == "true")' \
  "${LAYOUT_FILE}" >/dev/null || fail "radio row is not a full click target"

click_id 'hmkit_form_contact_0_row'
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_contact" and .attributes.checked == "true")' \
  "${LAYOUT_FILE}" >/dev/null || fail "radio row click did not select the option"

click_id 'hmkit_scene_2'
sleep 1
scroll_until_id 'hmkit_options_city_retry' 2
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_options_city_error" and .attributes.text == "城市服务暂不可用")' \
  "${LAYOUT_FILE}" >/dev/null || fail "async option loader did not expose its failure"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_options_city_retry" and .attributes.text == "重试")' \
  "${LAYOUT_FILE}" >/dev/null || fail "async option retry action did not render"

click_id 'hmkit_options_city_retry'
sleep 1
scroll_until_id 'hmkit_form_city' 2
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_city" and .attributes.enabled == "true")' \
  "${LAYOUT_FILE}" >/dev/null || fail "async option retry did not restore the Select"
if jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_options_city_error")' \
  "${LAYOUT_FILE}" >/dev/null; then
  fail "async option error remained after a successful retry"
fi

scroll_until_id 'hmkit_form_account' 3
dump_layout
input_text_id 'hmkit_form_account' 'admin'
sleep 2
hdc shell uitest uiInput keyEvent Back >/dev/null
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_account" and .attributes.text == "admin" and .attributes.description == "错误：该账号已被占用")' \
  "${LAYOUT_FILE}" >/dev/null || fail "async error or accessibility description is incorrect"

scroll_until_id 'hmkit_form_submit' 2
click_id 'hmkit_form_submit'
sleep 2
hdc shell uitest uiInput keyEvent Back >/dev/null
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_async_submit_status" and .attributes.text == "提交失败：2 项错误")' \
  "${LAYOUT_FILE}" >/dev/null || fail "invalid submit event did not reach the host"

scroll_until_id 'hmkit_scene_3' 3
click_id 'hmkit_scene_3'
sleep 1
scroll_until_id 'hmkit_form_profile.name' 3
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_profile.name")' \
  "${LAYOUT_FILE}" >/dev/null || fail "nested path field did not render"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_nested_values" and ((.attributes.text // "") | contains("\"address\":{\"country\":\"CN\"}")))' \
  "${LAYOUT_FILE}" >/dev/null || fail "inferred defaults did not create nested values"

scroll_until_id 'hmkit_nested_refill' 2
click_id 'hmkit_nested_refill'
sleep 1
scroll_until_id 'hmkit_form_profile.name' 3
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_profile.name" and .attributes.text == "服务端嵌套用户")' \
  "${LAYOUT_FILE}" >/dev/null || fail "nested controlled refill did not reach the field"

scroll_until_id 'hmkit_scene_4' 3
click_id 'hmkit_scene_4'
sleep 1
scroll_until_id 'hmkit_array_contact-a_name' 3
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_array_contact-a_name" and .attributes.text == "张三")' \
  "${LAYOUT_FILE}" >/dev/null || fail "FormArray initial item did not render"

click_id 'hmkit_array_contact-a_down'
sleep 1
scroll_until_id 'hmkit_array_values' 2
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_array_values" and ((.attributes.text // "") | contains("[{\"id\":\"contact-b\"") and contains("\"id\":\"contact-a\"")))' \
  "${LAYOUT_FILE}" >/dev/null || fail "FormArray move did not reorder controlled values"

scroll_until_id 'hmkit_array_add' 3
click_id 'hmkit_array_add'
sleep 1
scroll_until_id 'hmkit_array_contact-3_name' 2
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_array_contact-3_name")' \
  "${LAYOUT_FILE}" >/dev/null || fail "FormArray append did not create an item"
scroll_until_id 'hmkit_array_contact-3_remove' 2
click_id 'hmkit_array_contact-3_remove'
sleep 1
dump_layout
if jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_array_contact-3_name")' \
  "${LAYOUT_FILE}" >/dev/null; then
  fail "FormArray remove kept the deleted item"
fi

scroll_until_id 'hmkit_array_refill' 3
click_id 'hmkit_array_refill'
sleep 1
scroll_until_id 'hmkit_array_contact-b_name' 2
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_array_contact-b_name" and .attributes.text == "李四（已回填）")' \
  "${LAYOUT_FILE}" >/dev/null || fail "FormArray controlled reorder/refill did not preserve business identity"

scroll_until_id 'hmkit_scene_5' 3
click_id 'hmkit_scene_5'
sleep 1
scroll_until_id 'hmkit_form_step_account' 3
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_step_account" and .attributes.text == "创建账号")' \
  "${LAYOUT_FILE}" >/dev/null || fail "structured form first step did not render"
# A keepAlive field may remain in the native tree while Visibility.None removes it from layout.

scroll_until_id 'hmkit_form_section_contact_toggle' 2
click_id 'hmkit_form_section_contact_toggle'
sleep 1
scroll_until_id 'hmkit_form_email' 2
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_email")' \
  "${LAYOUT_FILE}" >/dev/null || fail "collapsed section did not reveal its field"
EMAIL_HASH="$(jq -r '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_email") | .attributes.hashcode' \
  "${LAYOUT_FILE}" | head -1)"
[[ -n "${EMAIL_HASH}" ]] || fail "keepAlive field did not expose a native node identity"
scroll_until_id 'hmkit_form_section_contact_toggle' 3
click_id 'hmkit_form_section_contact_toggle'
sleep 1
scroll_until_id 'hmkit_form_section_contact_toggle' 3
click_id 'hmkit_form_section_contact_toggle'
sleep 1
scroll_until_id 'hmkit_form_email' 2
dump_layout
[[ "$(jq -r '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_email") | .attributes.hashcode' \
  "${LAYOUT_FILE}" | head -1)" == "${EMAIL_HASH}" ]] || fail "keepAlive did not retain the native field node"

scroll_until_id 'hmkit_form_next' 2
click_id 'hmkit_form_next'
sleep 1
hdc shell uitest uiInput keyEvent Back >/dev/null
scroll_until_id 'hmkit_form_step_account' 3
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_step_account")' \
  "${LAYOUT_FILE}" >/dev/null || fail "invalid current step advanced unexpectedly"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_accountName" and .attributes.description == "错误：请输入账号名称")' \
  "${LAYOUT_FILE}" >/dev/null || fail "current-step validation did not expose and focus the first error"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_error_summary_title" and .attributes.text == "请检查以下 2 项")' \
  "${LAYOUT_FILE}" >/dev/null || fail "structured validation did not render the ordered error summary"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_error_summary_email")' \
  "${LAYOUT_FILE}" >/dev/null || fail "collapsed-section error did not enter the summary"

click_id 'hmkit_form_error_summary_email'
sleep 1
scroll_until_id 'hmkit_form_email' 2
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_email" and .attributes.focused == "true" and .attributes.description == "错误：请输入联系邮箱")' \
  "${LAYOUT_FILE}" >/dev/null || fail "summary activation did not expand the section and focus its field"

input_text_id 'hmkit_form_accountName' 'hmkit-user'
sleep 1
hdc shell uitest uiInput keyEvent Back >/dev/null
scroll_until_id 'hmkit_form_email' 2
input_text_id 'hmkit_form_email' 'demo@hmkit.dev'
sleep 1
hdc shell uitest uiInput keyEvent Back >/dev/null
scroll_until_id 'hmkit_form_next' 2
click_id 'hmkit_form_next'
sleep 1
scroll_until_id 'hmkit_form_step_company' 3
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_step_company" and .attributes.text == "企业认证")' \
  "${LAYOUT_FILE}" >/dev/null || fail "valid current step did not advance"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_previous")' \
  "${LAYOUT_FILE}" >/dev/null || fail "previous-step navigation did not render"

scroll_until_id 'hmkit_form_previous' 2
click_id 'hmkit_form_previous'
sleep 1
scroll_until_id 'hmkit_form_step_account' 3
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_accountName" and .attributes.text == "hmkit-user")' \
  "${LAYOUT_FILE}" >/dev/null || fail "previous-step navigation lost controlled field state"
scroll_until_id 'hmkit_form_next' 2
click_id 'hmkit_form_next'
sleep 1
scroll_until_id 'hmkit_form_step_company' 3

scroll_until_id 'hmkit_structure_invalidate_account' 2
click_id 'hmkit_structure_invalidate_account'
sleep 1
scroll_until_id 'hmkit_form_submit' 3
click_id 'hmkit_form_submit'
sleep 1
scroll_until_id 'hmkit_form_error_summary_company' 3
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_step_account")' \
  "${LAYOUT_FILE}" >/dev/null || fail "full submit did not return to the first-step error"
click_id 'hmkit_form_error_summary_company'
sleep 1
scroll_until_id 'hmkit_form_company' 2
dump_layout
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_step_company" and .attributes.text == "企业认证")' \
  "${LAYOUT_FILE}" >/dev/null || fail "summary activation did not navigate across steps"
jq -e '.. | objects | select(.attributes? and (.attributes.id // "") == "hmkit_form_company" and .attributes.focused == "true")' \
  "${LAYOUT_FILE}" >/dev/null || fail "cross-step summary activation did not focus the target field"

echo "Pura 90 form runtime verification passed."
