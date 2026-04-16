# m2-stop-loop-dedup: stop-loop.sh 비루프/루프 코드 중복 제거

> 우선순위: MEDIUM  
> 예상 작업량: ~60줄 감소  
> 의존성: 없음 (독립 작업)

## 1. 현황 분석

`hooks/stop-loop.sh`는 비루프 모드(24-58줄)와 루프 모드(88-139줄)에서 L1/L2 실행 로직을 **거의 동일하게 반복**한다.

### 1.1 비루프 모드 L1 (31-41줄)

```bash
  # L1 정적 감사
  echo "[wj:gate] ▶ L1 정적 감사 ..." >&2
  _l1_exit=0
  _l1_out=$(echo "$_changed" | bash "$_lib/gate-l1.sh" 2>&1) || _l1_exit=$?

  if [[ $_l1_exit -ne 0 ]]; then
    echo "[wj:gate] ✗ L1 실패" >&2
    printf '{"decision":"block","reason":"[wj:gate] L1 정적 감사 실패 — 수정 필요:\\n\\n%s"}' "$_l1_out"
    exit 0
  fi
  echo "[wj:gate] ✓ L1 통과" >&2
```

### 1.2 루프 모드 L1 (88-114줄)

```bash
# === L1: 정적 감사 ===
echo "[wj:loop] ── 게이트 검증 시작 (task=${_task} iter=${_iter}) ──" >&2
_l1_exit=0
_l1_result=""
if [[ -n "$_changed_files" ]]; then
  echo "[wj:loop] ▶ L1 정적 감사 (300줄/any/!./silent catch) ..." >&2
  _l1_result=$(echo "$_changed_files" | bash "$_lib/gate-l1.sh" 2>&1) || _l1_exit=$?
else
  echo "[wj:loop] ▶ L1 skip (변경 파일 없음)" >&2
fi

if [[ $_l1_exit -ne 0 ]]; then
  echo "[wj:loop] ✗ L1 실패" >&2
  bash "$_lib/loop-state.sh" inc-failure >/dev/null
  _consecutive=$(( _consecutive + 1 ))
  ...
fi
```

### 1.3 비루프 모드 L2 (43-56줄)

```bash
  _has_ts=$(echo "$_changed" | grep -E '\.(ts|tsx|mts|cts)$' || true)
  if [[ -n "$_has_ts" ]]; then
    echo "[wj:gate] ▶ L2 tsc 타입체크 ..." >&2
    _l2_exit=0
    _l2_out=$(bash "$_lib/gate-l2.sh" "$_project_root" 2>&1) || _l2_exit=$?

    if [[ $_l2_exit -ne 0 ]]; then
      echo "[wj:gate] ✗ L2 실패" >&2
      printf '{"decision":"block","reason":"[wj:gate] L2 타입체크 실패 — 수정 필요:\\n\\n%s"}' "$_l2_out"
      exit 0
    fi
    echo "[wj:gate] ✓ L2 통과" >&2
  fi
```

### 1.4 루프 모드 L2 (116-139줄)

```bash
echo "[wj:loop] ✓ L1 통과" >&2
_has_ts=$(echo "$_changed_files" | grep -E '\.(ts|tsx|mts|cts)$' || true)
if [[ -n "$_has_ts" ]]; then
  echo "[wj:loop] ▶ L2 tsc 타입체크 ..." >&2
  _l2_exit=0
  _l2_result=$(bash "$_lib/gate-l2.sh" "$_project_root" 2>&1) || _l2_exit=$?

  if [[ $_l2_exit -ne 0 ]]; then
    echo "[wj:loop] ✗ L2 실패" >&2
    bash "$_lib/loop-state.sh" inc-failure >/dev/null
    ...
  fi
fi
```

## 2. 중복 핵심 포인트

| 요소 | 비루프 | 루프 | 차이 |
|------|--------|------|------|
| L1 실행 | `echo "$_changed" \| bash "$_lib/gate-l1.sh"` | `echo "$_changed_files" \| bash "$_lib/gate-l1.sh"` | 변수명만 다름 |
| L2 실행 | `bash "$_lib/gate-l2.sh" "$_project_root"` | `bash "$_lib/gate-l2.sh" "$_project_root"` | **동일** |
| 실패 시 | printf 후 exit 0 | inc-failure + consecutive 카운트 + printf 후 exit 0 | 루프 모드는 실패 추적 추가 |
| 로그 접두사 | `[wj:gate]` | `[wj:loop]` | 접두사만 다름 |
| TS 필터 | `echo "$_changed" \| grep -E '\.(ts\|tsx\|mts\|cts)$'` | `echo "$_changed_files" \| grep -E '\.(ts\|tsx\|mts\|cts)$'` | 변수명만 다름 |

