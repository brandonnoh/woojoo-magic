#!/usr/bin/env bash
# patterns.sh — 언어별 안티패턴 정규식 공통 라이브러리
# source로 가져와서 사용. 단독 실행 불가.
# gate-l1.sh, quality-check.sh에서 공유하는 정규식을 한 곳에서 관리.
# 주의: set -euo pipefail은 호출자가 설정. 여기서는 생략.

# === 줄 수 제한 ===
# shellcheck disable=SC2034
WJ_LIMIT_TS=300
# shellcheck disable=SC2034
WJ_LIMIT_PY=600
# shellcheck disable=SC2034
WJ_LIMIT_PY_SOFT=400
# shellcheck disable=SC2034
WJ_LIMIT_GO=500
# shellcheck disable=SC2034
WJ_LIMIT_RS=500
# shellcheck disable=SC2034
WJ_LIMIT_SWIFT=400
# shellcheck disable=SC2034
WJ_LIMIT_KT=400

# === TS/JS 패턴 ===
# shellcheck disable=SC2034
WJ_TS_ANY=':\s*any\b|<any>|\bas\s+any\b'
# shellcheck disable=SC2034
WJ_TS_NONNULL='[A-Za-z0-9_)\]]!\.'
# shellcheck disable=SC2034
WJ_TS_SILENT_CATCH='catch\s*\(\s*\w*\s*\)\s*\{\s*\}'
# shellcheck disable=SC2034
WJ_TS_ESLINT_ANY='eslint-disable.*no-explicit-any'
# shellcheck disable=SC2034
WJ_TS_AS_CAST='\bas\b\s+[A-Z]'

# === Python 패턴 ===
# shellcheck disable=SC2034
WJ_PY_ANY=':\s*Any\b|-> Any\b|List\[Any\]|Dict\[.*, Any\]'
# shellcheck disable=SC2034
WJ_PY_BARE_EXCEPT='^\s*except\s*:'
# shellcheck disable=SC2034
WJ_PY_SILENT_EXCEPT='except.*:\s*$'
# shellcheck disable=SC2034
WJ_PY_TYPE_IGNORE='#\s*type:\s*ignore\s*$'

# === Go 패턴 ===
# shellcheck disable=SC2034
WJ_GO_IGNORED_ERR='^\s*_\s*=\s*\w+\('
# shellcheck disable=SC2034
WJ_GO_EMPTY_IFACE='interface\{\}'

# === Rust 패턴 ===
# shellcheck disable=SC2034
WJ_RS_UNWRAP='\.unwrap\(\)'
# shellcheck disable=SC2034
WJ_RS_UNSAFE='^\s*unsafe\s'

# === Swift 패턴 ===
# shellcheck disable=SC2034
WJ_SW_FORCE_UNWRAP='[a-zA-Z0-9_)\]]!'
# shellcheck disable=SC2034
WJ_SW_TRY_FORCE='\btry!'

# === Kotlin 패턴 ===
# shellcheck disable=SC2034
WJ_KT_BANGBANG='!!'
# shellcheck disable=SC2034
WJ_KT_GLOBALSCOPE='GlobalScope'

# === 시크릿 패턴 (audit 리포트 내 실제 값 유출 방지) ===
# .dev/audit/*.md 파일에 이 패턴이 매칭되면 실제 시크릿이 포함된 것으로 간주
# shellcheck disable=SC2034
WJ_SECRET_AWS_KEY='AKIA[A-Z0-9]{16}'
# shellcheck disable=SC2034
WJ_SECRET_GCP_KEY='AIzaSy[a-zA-Z0-9_-]{33}'
# shellcheck disable=SC2034
WJ_SECRET_GITHUB_PAT='ghp_[a-zA-Z0-9]{36}'
# shellcheck disable=SC2034
WJ_SECRET_GITHUB_OAUTH='gho_[a-zA-Z0-9]{36}'
# shellcheck disable=SC2034
WJ_SECRET_GITHUB_APP='ghu_[a-zA-Z0-9]{36}|ghs_[a-zA-Z0-9]{36}'
# shellcheck disable=SC2034
WJ_SECRET_STRIPE_LIVE='sk_live_[a-zA-Z0-9]{24,}'
# shellcheck disable=SC2034
WJ_SECRET_STRIPE_RKEY='rk_live_[a-zA-Z0-9]{24,}'
# shellcheck disable=SC2034
WJ_SECRET_SLACK='xox[bpas]-[a-zA-Z0-9-]+'
# shellcheck disable=SC2034
WJ_SECRET_PRIVATE_KEY='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
# shellcheck disable=SC2034
WJ_SECRET_JWT='eyJ[a-zA-Z0-9_-]{20,}\.eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]+'
# shellcheck disable=SC2034
WJ_SECRET_GENERIC_HIGH='(password|secret|api_key|apikey|token|auth_token|access_key)\s*[=:]\s*["\x27][A-Za-z0-9+/=_-]{16,}["\x27]'

# 전체 시크릿 패턴 (파이프로 연결 — grep -E에서 사용)
# shellcheck disable=SC2034
WJ_SECRET_ALL="${WJ_SECRET_AWS_KEY}|${WJ_SECRET_GCP_KEY}|${WJ_SECRET_GITHUB_PAT}|${WJ_SECRET_GITHUB_OAUTH}|${WJ_SECRET_GITHUB_APP}|${WJ_SECRET_STRIPE_LIVE}|${WJ_SECRET_STRIPE_RKEY}|${WJ_SECRET_SLACK}|${WJ_SECRET_PRIVATE_KEY}|${WJ_SECRET_JWT}"
