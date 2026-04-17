#!/usr/bin/env bash
# gate-l1.sh — L1 정적 감사 (grep only, <1초)
# 인자: 파일 목록 (stdin, 한 줄에 하나) 또는 $1로 단일 파일
# 출력: 실패 시 위반 내역을 stdout에 출력하고 exit 1
# 성공 시 exit 0
set -euo pipefail

# 공통 패턴 라이브러리 로드
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patterns.sh"

_files=""
if [[ $# -gt 0 && -f "$1" ]]; then
  _files="$1"
else
  _files="$(cat || true)"
fi

[[ -n "$_files" ]] || exit 0

_total_fail=0
_total_messages=""

# TS/JS 파일만 필터
_ts_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx) ;;
    *) continue ;;
  esac
  # 제외: .d.ts, __tests__, *.test.*, *.spec.*, node_modules, dist
  case "$f" in
    *.d.ts|*__tests__*|*.test.*|*.spec.*|*node_modules*|*dist/*) continue ;;
  esac
  [[ -f "$f" ]] || continue
  _ts_files="${_ts_files}${f}"$'\n'
done <<< "$_files"

_ts_files="$(echo "$_ts_files" | sed '/^$/d')"
if [[ -n "$_ts_files" ]]; then

_fail=0
_messages=""

# 1) 300줄 초과
while IFS= read -r f; do
  _lines=$(wc -l < "$f" | tr -d ' ')
  if (( _lines > 300 )); then
    _messages="${_messages}  300줄 초과: ${f} (${_lines}줄)"$'\n'
    _fail=1
  fi
done <<< "$_ts_files"

# 2) any 금지
_any_hits=$(xargs -d '\n' grep -HnE "$WJ_TS_ANY" 2>/dev/null <<< "$_ts_files" | grep -v '// @ts-' || true)
if [[ -n "$_any_hits" ]]; then
  _messages="${_messages}  any 타입 감지:"$'\n'
  _messages="${_messages}$(echo "$_any_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

# 3) non-null assertion
_nn_hits=$(xargs -d '\n' grep -HnE "$WJ_TS_NONNULL" 2>/dev/null <<< "$_ts_files" || true)
if [[ -n "$_nn_hits" ]]; then
  _messages="${_messages}  non-null assertion(!.) 감지:"$'\n'
  _messages="${_messages}$(echo "$_nn_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

# 4) silent catch
_sc_hits=$(xargs -d '\n' grep -HnE "$WJ_TS_SILENT_CATCH" 2>/dev/null <<< "$_ts_files" || true)
if [[ -n "$_sc_hits" ]]; then
  _messages="${_messages}  silent catch {} 감지:"$'\n'
  _messages="${_messages}$(echo "$_sc_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

# 5) eslint-disable no-explicit-any
_ed_hits=$(xargs -d '\n' grep -Hn "$WJ_TS_ESLINT_ANY" 2>/dev/null <<< "$_ts_files" || true)
if [[ -n "$_ed_hits" ]]; then
  _messages="${_messages}  eslint-disable no-explicit-any 감지:"$'\n'
  _messages="${_messages}$(echo "$_ed_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

if (( _fail == 1 )); then
  _total_messages="${_total_messages}[L1] TS/JS 정적 감사 실패:"$'\n'"${_messages}"$'\n'
  _total_fail=1
fi

fi  # end TS block

# === Python 검사 ===
_py_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.py) ;;
    *) continue ;;
  esac
  case "$f" in
    *__pycache__*|*.pyc|*node_modules*|*dist/*|*venv/*|*.venv/*) continue ;;
  esac
  [[ -f "$f" ]] || continue
  _py_files="${_py_files}${f}"$'\n'
done <<< "$_files"

_py_files="$(echo "$_py_files" | sed '/^$/d')"

if [[ -n "$_py_files" ]]; then
  _py_fail=0
  _py_messages=""

  # 1) 600줄 초과 (hard limit)
  while IFS= read -r f; do
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 600 )); then
      _py_messages="${_py_messages}  600줄 초과: ${f} (${_lines}줄)"$'\n'
      _py_fail=1
    fi
  done <<< "$_py_files"

  # 2) Any 사용 금지
  _any_py=$(xargs -d '\n' grep -HnE "$WJ_PY_ANY" 2>/dev/null <<< "$_py_files" | grep -v '# type:' || true)
  if [[ -n "$_any_py" ]]; then
    _py_messages="${_py_messages}  Any 타입 감지:"$'\n'
    _py_messages="${_py_messages}$(echo "$_any_py" | head -5 | sed 's/^/    /')"$'\n'
    _py_fail=1
  fi

  # 3) bare except / silent except
  _bare=$(xargs -d '\n' grep -HnE "$WJ_PY_BARE_EXCEPT" 2>/dev/null <<< "$_py_files" || true)
  _silent=$(xargs -d '\n' grep -HnE "$WJ_PY_SILENT_EXCEPT" 2>/dev/null <<< "$_py_files" || true)
  _pass_after=""
  if [[ -n "$_silent" ]]; then
    _pass_after=$(xargs -d '\n' grep -HnE 'except.*:' -A1 2>/dev/null <<< "$_py_files" | grep -E '^\s+pass\s*$' || true)
  fi
  if [[ -n "$_bare" ]]; then
    _py_messages="${_py_messages}  bare except: 감지:"$'\n'
    _py_messages="${_py_messages}$(echo "$_bare" | head -5 | sed 's/^/    /')"$'\n'
    _py_fail=1
  fi
  if [[ -n "$_pass_after" ]]; then
    _py_messages="${_py_messages}  except + pass (silent catch) 감지"$'\n'
    _py_fail=1
  fi

  # 4) type: ignore (사유 없는)
  _ignore=$(xargs -d '\n' grep -HnE "$WJ_PY_TYPE_IGNORE" 2>/dev/null <<< "$_py_files" || true)
  if [[ -n "$_ignore" ]]; then
    _py_messages="${_py_messages}  type: ignore (사유 없음) 감지:"$'\n'
    _py_messages="${_py_messages}$(echo "$_ignore" | head -5 | sed 's/^/    /')"$'\n'
    _py_fail=1
  fi

  if (( _py_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Python 정적 감사 실패:"$'\n'"${_py_messages}"$'\n'
    _total_fail=1
  fi
fi

# === Go 검사 ===
_go_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in *.go) ;; *) continue ;; esac
  case "$f" in *vendor/*|*_test.go) continue ;; esac
  [[ -f "$f" ]] || continue
  _go_files="${_go_files}${f}"$'\n'
done <<< "$_files"
_go_files="$(echo "$_go_files" | sed '/^$/d')"

if [[ -n "$_go_files" ]]; then
  _go_fail=0
  _go_messages=""
  while IFS= read -r f; do
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 500 )); then
      _go_messages="${_go_messages}  500줄 초과: ${f} (${_lines}줄)"$'\n'
      _go_fail=1
    fi
  done <<< "$_go_files"
  _ignored_err=$(xargs -d '\n' grep -HnE "$WJ_GO_IGNORED_ERR" 2>/dev/null <<< "$_go_files" || true)
  if [[ -n "$_ignored_err" ]]; then
    _go_messages="${_go_messages}  _ = err (에러 무시) 감지:"$'\n'
    _go_messages="${_go_messages}$(echo "$_ignored_err" | head -5 | sed 's/^/    /')"$'\n'
    _go_fail=1
  fi
  _iface=$(xargs -d '\n' grep -HnE "$WJ_GO_EMPTY_IFACE" 2>/dev/null <<< "$_go_files" || true)
  if [[ -n "$_iface" ]]; then
    _go_messages="${_go_messages}  interface{} 감지 — 제네릭 또는 구체 타입 사용:"$'\n'
    _go_messages="${_go_messages}$(echo "$_iface" | head -5 | sed 's/^/    /')"$'\n'
    _go_fail=1
  fi
  if (( _go_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Go 정적 감사 실패:"$'\n'"${_go_messages}"$'\n'
    _total_fail=1
  fi
fi

# === Rust 검사 ===
_rs_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in *.rs) ;; *) continue ;; esac
  case "$f" in *target/*) continue ;; esac
  [[ -f "$f" ]] || continue
  _rs_files="${_rs_files}${f}"$'\n'
done <<< "$_files"
_rs_files="$(echo "$_rs_files" | sed '/^$/d')"

if [[ -n "$_rs_files" ]]; then
  _rs_fail=0
  _rs_messages=""
  while IFS= read -r f; do
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 500 )); then
      _rs_messages="${_rs_messages}  500줄 초과: ${f} (${_lines}줄)"$'\n'
      _rs_fail=1
    fi
  done <<< "$_rs_files"
  _unwrap=$(xargs -d '\n' grep -HnE "$WJ_RS_UNWRAP" 2>/dev/null <<< "$_rs_files" | grep -v '#\[cfg(test)\]' | grep -v '#\[test\]' | grep -v 'tests/' || true)
  if [[ -n "$_unwrap" ]]; then
    _rs_messages="${_rs_messages}  unwrap() 감지 (테스트 외):"$'\n'
    _rs_messages="${_rs_messages}$(echo "$_unwrap" | head -5 | sed 's/^/    /')"$'\n'
    _rs_fail=1
  fi
  _unsafe=$(xargs -d '\n' grep -HnE "$WJ_RS_UNSAFE" 2>/dev/null <<< "$_rs_files" || true)
  if [[ -n "$_unsafe" ]]; then
    _rs_messages="${_rs_messages}  unsafe 블록 감지 (사유 주석 확인 필요):"$'\n'
    _rs_messages="${_rs_messages}$(echo "$_unsafe" | head -5 | sed 's/^/    /')"$'\n'
    # unsafe는 경고만 (fail 아님)
  fi
  if (( _rs_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Rust 정적 감사 실패:"$'\n'"${_rs_messages}"$'\n'
    _total_fail=1
  fi
fi

# === Swift 검사 ===
_swift_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in *.swift) ;; *) continue ;; esac
  case "$f" in *.build/*|*DerivedData/*) continue ;; esac
  [[ -f "$f" ]] || continue
  _swift_files="${_swift_files}${f}"$'\n'
done <<< "$_files"
_swift_files="$(echo "$_swift_files" | sed '/^$/d')"

if [[ -n "$_swift_files" ]]; then
  _sw_fail=0
  _sw_messages=""
  while IFS= read -r f; do
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 400 )); then
      _sw_messages="${_sw_messages}  400줄 초과: ${f} (${_lines}줄)"$'\n'
      _sw_fail=1
    fi
  done <<< "$_swift_files"
  _force=$(xargs -d '\n' grep -HnE "$WJ_SW_FORCE_UNWRAP" 2>/dev/null <<< "$_swift_files" | grep -v 'IBOutlet' | grep -v '// force-unwrap:' || true)
  if [[ -n "$_force" ]]; then
    _sw_messages="${_sw_messages}  force unwrap (!) 감지:"$'\n'
    _sw_messages="${_sw_messages}$(echo "$_force" | head -5 | sed 's/^/    /')"$'\n'
    _sw_fail=1
  fi
  _tryforce=$(xargs -d '\n' grep -HnE "$WJ_SW_TRY_FORCE" 2>/dev/null <<< "$_swift_files" || true)
  if [[ -n "$_tryforce" ]]; then
    _sw_messages="${_sw_messages}  try! 감지:"$'\n'
    _sw_messages="${_sw_messages}$(echo "$_tryforce" | head -5 | sed 's/^/    /')"$'\n'
    _sw_fail=1
  fi
  if (( _sw_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Swift 정적 감사 실패:"$'\n'"${_sw_messages}"$'\n'
    _total_fail=1
  fi
fi

# === Kotlin 검사 ===
_kt_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in *.kt|*.kts) ;; *) continue ;; esac
  case "$f" in *build/*|*generated/*) continue ;; esac
  [[ -f "$f" ]] || continue
  _kt_files="${_kt_files}${f}"$'\n'
done <<< "$_files"
_kt_files="$(echo "$_kt_files" | sed '/^$/d')"

if [[ -n "$_kt_files" ]]; then
  _kt_fail=0
  _kt_messages=""
  while IFS= read -r f; do
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 400 )); then
      _kt_messages="${_kt_messages}  400줄 초과: ${f} (${_lines}줄)"$'\n'
      _kt_fail=1
    fi
  done <<< "$_kt_files"
  _bangbang=$(xargs -d '\n' grep -HnE "$WJ_KT_BANGBANG" 2>/dev/null <<< "$_kt_files" || true)
  if [[ -n "$_bangbang" ]]; then
    _kt_messages="${_kt_messages}  !! (force unwrap) 감지:"$'\n'
    _kt_messages="${_kt_messages}$(echo "$_bangbang" | head -5 | sed 's/^/    /')"$'\n'
    _kt_fail=1
  fi
  _globalscope=$(xargs -d '\n' grep -HnE "$WJ_KT_GLOBALSCOPE" 2>/dev/null <<< "$_kt_files" || true)
  if [[ -n "$_globalscope" ]]; then
    _kt_messages="${_kt_messages}  GlobalScope 감지 — structured concurrency 사용:"$'\n'
    _kt_messages="${_kt_messages}$(echo "$_globalscope" | head -5 | sed 's/^/    /')"$'\n'
    _kt_fail=1
  fi
  if (( _kt_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Kotlin 정적 감사 실패:"$'\n'"${_kt_messages}"$'\n'
    _total_fail=1
  fi
fi

# === Cyclomatic Complexity 체크 (외부 도구 의존, 선택적) ===

# Python CC: ruff C901 (ruff + jq 설치 시만)
if [[ -n "$_py_files" ]] && command -v ruff >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  _cc_violations=""
  while IFS= read -r f; do
    _cc_out=$(ruff check --select C901 --output-format json "$f" 2>/dev/null || true)
    if [[ -n "$_cc_out" && "$_cc_out" != "[]" ]]; then
      _cc_parsed=$(echo "$_cc_out" | jq -r '.[] | "\(.filename):\(.location.row) \(.message)"' 2>/dev/null || true)
      if [[ -n "$_cc_parsed" ]]; then
        _cc_violations="${_cc_violations}${_cc_parsed}"$'\n'
      fi
    fi
  done <<< "$_py_files"
  _cc_violations="$(echo "$_cc_violations" | sed '/^$/d')"
  if [[ -n "$_cc_violations" ]]; then
    _cc_display=$(echo "$_cc_violations" | head -5 | sed 's/^/  /')
    _total_messages="${_total_messages}[L1] Python Cyclomatic Complexity 초과:"$'\n'"${_cc_display}"$'\n'
    _total_fail=1
  fi
fi

# Go CC: gocyclo (설치 시만)
if [[ -n "$_go_files" ]] && command -v gocyclo >/dev/null 2>&1; then
  _go_cc=$(xargs -d '\n' gocyclo -over 10 2>/dev/null <<< "$_go_files" || true)
  if [[ -n "$_go_cc" ]]; then
    _go_cc_display=$(echo "$_go_cc" | head -5 | sed 's/^/  /')
    _total_messages="${_total_messages}[L1] Go Cyclomatic Complexity 초과 (>10):"$'\n'"${_go_cc_display}"$'\n'
    _total_fail=1
  fi
fi

# TS/JS CC: 현재 skip (eslint complexity 규칙은 .eslintrc 의존성이 높아 L1에 부적합)
# 향후 biome 또는 oxlint에 CC 규칙이 추가되면 여기서 확장

# Rust CC: 현재 skip (cargo clippy cognitive_complexity는 L2에서 처리)
# Swift CC: 현재 skip (swiftlint cyclomatic_complexity는 L2에서 처리)
# Kotlin CC: 현재 skip (detekt CyclomaticComplexMethod는 L2에서 처리)

if (( _total_fail == 1 )); then
  echo "$_total_messages"
  exit 1
fi

echo "[L1] OK"
exit 0
