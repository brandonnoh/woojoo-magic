# h4-l3-multilang: gate-l3.sh 다국어 테스트 러너 확장

## 배경

`gate-l3.sh`는 L3 targeted test 게이트로, 편집된 파일에 대응하는 테스트만 실행한다.
현재 **TS/JS (vitest, jest)만 지원**하며, Python/Go/Rust는 skip된다.
`references/INDEX.md`에 모든 언어의 테스트 명령이 정의되어 있으므로 확장이 필요하다.

## 대상 파일

- `src/wj-magic/lib/gate-l3.sh` (현재 92줄)

## 현재 구조 (줄 번호 기준)

| 구간 | 줄 번호 | 내용 |
|------|---------|------|
| 초기화 | 1-8 | `_root`, `cd` |
| 입력 파싱 | 10-11 | stdin → `_files` |
| 파일→테스트 매핑 | 13-39 | TS/JS 전용 매핑 로직 |
| 테스트 파일 정리 | 41-45 | `sort -u`, 빈 목록이면 skip |
| 대상 출력 | 47-48 | `[L3] 대상 테스트:` |
| 러너 감지 | 50-63 | vitest/jest만 감지 |
| 파일 인자 구성 | 65-66 | `_file_args` |
| 테스트 실행 | 68-86 | vitest run / jest |
| 실패 출력 | 88-91 | 마지막 20줄 + exit 1 |

### 현재 파일→테스트 매핑 로직 (줄 13-39 상세)

```bash
# 이미 테스트 파일이면 그대로 추가
case "$f" in
  *.test.*|*.spec.*|*__tests__*) → 직접 추가

# TS/JS가 아니면 skip    ← 여기서 Python/Go/Rust가 모두 탈락
case "$f" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) continue ;;

# 같은 디렉토리에서 .test./.spec./__tests__/ 패턴 탐색
```

### 현재 러너 감지 로직 (줄 50-63)

```bash
vitest.config.* → vitest
jest.config.* → jest
package.json devDependencies → vitest/jest
그 외 → skip
```

## 변경 내용

### 1. 파일→테스트 매핑: Python 추가 (줄 25 수정)

**현재 줄 22-25:**
```bash
  # TS/JS가 아니면 skip
  case "$f" in
    *.ts|*.tsx|*.js|*.jsx) ;;
    *) continue ;;
  esac
```

**변경 후:**
```bash
  # 지원 언어가 아니면 skip
  _lang=""
  case "$f" in
    *.ts|*.tsx|*.js|*.jsx) _lang="ts" ;;
    *.py) _lang="py" ;;
    *.go) _lang="go" ;;
    *.rs) _lang="rust" ;;
    *) continue ;;
  esac
```

### 2. 테스트 파일 탐색: 언어별 분기 (줄 27-38 교체)

**현재 줄 27-38** (TS/JS 전용 매핑):
```bash
  _dir=$(dirname "$f")
  _base=$(basename "$f" | sed 's/\.[^.]*$//')
  _ext=$(basename "$f" | sed 's/.*\.//')
  for _pattern in \
    "${_dir}/${_base}.test.${_ext}" \
    "${_dir}/${_base}.spec.${_ext}" \
    "${_dir}/__tests__/${_base}.test.${_ext}" \
    "${_dir}/__tests__/${_base}.spec.${_ext}"; do
    if [[ -f "$_pattern" ]]; then
      _test_files="${_test_files}${_pattern}"$'\n'
    fi
  done
```

**변경 후** (언어별 분기):
```bash
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
```

### 3. 러너 감지: 다국어 확장 (줄 50-63 교체)

**현재 줄 50-63 전체를 교체:**

```bash
# 테스트 러너 감지 (다국어)
_runner=""
_runner_lang=""

# TS/JS 테스트 파일이 있는지 확인
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
```

### 4. 테스트 실행: 다국어 확장 (줄 65-91 교체)

**현재 줄 65-91 전체를 교체:**

```bash
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
```

## 언어별 파일→테스트 매핑 전략

| 언어 | 소스 파일 | 테스트 파일 후보 | 패턴 |
|------|----------|---------------|------|
| TS/JS | `src/utils.ts` | `src/utils.test.ts`, `src/utils.spec.ts`, `src/__tests__/utils.test.ts` | `.test.ext`, `.spec.ext`, `__tests__/` |
| Python | `app/service.py` | `app/test_service.py`, `app/service_test.py`, `app/tests/test_service.py`, `tests/test_service.py` | `test_*.py`, `*_test.py` |
| Go | `pkg/handler.go` | `pkg/handler_test.go`, `pkg/*_test.go` (패키지 단위) | `*_test.go` 같은 디렉토리 |
| Rust | `src/lib.rs` | `src/lib.rs` 자체 (`#[cfg(test)]`), `tests/lib.rs` | 인라인 테스트 또는 `tests/` |

## 러너 감지 및 명령 형식

| 러너 | 감지 방법 | 명령 형식 | 타임아웃 |
|------|----------|----------|---------|
| vitest | `vitest.config.*` 또는 package.json | `npx vitest run <files> --reporter=verbose` | 30초 (기존) |
| jest | `jest.config.*` 또는 package.json | `npx jest <files> --verbose` | 30초 (기존) |
| pytest | `command -v pytest` | `pytest <files> -v --tb=short` | 30초 |
| go test | `command -v go` | `go test <packages> -v -count=1` | 30초 |
| cargo test | `command -v cargo` | `cargo test <names> -- --nocapture` | 60초 (컴파일 포함) |

## 다국어 혼합 프로젝트 처리

현재 구현은 **우선순위 기반 단일 언어 실행**: ts > py > go > rust.
다국어 혼합 프로젝트에서 두 언어의 테스트를 모두 실행하려면 향후 확장 필요.
1차 구현에서는 단일 언어만 실행하되, 주석으로 확장 지점을 명시한다.

## 의존성

- `pytest` (선택): Python 테스트. 미설치 시 skip.
- `go` (선택): Go 테스트. 미설치 시 skip.
- `cargo` (선택): Rust 테스트. 미설치 시 skip.
- 기존 의존: `npx`, `jq`.

## 수락 조건

1. Python `.py` 파일 편집 시 `test_*.py`/`*_test.py` 매핑 및 pytest 실행
2. Go `.go` 파일 편집 시 `*_test.go` 매핑 및 `go test` 실행
3. Rust `.rs` 파일 편집 시 인라인 `#[cfg(test)]` 또는 `tests/` 매핑 및 `cargo test` 실행
4. 기존 TS/JS (vitest/jest) 동작 변경 없음
5. 각 러너 미설치 시 `[L3] skip` 출력 및 exit 0
6. 테스트 실패 시 마지막 20줄 출력 및 exit 1
7. `set -euo pipefail` 하에서 에러 없음