## 3. 설계: _run_l1() / _run_l2() 함수

### 3.1 CLAUDE.md 규칙 준수

CLAUDE.md 규칙: "메인 루프에서 `local` 금지, `_prefix` 변수명 사용"

함수 내부에서는 `local`을 사용해도 된다 (함수는 메인 루프가 아니므로).
단, 함수가 메인 루프 변수를 설정해야 하는 경우 전역 `_prefix` 변수를 사용한다.

### 3.2 _run_l1() 설계

```bash
# _run_l1 — L1 정적 감사 실행
# 인자: $1=변경 파일 목록, $2=로그 접두사 ("[wj:gate]" 또는 "[wj:loop]")
# 결과: _l1_exit (전역), _l1_out (전역)
_run_l1() {
  local _files="$1"
  local _prefix="$2"

  _l1_exit=0
  _l1_out=""

  if [[ -z "$_files" ]]; then
    echo "${_prefix} ▶ L1 skip (변경 파일 없음)" >&2
    return 0
  fi

  echo "${_prefix} ▶ L1 정적 감사 ..." >&2
  _l1_out=$(echo "$_files" | bash "$_lib/gate-l1.sh" 2>&1) || _l1_exit=$?

  if [[ $_l1_exit -ne 0 ]]; then
    echo "${_prefix} ✗ L1 실패" >&2
  else
    echo "${_prefix} ✓ L1 통과" >&2
  fi
}
```

### 3.3 _run_l2() 설계

```bash
# _run_l2 — L2 tsc 타입체크 실행
# 인자: $1=변경 파일 목록, $2=로그 접두사
# 결과: _l2_exit (전역), _l2_out (전역), _has_ts (전역)
_run_l2() {
  local _files="$1"
  local _prefix="$2"

  _l2_exit=0
  _l2_out=""
  _has_ts=$(echo "$_files" | grep -E '\.(ts|tsx|mts|cts)$' || true)

  if [[ -z "$_has_ts" ]]; then
    echo "${_prefix} ○ L2 skip (TS 파일 변경 없음)" >&2
    return 0
  fi

  echo "${_prefix} ▶ L2 tsc 타입체크 ..." >&2
  _l2_out=$(bash "$_lib/gate-l2.sh" "$_project_root" 2>&1) || _l2_exit=$?

  if [[ $_l2_exit -ne 0 ]]; then
    echo "${_prefix} ✗ L2 실패" >&2
  else
    echo "${_prefix} ✓ L2 통과" >&2
  fi
}
```

## 4. 리팩토링 후 stop-loop.sh 구조

### 4.1 함수 삽입 위치

15줄 (`_lib="${_plugin_root}/lib"`) 바로 뒤, 17줄 (`_state_file=...`) 앞에 함수 2개를 삽입한다.

### 4.2 비루프 모드 (현재 24-58줄) 리팩토링

**Before (24-58줄, 35줄):**
```bash
if [[ "$_active" != "true" ]]; then
  _changed=$(git -C "$_project_root" diff --name-only HEAD 2>/dev/null || true)
  if [[ -z "$_changed" ]]; then
    _changed=$(git -C "$_project_root" diff --name-only 2>/dev/null || true)
  fi
  [[ -z "$_changed" ]] && exit 0

  # L1 정적 감사
  echo "[wj:gate] ▶ L1 정적 감사 ..." >&2
  _l1_exit=0
  _l1_out=$(echo "$_changed" | bash "$_lib/gate-l1.sh" 2>&1) || _l1_exit=$?

  if [[ $_l1_exit -ne 0 ]]; then
    echo "[wj:gate] ✗ L1 실패" >&2
    printf '{"decision":"block","reason":"[wj:gate] L1 정적 감사 실패 — 수정 필요:\\n\\n%s"}' "$_l1_out"
    exit 0
  fi
  echo "[wj:gate] ✓ L1 통과" >&2

  # L2 tsc 타입체크 (TS 파일 변경 시만)
  _has_ts=$(echo "$_changed" | grep -E '\.(ts|tsx|mts|cts)$' || true)
  if [[ -n "$_has_ts" ]]; then
    echo "[wj:gate] ▶ L2 tsc 타입체크 ..." >&2
    _l2_exit=0
    _l2_out=$(bash "$_lib/gate-l2.sh" "$_project_root" 2>&1) || _l2_exit=$?

    if [[ $_l2_exit -ne 0 ]]; then
      echo "[wj:gate] ✗ L2 실패" >&2
      printf '{"decision":"block","reason":"[wj:gate] L2 타입체크 실패 — 수정 필요:\\n\\n%s"}' "$_l2_out"
      exit 0
    fi
    echo "[wj:gate] ✓ L2 통과" >&2
  fi

  exit 0
fi
```

