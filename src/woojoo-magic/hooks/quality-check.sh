#!/usr/bin/env bash
# woojoo-magic: Edit/Write 후 품질 체크 (PostToolUse)
# stdin: JSON { tool_name, tool_input: { file_path, ... } }
set -euo pipefail

INPUT="$(cat || true)"
if [[ -z "${INPUT}" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

FILE="$(printf '%s' "${INPUT}" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
if [[ -z "${FILE}" || ! -f "${FILE}" ]]; then
  exit 0
fi

WARN=()

case "${FILE}" in
  *.ts|*.tsx|*.js|*.jsx)
    # === TS/JS 검사 ===
    LINES=$(wc -l < "${FILE}" 2>/dev/null || echo 0)
    if [[ "${LINES}" -gt 300 ]]; then
      WARN+=("파일 ${LINES}줄: 300줄 초과 — SRP 기준 분할 필요 → REFACTORING_PREVENTION.md")
    fi
    if grep -En ': any\b|<any>|as any\b' "${FILE}" >/dev/null 2>&1; then
      WARN+=("any 사용 감지 — unknown + 타입 가드 → HIGH_QUALITY_CODE_STANDARDS.md")
    fi
    if grep -En '[A-Za-z0-9_)\]]!\.' "${FILE}" >/dev/null 2>&1; then
      WARN+=("!. (non-null assertion) 감지 → NON_NULL_ELIMINATION.md")
    fi
    if command -v perl >/dev/null 2>&1; then
      if perl -0777 -ne 'exit 0 if /catch\s*(?:\([^)]*\))?\s*\{\s*\}/; exit 1' "${FILE}" 2>/dev/null; then
        WARN+=("Silent catch 감지 — 최소한 로깅/복구 필요")
      fi
    fi
    if grep -n 'eslint-disable.*no-explicit-any' "${FILE}" >/dev/null 2>&1; then
      WARN+=("eslint-disable no-explicit-any — 린트 우회 금지, 타입을 정확히 지정")
    fi
    AS_COUNT=$(grep -cE '\bas\b\s+[A-Z]' "${FILE}" 2>/dev/null || echo 0)
    if [[ "${AS_COUNT}" -gt 3 ]]; then
      WARN+=("as 캐스팅 ${AS_COUNT}회 — 타입 가드/제네릭 사용 권장 → LIBRARY_TYPE_HARDENING.md")
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
      ' "${FILE}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_FUNCS}" ]]; then
      _FUNC_COUNT=$(echo "${_LONG_FUNCS}" | wc -l | tr -d ' ')
      WARN+=("20줄 초과 함수 ${_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        WARN+=("  ${_fl}")
      done <<< "$(echo "${_LONG_FUNCS}" | head -3)"
    fi
    ;;
  *.py)
    # === Python 검사 ===
    LINES=$(wc -l < "${FILE}" 2>/dev/null || echo 0)
    if [[ "${LINES}" -gt 600 ]]; then
      WARN+=("파일 ${LINES}줄: 600줄 초과 (hard limit) → standards/python.md")
    elif [[ "${LINES}" -gt 400 ]]; then
      WARN+=("파일 ${LINES}줄: 400줄 초과 (soft limit) — 분할 검토 → standards/python.md")
    fi
    if grep -En ':\s*Any\b|-> Any\b' "${FILE}" >/dev/null 2>&1; then
      WARN+=("Any 사용 감지 — object + isinstance 사용 → standards/python.md")
    fi
    if grep -En '^\s*except\s*:' "${FILE}" >/dev/null 2>&1; then
      WARN+=("bare except: 감지 — 구체 예외 타입 지정 필요")
    fi
    if grep -En 'except.*pass\s*$' "${FILE}" >/dev/null 2>&1; then
      WARN+=("except + pass (silent catch) 감지 — 최소 로깅 필요")
    fi
    if grep -En '#\s*type:\s*ignore\s*$' "${FILE}" >/dev/null 2>&1; then
      WARN+=("type: ignore (사유 없음) — 사유 주석 필수 (예: # type: ignore[arg-type])")
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
      ' "${FILE}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_PY_FUNCS}" ]]; then
      _PY_FUNC_COUNT=$(echo "${_LONG_PY_FUNCS}" | wc -l | tr -d ' ')
      WARN+=("50줄 초과 함수 ${_PY_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        WARN+=("  ${_fl}")
      done <<< "$(echo "${_LONG_PY_FUNCS}" | head -3)"
    fi
    ;;
  *.go)
    # === Go 검사 ===
    LINES=$(wc -l < "${FILE}" 2>/dev/null || echo 0)
    if [[ "${LINES}" -gt 500 ]]; then
      WARN+=("파일 ${LINES}줄: 500줄 초과 → go/standards.md")
    fi
    if grep -En '^\s*_\s*=\s*\w+\(' "${FILE}" >/dev/null 2>&1; then
      WARN+=("_ = err (에러 무시) 감지 — 에러 처리 필수 → go/standards.md")
    fi
    if grep -En 'interface\{\}' "${FILE}" >/dev/null 2>&1; then
      WARN+=("interface{} 감지 — 제네릭 또는 구체 타입 사용 → go/standards.md")
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
      ' "${FILE}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_GO_FUNCS}" ]]; then
      _GO_FUNC_COUNT=$(echo "${_LONG_GO_FUNCS}" | wc -l | tr -d ' ')
      WARN+=("40줄 초과 함수 ${_GO_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        WARN+=("  ${_fl}")
      done <<< "$(echo "${_LONG_GO_FUNCS}" | head -3)"
    fi
    ;;
  *.rs)
    # === Rust 검사 ===
    LINES=$(wc -l < "${FILE}" 2>/dev/null || echo 0)
    if [[ "${LINES}" -gt 500 ]]; then
      WARN+=("파일 ${LINES}줄: 500줄 초과 → rust/standards.md")
    fi
    if grep -En '\.unwrap\(\)' "${FILE}" >/dev/null 2>&1; then
      WARN+=("unwrap() 감지 — ? operator 또는 expect() 사용 → rust/standards.md")
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
      ' "${FILE}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_RS_FUNCS}" ]]; then
      _RS_FUNC_COUNT=$(echo "${_LONG_RS_FUNCS}" | wc -l | tr -d ' ')
      WARN+=("40줄 초과 함수 ${_RS_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        WARN+=("  ${_fl}")
      done <<< "$(echo "${_LONG_RS_FUNCS}" | head -3)"
    fi
    ;;
  *.swift)
    # === Swift 검사 ===
    LINES=$(wc -l < "${FILE}" 2>/dev/null || echo 0)
    if [[ "${LINES}" -gt 400 ]]; then
      WARN+=("파일 ${LINES}줄: 400줄 초과 → swift/standards.md")
    fi
    if grep -En '\btry!' "${FILE}" >/dev/null 2>&1; then
      WARN+=("try! 감지 — do-catch 사용 → swift/standards.md")
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
      ' "${FILE}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_SWIFT_FUNCS}" ]]; then
      _SWIFT_FUNC_COUNT=$(echo "${_LONG_SWIFT_FUNCS}" | wc -l | tr -d ' ')
      WARN+=("30줄 초과 함수 ${_SWIFT_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        WARN+=("  ${_fl}")
      done <<< "$(echo "${_LONG_SWIFT_FUNCS}" | head -3)"
    fi
    ;;
  *.kt|*.kts)
    # === Kotlin 검사 ===
    LINES=$(wc -l < "${FILE}" 2>/dev/null || echo 0)
    if [[ "${LINES}" -gt 400 ]]; then
      WARN+=("파일 ${LINES}줄: 400줄 초과 → kotlin/standards.md")
    fi
    if grep -En '!!' "${FILE}" >/dev/null 2>&1; then
      WARN+=("!! (force unwrap) 감지 — ?./?:/let 사용 → kotlin/standards.md")
    fi
    if grep -En 'GlobalScope' "${FILE}" >/dev/null 2>&1; then
      WARN+=("GlobalScope 감지 — structured concurrency 사용 → kotlin/standards.md")
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
      ' "${FILE}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_KT_FUNCS}" ]]; then
      _KT_FUNC_COUNT=$(echo "${_LONG_KT_FUNCS}" | wc -l | tr -d ' ')
      WARN+=("30줄 초과 함수 ${_KT_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        WARN+=("  ${_fl}")
      done <<< "$(echo "${_LONG_KT_FUNCS}" | head -3)"
    fi
    ;;
  *)
    exit 0
    ;;
esac

if [[ ${#WARN[@]} -gt 0 ]]; then
  echo "[woojoo-magic] 품질 경고: ${FILE}"
  for w in "${WARN[@]}"; do
    echo "  ⚠ ${w}"
  done
fi

exit 0
