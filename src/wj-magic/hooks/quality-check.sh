#!/usr/bin/env bash
# wj-magic: Edit/Write 후 품질 체크 (PostToolUse)
# stdin: JSON { tool_name, tool_input: { file_path, ... } }
set -euo pipefail

# 공통 패턴 라이브러리 로드
_plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${_plugin_root}/lib/patterns.sh"

_input="$(cat || true)"
if [[ -z "${_input}" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

_file="$(printf '%s' "${_input}" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
if [[ -z "${_file}" || ! -f "${_file}" ]]; then
  exit 0
fi

_warn=()

case "${_file}" in
  *.ts|*.tsx|*.js|*.jsx)
    # === TS/JS 검사 ===
    _lines=$(wc -l < "${_file}" 2>/dev/null || echo 0)
    if [[ "${_lines}" -gt 300 ]]; then
      _warn+=("파일 ${_lines}줄: 300줄 초과 — SRP 기준 분할 필요 → REFACTORING_PREVENTION.md")
    fi
    if grep -En "$WJ_TS_ANY" "${_file}" >/dev/null 2>&1; then
      _warn+=("any 사용 감지 — unknown + 타입 가드 → HIGH_QUALITY_CODE_STANDARDS.md")
    fi
    if grep -En "$WJ_TS_NONNULL" "${_file}" >/dev/null 2>&1; then
      _warn+=("!. (non-null assertion) 감지 → NON_NULL_ELIMINATION.md")
    fi
    if command -v perl >/dev/null 2>&1; then
      if perl -0777 -ne 'exit 0 if /catch\s*(?:\([^)]*\))?\s*\{\s*\}/; exit 1' "${_file}" 2>/dev/null; then
        _warn+=("Silent catch 감지 — 최소한 로깅/복구 필요")
      fi
    fi
    if grep -n "$WJ_TS_ESLINT_ANY" "${_file}" >/dev/null 2>&1; then
      _warn+=("eslint-disable no-explicit-any — 린트 우회 금지, 타입을 정확히 지정")
    fi
    _as_count=$(grep -cE "$WJ_TS_AS_CAST" "${_file}" 2>/dev/null || true)
    _as_count="${_as_count:-0}"
    if [[ "${_as_count}" -gt 3 ]]; then
      _warn+=("as 캐스팅 ${_as_count}회 — 타입 가드/제네릭 사용 권장 → LIBRARY_TYPE_HARDENING.md")
    fi
    # 함수 길이 체크 (rough estimate, 20줄 초과)
    _LONG_FUNCS=""
    if command -v awk >/dev/null 2>&1; then
      _LONG_FUNCS=$(awk '
        /^[[:space:]]*(export[[:space:]]+)?(async[[:space:]]+)?function[[:space:]]+[A-Za-z_]/ ||
        /^[[:space:]]*(export[[:space:]]+)?(const|let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*(async[[:space:]]*)?\(/ {
          if (fname != "" && (NR - start) > 20) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
          fname = $0; sub(/^[[:space:]]+/, "", fname); sub(/[({].*/, "", fname)
          start = NR
        }
        END {
          if (fname != "" && (NR - start) > 20) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
        }
      ' "${_file}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_FUNCS}" ]]; then
      _FUNC_COUNT=$(echo "${_LONG_FUNCS}" | wc -l | tr -d ' ')
      _warn+=("20줄 초과 함수 ${_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        _warn+=("  ${_fl}")
      done <<< "$(echo "${_LONG_FUNCS}" | head -3)"
    fi
    ;;
  *.py)
    # === Python 검사 ===
    _lines=$(wc -l < "${_file}" 2>/dev/null || echo 0)
    if [[ "${_lines}" -gt 600 ]]; then
      _warn+=("파일 ${_lines}줄: 600줄 초과 (hard limit) → standards/python.md")
    elif [[ "${_lines}" -gt 400 ]]; then
      _warn+=("파일 ${_lines}줄: 400줄 초과 (soft limit) — 분할 검토 → standards/python.md")
    fi
    if grep -En "$WJ_PY_ANY" "${_file}" >/dev/null 2>&1; then
      _warn+=("Any 사용 감지 — object + isinstance 사용 → standards/python.md")
    fi
    if grep -En "$WJ_PY_BARE_EXCEPT" "${_file}" >/dev/null 2>&1; then
      _warn+=("bare except: 감지 — 구체 예외 타입 지정 필요")
    fi
    if grep -En 'except.*pass\s*$' "${_file}" >/dev/null 2>&1; then
      _warn+=("except + pass (silent catch) 감지 — 최소 로깅 필요")
    fi
    if grep -En "$WJ_PY_TYPE_IGNORE" "${_file}" >/dev/null 2>&1; then
      _warn+=("type: ignore (사유 없음) — 사유 주석 필수 (예: # type: ignore[arg-type])")
    fi
    # 함수 길이 체크 (rough estimate, 50줄 초과)
    _LONG_PY_FUNCS=""
    if command -v awk >/dev/null 2>&1; then
      _LONG_PY_FUNCS=$(awk '
        /^[[:space:]]*def [A-Za-z_]/ {
          if (fname != "" && (NR - start) > 50) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
          fname = $0; sub(/^[[:space:]]+/, "", fname); sub(/\(.*/, "", fname)
          start = NR
        }
        END {
          if (fname != "" && (NR - start) > 50) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
        }
      ' "${_file}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_PY_FUNCS}" ]]; then
      _PY_FUNC_COUNT=$(echo "${_LONG_PY_FUNCS}" | wc -l | tr -d ' ')
      _warn+=("50줄 초과 함수 ${_PY_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        _warn+=("  ${_fl}")
      done <<< "$(echo "${_LONG_PY_FUNCS}" | head -3)"
    fi
    ;;
  *.go)
    # === Go 검사 ===
    _lines=$(wc -l < "${_file}" 2>/dev/null || echo 0)
    if [[ "${_lines}" -gt 500 ]]; then
      _warn+=("파일 ${_lines}줄: 500줄 초과 → go/standards.md")
    fi
    if grep -En "$WJ_GO_IGNORED_ERR" "${_file}" >/dev/null 2>&1; then
      _warn+=("_ = err (에러 무시) 감지 — 에러 처리 필수 → go/standards.md")
    fi
    if grep -En "$WJ_GO_EMPTY_IFACE" "${_file}" >/dev/null 2>&1; then
      _warn+=("interface{} 감지 — 제네릭 또는 구체 타입 사용 → go/standards.md")
    fi
    # 함수 길이 체크 (rough estimate, 40줄 초과)
    _LONG_GO_FUNCS=""
    if command -v awk >/dev/null 2>&1; then
      _LONG_GO_FUNCS=$(awk '
        /^func / {
          if (fname != "" && (NR - start) > 40) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
          fname = $0; sub(/^[[:space:]]+/, "", fname); sub(/[({].*/, "", fname)
          start = NR
        }
        END {
          if (fname != "" && (NR - start) > 40) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
        }
      ' "${_file}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_GO_FUNCS}" ]]; then
      _GO_FUNC_COUNT=$(echo "${_LONG_GO_FUNCS}" | wc -l | tr -d ' ')
      _warn+=("40줄 초과 함수 ${_GO_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        _warn+=("  ${_fl}")
      done <<< "$(echo "${_LONG_GO_FUNCS}" | head -3)"
    fi
    ;;
  *.rs)
    # === Rust 검사 ===
    _lines=$(wc -l < "${_file}" 2>/dev/null || echo 0)
    if [[ "${_lines}" -gt 500 ]]; then
      _warn+=("파일 ${_lines}줄: 500줄 초과 → rust/standards.md")
    fi
    if grep -En "$WJ_RS_UNWRAP" "${_file}" >/dev/null 2>&1; then
      _warn+=("unwrap() 감지 — ? operator 또는 expect() 사용 → rust/standards.md")
    fi
    # 함수 길이 체크 (rough estimate, 40줄 초과)
    _LONG_RS_FUNCS=""
    if command -v awk >/dev/null 2>&1; then
      _LONG_RS_FUNCS=$(awk '
        /^[[:space:]]*(pub[[:space:]]+)?(async[[:space:]]+)?fn / {
          if (fname != "" && (NR - start) > 40) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
          fname = $0; sub(/^[[:space:]]+/, "", fname); sub(/[({].*/, "", fname)
          start = NR
        }
        END {
          if (fname != "" && (NR - start) > 40) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
        }
      ' "${_file}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_RS_FUNCS}" ]]; then
      _RS_FUNC_COUNT=$(echo "${_LONG_RS_FUNCS}" | wc -l | tr -d ' ')
      _warn+=("40줄 초과 함수 ${_RS_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        _warn+=("  ${_fl}")
      done <<< "$(echo "${_LONG_RS_FUNCS}" | head -3)"
    fi
    ;;
  *.swift)
    # === Swift 검사 ===
    _lines=$(wc -l < "${_file}" 2>/dev/null || echo 0)
    if [[ "${_lines}" -gt 400 ]]; then
      _warn+=("파일 ${_lines}줄: 400줄 초과 → swift/standards.md")
    fi
    if grep -En "$WJ_SW_TRY_FORCE" "${_file}" >/dev/null 2>&1; then
      _warn+=("try! 감지 — do-catch 사용 → swift/standards.md")
    fi
    # 함수 길이 체크 (rough estimate, 30줄 초과)
    _LONG_SWIFT_FUNCS=""
    if command -v awk >/dev/null 2>&1; then
      _LONG_SWIFT_FUNCS=$(awk '
        /^[[:space:]]*(public|private|internal|open)?[[:space:]]*(static|class)?[[:space:]]*func / {
          if (fname != "" && (NR - start) > 30) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
          fname = $0; sub(/^[[:space:]]+/, "", fname); sub(/[({].*/, "", fname)
          start = NR
        }
        END {
          if (fname != "" && (NR - start) > 30) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
        }
      ' "${_file}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_SWIFT_FUNCS}" ]]; then
      _SWIFT_FUNC_COUNT=$(echo "${_LONG_SWIFT_FUNCS}" | wc -l | tr -d ' ')
      _warn+=("30줄 초과 함수 ${_SWIFT_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        _warn+=("  ${_fl}")
      done <<< "$(echo "${_LONG_SWIFT_FUNCS}" | head -3)"
    fi
    ;;
  *.kt|*.kts)
    # === Kotlin 검사 ===
    _lines=$(wc -l < "${_file}" 2>/dev/null || echo 0)
    if [[ "${_lines}" -gt 400 ]]; then
      _warn+=("파일 ${_lines}줄: 400줄 초과 → kotlin/standards.md")
    fi
    if grep -En "$WJ_KT_BANGBANG" "${_file}" >/dev/null 2>&1; then
      _warn+=("!! (force unwrap) 감지 — ?./?:/let 사용 → kotlin/standards.md")
    fi
    if grep -En "$WJ_KT_GLOBALSCOPE" "${_file}" >/dev/null 2>&1; then
      _warn+=("GlobalScope 감지 — structured concurrency 사용 → kotlin/standards.md")
    fi
    # 함수 길이 체크 (rough estimate, 30줄 초과)
    _LONG_KT_FUNCS=""
    if command -v awk >/dev/null 2>&1; then
      _LONG_KT_FUNCS=$(awk '
        /^[[:space:]]*(public|private|internal|protected)?[[:space:]]*(suspend[[:space:]]+)?fun / {
          if (fname != "" && (NR - start) > 30) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
          fname = $0; sub(/^[[:space:]]+/, "", fname); sub(/[({].*/, "", fname)
          start = NR
        }
        END {
          if (fname != "" && (NR - start) > 30) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
        }
      ' "${_file}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_KT_FUNCS}" ]]; then
      _KT_FUNC_COUNT=$(echo "${_LONG_KT_FUNCS}" | wc -l | tr -d ' ')
      _warn+=("30줄 초과 함수 ${_KT_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        _warn+=("  ${_fl}")
      done <<< "$(echo "${_LONG_KT_FUNCS}" | head -3)"
    fi
    ;;
  *)
    # .dev/audit/ 내 마크다운 파일 시크릿 유출 2차 검증 (PostToolUse 안전망)
    case "${_file}" in
      */.dev/audit/*.md)
        _secret_regex='AKIA[A-Z0-9]{16}|AIzaSy[a-zA-Z0-9_-]{33}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|sk_live_[a-zA-Z0-9]{24,}|rk_live_[a-zA-Z0-9]{24,}|xox[bpas]-[a-zA-Z0-9-]+|eyJ[a-zA-Z0-9_-]{20,}\.eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]+'
        if grep -Eq "${_secret_regex}" "${_file}" 2>/dev/null; then
          echo "[woojoo-magic] ⛔ CRITICAL: audit 리포트에 실제 시크릿 값이 포함되어 있습니다!" >&2
          echo "  파일: ${_file}" >&2
          echo "  즉시 해당 값을 마스킹(앞 6자 + ***)하세요. 이 파일을 커밋하면 GitHub Secret Scanning이 키를 차단합니다." >&2
        fi
        ;;
    esac
    exit 0
    ;;
esac

if [[ ${#_warn[@]} -gt 0 ]]; then
  echo "[wj-magic] 품질 경고: ${_file}"
  for w in "${_warn[@]}"; do
    echo "  ⚠ ${w}"
  done
fi

exit 0