**After (약 18줄):**
```bash
if [[ "$_active" != "true" ]]; then
  _changed=$(git -C "$_project_root" diff --name-only HEAD 2>/dev/null || true)
  if [[ -z "$_changed" ]]; then
    _changed=$(git -C "$_project_root" diff --name-only 2>/dev/null || true)
  fi
  [[ -z "$_changed" ]] && exit 0

  _run_l1 "$_changed" "[wj:gate]"
  if [[ $_l1_exit -ne 0 ]]; then
    printf '{"decision":"block","reason":"[wj:gate] L1 정적 감사 실패 — 수정 필요:\\n\\n%s"}' "$_l1_out"
    exit 0
  fi

  _run_l2 "$_changed" "[wj:gate]"
  if [[ $_l2_exit -ne 0 ]]; then
    printf '{"decision":"block","reason":"[wj:gate] L2 타입체크 실패 — 수정 필요:\\n\\n%s"}' "$_l2_out"
    exit 0
  fi

  exit 0
fi
```

### 4.3 루프 모드 L1 (현재 88-114줄) 리팩토링

**Before (88-114줄, 27줄):**
```bash
# === L1: 정적 감사 ===
echo "[wj:loop] ── 게이트 검증 시작 (task=${_task} iter=${_iter}) ──" >&2
_l1_exit=0
_l1_result=""
if [[ -n "$_changed_files" ]]; then
  echo "[wj:loop] ▶ L1 정적 감사 (300줄/any/!./silent catch) ..." >&2
  _l1_result=$(echo "$_changed_files" | bash "$_lib/gate-l1.sh" 2>&1) || _l1_exit=$?
else
  echo "[wj:loop] ▶ L1 skip (변경 파일 없음)" >&2
fi

if [[ $_l1_exit -ne 0 ]]; then
  echo "[wj:loop] ✗ L1 실패" >&2
  bash "$_lib/loop-state.sh" inc-failure >/dev/null
  _consecutive=$(( _consecutive + 1 ))

  if (( _consecutive >= 3 )); then
    bash "$_lib/loop-state.sh" stop "consecutive-failures" >/dev/null
    bash "$_lib/journal.sh" "$_iter" "$_task" "L1-fail-stop" "연속 ${_consecutive}회 실패로 중단" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj:loop] 연속 %d회 게이트 실패 — 루프 자동 중단.\\n\\n%s\\n\\n수동으로 문제를 해결한 후 /wj:loop start로 재시작하세요."}' "$_consecutive" "$_l1_result"
    exit 0
  fi

  bash "$_lib/journal.sh" "$_iter" "$_task" "L1-fail" "" 2>/dev/null || true
  printf '{"decision":"block","reason":"[wj:loop] task=%s iter=%s — L1 게이트 실패:\\n\\n%s\\n\\n이 문제를 먼저 수정하세요."}' "$_task" "$_iter" "$_l1_result"
  exit 0
fi
```

**After (약 16줄):**
```bash
# === L1: 정적 감사 ===
echo "[wj:loop] ── 게이트 검증 시작 (task=${_task} iter=${_iter}) ──" >&2
_run_l1 "$_changed_files" "[wj:loop]"

if [[ $_l1_exit -ne 0 ]]; then
  bash "$_lib/loop-state.sh" inc-failure >/dev/null
  _consecutive=$(( _consecutive + 1 ))

  if (( _consecutive >= 3 )); then
    bash "$_lib/loop-state.sh" stop "consecutive-failures" >/dev/null
    bash "$_lib/journal.sh" "$_iter" "$_task" "L1-fail-stop" "연속 ${_consecutive}회 실패로 중단" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj:loop] 연속 %d회 게이트 실패 — 루프 자동 중단.\\n\\n%s\\n\\n수동으로 문제를 해결한 후 /wj:loop start로 재시작하세요."}' "$_consecutive" "$_l1_out"
    exit 0
  fi

  bash "$_lib/journal.sh" "$_iter" "$_task" "L1-fail" "" 2>/dev/null || true
  printf '{"decision":"block","reason":"[wj:loop] task=%s iter=%s — L1 게이트 실패:\\n\\n%s\\n\\n이 문제를 먼저 수정하세요."}' "$_task" "$_iter" "$_l1_out"
  exit 0
fi
```

**주의:** 루프 모드에서 `_l1_result` 변수명을 `_l1_out`으로 통일한다 (_run_l1 함수가 `_l1_out`을 설정).

### 4.4 루프 모드 L2 (현재 116-139줄) 리팩토링

