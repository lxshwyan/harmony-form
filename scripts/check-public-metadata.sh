#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGE_JSON="${PROJECT_DIR}/form/oh-package.json5"

cd "${PROJECT_DIR}"

grep -Eq '"name"[[:space:]]*:[[:space:]]*"@hmkit/form"' "${PACKAGE_JSON}"
grep -Eq '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?"' "${PACKAGE_JSON}"
grep -Fq '"homepage": "https://github.com/lxshwyan/harmony-form"' "${PACKAGE_JSON}"
grep -Fq '"repository": "https://github.com/lxshwyan/harmony-form.git"' "${PACKAGE_JSON}"
grep -Eq '"@hmkit/validator"[[:space:]]*:[[:space:]]*"\^1\.0\.0"' "${PACKAGE_JSON}"

grep -Fq 'ohpm install @hmkit/form' README.md
grep -Fq 'ohpm install @hmkit/form' form/README.md

for required_file in \
  CONTRIBUTING.md \
  CODE_OF_CONDUCT.md \
  SECURITY.md \
  .github/ISSUE_TEMPLATE/bug_report.yml \
  .github/ISSUE_TEMPLATE/feature_request.yml \
  .github/PULL_REQUEST_TEMPLATE.md; do
  [[ -s "${required_file}" ]] || {
    echo "Required public repository file is missing or empty: ${required_file}" >&2
    exit 1
  }
done

if grep -Fq '当前仓库处于 0.1.0 首发审核阶段' README.md \
  || grep -Fq '0.1.0 尚未发布' MIGRATION.md \
  || grep -Fq '发布动作待用户单独授权' RELEASE-DECISION.md \
  || grep -Fq '当前等待平台审核' RELEASE-DECISION.md RELEASE-CHECKLIST.md; then
  echo "Published-state documentation contains stale release-candidate wording." >&2
  exit 1
fi

if grep -Eq '"@hmkit/validator"[[:space:]]*:[[:space:]]*"file:' "${PACKAGE_JSON}"; then
  echo "The publishable package must not use a file: validator dependency." >&2
  exit 1
fi

sensitive_pattern='BEGIN (RSA |OPENSSH |EC |ENCRYPTED )?PRIVATE'" KEY"
signing_secret_pattern='keyPassword|storePassword|certpath|storeFile|/Users/[^/]+/\.ohos'

while IFS= read -r -d '' candidate_file; do
  [[ "${candidate_file}" == "scripts/check-public-metadata.sh" ]] && continue
  grep -Iq . "${candidate_file}" || continue

  if grep -Il -E "${sensitive_pattern}" "${candidate_file}" >/dev/null; then
    echo "Publishable file contains private-key material: ${candidate_file}" >&2
    exit 1
  fi

  if grep -Il -i -E "${signing_secret_pattern}" "${candidate_file}" >/dev/null; then
    echo "Publishable file contains local signing credentials or certificate paths: ${candidate_file}" >&2
    exit 1
  fi
done < <(git ls-files --cached --others --exclude-standard -z)

while IFS= read -r script_file; do
  bash -n "${script_file}"
done < <(find scripts -maxdepth 1 -type f -name '*.sh' -print | sort)

echo "Public repository metadata and static safety checks passed."
