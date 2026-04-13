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