**Before (116-139줄, 24줄):**
```bash
# === L2: tsc 증분 (TS 파일 편집 시만) ===
echo "[wj:loop] ✓ L1 통과" >&2
_has_ts=$(echo "$_changed_files" | grep -E '\.(ts|tsx|mts|cts)$' || true)
if [[ -n "$_has_ts" ]]; then
  echo "[wj:loop] ▶ L2 tsc 타입체크 ..." >&2
  _l2_exit=0
  _l2_result=$(bash "$_lib/gate-l2.sh" "$_project_root" 2>&1) || _l2_exit=$?

  if [[ $_l2_exit -ne 0 ]]; then
    echo "[wj:loop] ✗ L2 실패" >&2
    bash "$_lib/loop-state.sh" inc-failure >/dev/null
    _consecutive=$(( _consecutive + 1 ))
    if (( _consecutive >= 3 )); then
      bash "$_lib/loop-state.sh" stop "consecutive-failures" >/dev/null
      bash "$_lib/journal.sh" "$_iter" "$_task" "L2-fail-stop" "" 2>/dev/null || true
      printf '{"decision":"block","reason":"[wj:loop] 연속 %d회 게이트 실패 — 루프 자동 중단.\\n\\n%s\\n\\n수동으로 문제를 해결한 후 /wj:loop start로 재시작하세요."}' "$_consecutive" "$_l2_result"
      exit 0
    fi

    bash "$_lib/journal.sh" "$_iter" "$_task" "L2-fail" "" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj:loop] task=%s iter=%s — L2 타입체크 실패:\\n\\n%s\\n\\n이 타입 에러부터 수정하세요."}' "$_task" "$_iter" "$_l2_result"
    exit 0
  fi
fi
```

**After (약 16줄):**
```bash
# === L2: tsc 증분 (TS 파일 편집 시만) ===
_run_l2 "$_changed_files" "[wj:loop]"

if [[ $_l2_exit -ne 0 ]]; then
  bash "$_lib/loop-state.sh" inc-failure >/dev/null
  _consecutive=$(( _consecutive + 1 ))
  if (( _consecutive >= 3 )); then
    bash "$_lib/loop-state.sh" stop "consecutive-failures" >/dev/null
    bash "$_lib/journal.sh" "$_iter" "$_task" "L2-fail-stop" "" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj:loop] 연속 %d회 게이트 실패 — 루프 자동 중단.\\n\\n%s\\n\\n수동으로 문제를 해결한 후 /wj:loop start로 재시작하세요."}' "$_consecutive" "$_l2_out"
    exit 0
  fi

  bash "$_lib/journal.sh" "$_iter" "$_task" "L2-fail" "" 2>/dev/null || true
  printf '{"decision":"block","reason":"[wj:loop] task=%s iter=%s — L2 타입체크 실패:\\n\\n%s\\n\\n이 타입 에러부터 수정하세요."}' "$_task" "$_iter" "$_l2_out"
  exit 0
fi
```

**주의:** `_l2_result` 변수명을 `_l2_out`으로 통일.

## 5. 줄 수 감소 추정

| 구간 | Before | After | 절감 |
|------|--------|-------|------|
| 함수 정의 (신규) | 0줄 | 30줄 | +30줄 |
| 비루프 L1+L2 (24-58줄) | 35줄 | 18줄 | -17줄 |
| 루프 L1 (88-114줄) | 27줄 | 16줄 | -11줄 |
| 루프 L2 (116-139줄) | 24줄 | 16줄 | -8줄 |
| L2 로그 (142-146줄) | 5줄 | 0줄 (함수 내 처리) | -5줄 |
| **합계** | | | **-11줄 순감소** |

실질적 중복 코드는 **약 60줄이 30줄 함수로 통합**되어 유지보수성이 크게 향상.

## 6. 변수명 통일 필수 사항

루프 모드에서 `_l1_result`/`_l2_result`를 사용하던 것을 함수의 출력인 `_l1_out`/`_l2_out`으로 **모두 치환**해야 한다.

영향 받는 줄:
- 94줄: `_l1_result=$(echo ...` → 함수로 대체 (삭제)
- 107줄: `"$_l1_result"` → `"$_l1_out"`
- 112줄: `"$_l1_result"` → `"$_l1_out"`
- 122줄: `_l2_result=$(bash ...` → 함수로 대체 (삭제)
- 131줄: `"$_l2_result"` → `"$_l2_out"`
- 136줄: `"$_l2_result"` → `"$_l2_out"`

## 7. 테스트 계획

- `tests/stop-loop.bats` 기존 테스트 전부 통과 확인
- 비루프 모드에서 L1 실패 시 block JSON 출력 형식 일치 확인
- 루프 모드에서 consecutive failure 카운트 정상 동작 확인

## 8. 파일 변경 요약

| 파일 | 동작 |
|------|------|
| `src/woojoo-magic/hooks/stop-loop.sh` | 함수 2개 추가 (15줄 뒤) + 비루프/루프 L1/L2 블록 리팩토링 |
