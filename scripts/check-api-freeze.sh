#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HAR_FILE="${PROJECT_DIR}/form/build/default/outputs/default/form.har"
BASELINE="${PROJECT_DIR}/api/0.1.0-declarations.sha256"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hmkit-form-api-freeze.XXXXXX")"
ACTUAL="${TEMP_DIR}/actual.sha256"
trap 'rm -rf "${TEMP_DIR}"' EXIT

[[ -s "${HAR_FILE}" ]] || { echo "API freeze check: release HAR missing" >&2; exit 1; }
[[ -s "${BASELINE}" ]] || { echo "API freeze check: baseline missing" >&2; exit 1; }

tar -xzf "${HAR_FILE}" -C "${TEMP_DIR}"
while IFS= read -r file; do
  relative="${file#${TEMP_DIR}/package/}"
  normalized="${TEMP_DIR}/normalized.txt"
  perl -0777 -pe 's{/\*\*.*?\*/}{}gs; s{^//.*\n}{}mg; s{^\s*private[^\n]*\n}{}mg;
    s{\b[a-z][a-z0-9]*[0-9]+\b}{arg}g; s{[ \t]+}{ }g; s{^\s+|\s+$}{}mg; s{\n+}{\n}g' \
    "${file}" > "${normalized}"
  hash="$(shasum -a 256 "${normalized}" | awk '{print $1}')"
  printf '%s  %s\n' "${hash}" "${relative}" >> "${ACTUAL}"
done < <(find "${TEMP_DIR}/package" -type f -name '*.d.ets' -print | sort)

if ! diff -u "${BASELINE}" "${ACTUAL}"; then
  echo "Public declaration freeze changed. Review compatibility and update the baseline deliberately." >&2
  exit 1
fi

echo "0.1.0 public declaration freeze passed ($(wc -l < "${ACTUAL}" | tr -d ' ') files)."
