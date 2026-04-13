#!/usr/bin/env bash
# gate-l3.sh — L3 targeted test (5~30초)
# 인자: stdin으로 편집 파일 목록, $1=프로젝트 루트
# 출력: 실패 시 테스트 에러를 stdout에 출력하고 exit 1
set -euo pipefail

_root="${1:-$PWD}"
cd "$_root"

_files="$(cat || true)"
[[ -n "$_files" ]] || { echo "[L3] skip (파일 목록 없음)"; exit 0; }

# 편집 파일 → 테스트 파일 매핑
_test_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # 이미 테스트 파일이면 그대로
  case "$f" in
    *.test.*|*.spec.*|*__tests__*) _test_files="${_test_files}${f}"$'\n'; continue ;;
  esac
  # 지원 언어가 아니면 skip
  _lang=""
  case "$f" in
    *.ts|*.tsx|*.js|*.jsx) _lang="ts" ;;
    *.py) _lang="py" ;;
    *.go) _lang="go" ;;
    *.rs) _lang="rust" ;;
    *) continue ;;
  esac
  # 언어별 테스트 파일 탐색
  _dir=$(dirname "$f")
  _base=$(basename "$f" | sed 's/\.[^.]*$//')
  _ext=$(basename "$f" | sed 's/.*\.//')
  case "$_lang" in
    ts)
      # TS/JS: .test.ext, .spec.ext, __tests__/
      for _pattern in \
        "${_dir}/${_base}.test.${_ext}" \
        "${_dir}/${_base}.spec.${_ext}" \
        "${_dir}/__tests__/${_base}.test.${_ext}" \
        "${_dir}/__tests__/${_base}.spec.${_ext}"; do
        if [[ -f "$_pattern" ]]; then
          _test_files="${_test_files}${_pattern}"$'\n'
        fi
      done
      ;;
    py)
      # Python: tests/test_*.py, *_test.py, test_*.py (같은 디렉토리)
      for _pattern in \
        "${_dir}/test_${_base}.py" \
        "${_dir}/${_base}_test.py" \
        "${_dir}/tests/test_${_base}.py" \
        "${_dir}/../tests/test_${_base}.py"; do
        if [[ -f "$_pattern" ]]; then
          _test_files="${_test_files}${_pattern}"$'\n'
        fi
      done
      ;;
    go)
      # Go: 같은 디렉토리의 *_test.go
      _go_test="${_dir}/${_base}_test.go"
      if [[ -f "$_go_test" ]]; then
        _test_files="${_test_files}${_go_test}"$'\n'
      else
        # Go는 패키지 단위 테스트이므로 같은 디렉토리에 _test.go가 있으면 수집
        for _gt in "${_dir}"/*_test.go; do
          if [[ -f "$_gt" ]]; then
            _test_files="${_test_files}${_gt}"$'\n'
            break  # 하나만 찾으면 패키지 테스트 트리거
          fi
        done
      fi
      ;;
    rust)
      # Rust: 같은 파일 내 #[cfg(test)] 또는 tests/ 디렉토리
      if grep -q '#\[cfg(test)\]' "$f" 2>/dev/null; then
        _test_files="${_test_files}${f}"$'\n'  # 파일 자체가 테스트 포함
      fi
      # tests/ 디렉토리의 동명 파일
      _rs_test="${_dir}/../tests/${_base}.rs"
      if [[ -f "$_rs_test" ]]; then
        _test_files="${_test_files}${_rs_test}"$'\n'
      fi
      ;;
  esac
done <<< "$_files"

_test_files="$(echo "$_test_files" | sort -u | sed '/^$/d')"
if [[ -z "$_test_files" ]]; then
  echo "[L3] skip (매칭되는 테스트 없음)"
  exit 0
fi

echo "[L3] 대상 테스트:"
echo "$_test_files" | sed 's/^/  - /'

# 테스트 러너 감지 (다국어)
# 우선순위: ts > py > go > rust (향후 다국어 혼합 동시 실행 확장 지점)
_runner=""
_runner_lang=""

_has_ts_tests=$(echo "$_test_files" | grep -E '\.(ts|tsx|js|jsx)$' || true)
_has_py_tests=$(echo "$_test_files" | grep -E '\.py$' || true)
_has_go_tests=$(echo "$_test_files" | grep -E '_test\.go$' || true)
_has_rs_tests=$(echo "$_test_files" | grep -E '\.rs$' || true)

if [[ -n "$_has_ts_tests" ]]; then
  if [[ -f "vitest.config.ts" || -f "vitest.config.js" || -f "vitest.config.mts" ]]; then
    _runner="vitest"
  elif [[ -f "jest.config.ts" || -f "jest.config.js" || -f "jest.config.cjs" ]]; then
    _runner="jest"
  elif command -v jq >/dev/null 2>&1; then
    if jq -e '.devDependencies.vitest // .dependencies.vitest' package.json >/dev/null 2>&1; then
      _runner="vitest"
    elif jq -e '.devDependencies.jest // .dependencies.jest' package.json >/dev/null 2>&1; then
      _runner="jest"
    fi
  fi
  _runner_lang="ts"
elif [[ -n "$_has_py_tests" ]]; then
  if command -v pytest >/dev/null 2>&1; then
    _runner="pytest"
  elif command -v python3 >/dev/null 2>&1 && python3 -m pytest --version >/dev/null 2>&1; then
    _runner="pytest-module"
  fi
  _runner_lang="py"
elif [[ -n "$_has_go_tests" ]]; then
  if command -v go >/dev/null 2>&1; then
    _runner="gotest"
  fi
  _runner_lang="go"
elif [[ -n "$_has_rs_tests" ]]; then
  if command -v cargo >/dev/null 2>&1; then
    _runner="cargo-test"
  fi
  _runner_lang="rust"
fi

if [[ -z "$_runner" ]]; then
  echo "[L3] skip (테스트 러너 감지 실패)"
  exit 0
fi

_log=$(mktemp)
_exit_code=0

case "$_runner" in
  vitest)
    _file_args=$(echo "$_has_ts_tests" | tr '\n' ' ')
    echo "[L3] vitest run ${_file_args}"
    if npx vitest run $_file_args --reporter=verbose > "$_log" 2>&1; then
      echo "[L3] OK (vitest)"
      rm -f "$_log"
      exit 0
    fi
    _exit_code=1
    ;;
  jest)
    _file_args=$(echo "$_has_ts_tests" | tr '\n' ' ')
    echo "[L3] jest ${_file_args}"
    if npx jest $_file_args --verbose > "$_log" 2>&1; then
      echo "[L3] OK (jest)"
      rm -f "$_log"
      exit 0
    fi
    _exit_code=1
    ;;
  pytest|pytest-module)
    _file_args=$(echo "$_has_py_tests" | tr '\n' ' ')
    echo "[L3] pytest ${_file_args}"
    _pytest_cmd="pytest"
    if [[ "$_runner" == "pytest-module" ]]; then
      _pytest_cmd="python3 -m pytest"
    fi
    if $_pytest_cmd $_file_args -v --tb=short > "$_log" 2>&1; then
      echo "[L3] OK (pytest)"
      rm -f "$_log"
      exit 0
    fi
    _exit_code=1
    ;;
  gotest)
    # Go는 패키지 단위 테스트 — 테스트 파일의 디렉토리를 패키지로 변환
    _go_pkgs=$(echo "$_has_go_tests" | xargs -I{} dirname {} | sort -u | sed 's|^|./|' | tr '\n' ' ')
    echo "[L3] go test ${_go_pkgs}"
    if go test $_go_pkgs -v -count=1 > "$_log" 2>&1; then
      echo "[L3] OK (go test)"
      rm -f "$_log"
      exit 0
    fi
    _exit_code=1
    ;;
  cargo-test)
    # Rust: cargo test는 프로젝트 단위 — 특정 테스트 필터 사용
    _rs_names=$(echo "$_has_rs_tests" | xargs -I{} basename {} .rs | tr '\n' ' ')
    echo "[L3] cargo test ${_rs_names}"
    if cargo test $_rs_names -- --nocapture > "$_log" 2>&1; then
      echo "[L3] OK (cargo test)"
      rm -f "$_log"
      exit 0
    fi
    _exit_code=1
    ;;
esac

if (( _exit_code == 1 )); then
  echo "[L3] 테스트 실패 (마지막 20줄):"
  tail -20 "$_log"
  rm -f "$_log"
  exit 1
fi

rm -f "$_log"
echo "[L3] OK"
exit 0
