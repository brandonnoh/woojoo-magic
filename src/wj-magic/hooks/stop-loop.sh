#!/usr/bin/env bash
# stop-loop.sh — Stop hook (매 응답 종료 시 실행)
#
# 루프 모드:  L1→L2→L3 게이트 (block)
# 일반 모드:  L1 정적 감사 (block — 위반 시 즉시 수정 유도)
#
# 출력 형식 (JSON):
#   block:    {"decision":"block","reason":"..."}
#   continue: (빈 출력)
set -euo pipefail

_plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
_project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
_lib="${_plugin_root}/lib"

# --- 공통 함수 ---

# _run_l1 -- L1 정적 감사 실행
# 인자: $1=변경 파일 목록, $2=로그 접두사 ("[wj-magic:gate]" 또는 "[wj-magic:loop]")
# 결과: _l1_exit (전역), _l1_out (전역)
_run_l1() {
  _files="$1"
  _prefix="$2"

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

# _run_l2 -- L2 tsc 타입체크 실행
# 인자: $1=변경 파일 목록, $2=로그 접두사
# 결과: _l2_exit (전역), _l2_out (전역), _has_ts (전역)
_run_l2() {
  _files="$1"
  _prefix="$2"

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

# loop.state 확인
_state_file="${_project_root}/.dev/state/loop.state"
_active="false"
if [[ -f "$_state_file" ]]; then
  _active=$(jq -r '.active' "$_state_file" 2>/dev/null || echo "false")
fi

# === 비루프 모드: L1 + L2 ===
if [[ "$_active" != "true" ]]; then
  _changed=$(git -C "$_project_root" diff --name-only HEAD 2>/dev/null || true)
  if [[ -z "$_changed" ]]; then
    _changed=$(git -C "$_project_root" diff --name-only 2>/dev/null || true)
  fi
  [[ -z "$_changed" ]] && exit 0

  _run_l1 "$_changed" "[wj-magic:gate]"
  if [[ $_l1_exit -ne 0 ]]; then
    printf '{"decision":"block","reason":"[wj-magic:gate] L1 정적 감사 실패 — 수정 필요:\\n\\n%s"}' "$_l1_out"
    exit 0
  fi

  _run_l2 "$_changed" "[wj-magic:gate]"
  if [[ $_l2_exit -ne 0 ]]; then
    printf '{"decision":"block","reason":"[wj-magic:gate] L2 타입체크 실패 — 수정 필요:\\n\\n%s"}' "$_l2_out"
    exit 0
  fi

  exit 0
fi

# 타임아웃 체크 (기본 60분, 0이면 비활성화)
_timeout_min=$(jq -r '.timeout_min // 0' "$_state_file" 2>/dev/null || echo 60)
if [[ "$_timeout_min" -gt 0 ]]; then
  _started=$(jq -r '.started_at // empty' "$_state_file" 2>/dev/null || true)
  if [[ -n "$_started" ]]; then
    _timeout_sec=$(( _timeout_min * 60 ))
    _started_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$_started" +%s 2>/dev/null || date -d "$_started" +%s 2>/dev/null || echo 0)
    _now_epoch=$(date +%s)
    _elapsed=$(( _now_epoch - _started_epoch ))
    if (( _elapsed > _timeout_sec )); then
      bash "$_lib/loop-state.sh" stop "timeout-${_timeout_min}min" >/dev/null
      printf '{"decision":"block","reason":"[wj-magic:loop] %d분 타임아웃 — 루프 자동 중단. /wj-magic:loop start로 재시작 가능."}' "$_timeout_min"
      exit 0
    fi
  fi
fi

# 현재 상태 읽기
_task=$(jq -r '.current_task // ""' "$_state_file")
_iter=$(jq -r '.iteration // 0' "$_state_file")
_consecutive=$(jq -r '.consecutive_failures // 0' "$_state_file")

# iteration 증가
bash "$_lib/loop-state.sh" inc-iter >/dev/null

# 변경 파일 감지 (git diff)
_changed_files=$(git -C "$_project_root" diff --name-only HEAD 2>/dev/null || true)
if [[ -z "$_changed_files" ]]; then
  _changed_files=$(git -C "$_project_root" diff --name-only 2>/dev/null || true)
fi

# === L1: 정적 감사 ===
echo "[wj-magic:loop] ── 게이트 검증 시작 (task=${_task} iter=${_iter}) ──" >&2
_run_l1 "$_changed_files" "[wj-magic:loop]"

if [[ $_l1_exit -ne 0 ]]; then
  bash "$_lib/loop-state.sh" inc-failure >/dev/null
  _consecutive=$(( _consecutive + 1 ))

  if (( _consecutive >= 3 )); then
    bash "$_lib/loop-state.sh" stop "consecutive-failures" >/dev/null
    bash "$_lib/journal.sh" "$_iter" "$_task" "L1-fail-stop" "연속 ${_consecutive}회 실패로 중단" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj-magic:loop] 연속 %d회 게이트 실패 — 루프 자동 중단.\\n\\n%s\\n\\n수동으로 문제를 해결한 후 /wj-magic:loop start로 재시작하세요."}' "$_consecutive" "$_l1_out"
    exit 0
  fi

  bash "$_lib/journal.sh" "$_iter" "$_task" "L1-fail" "" 2>/dev/null || true
  printf '{"decision":"block","reason":"[wj-magic:loop] task=%s iter=%s — L1 게이트 실패:\\n\\n%s\\n\\n이 문제를 먼저 수정하세요."}' "$_task" "$_iter" "$_l1_out"
  exit 0
fi

# === L2: tsc 증분 (TS 파일 편집 시만) ===
_run_l2 "$_changed_files" "[wj-magic:loop]"

if [[ $_l2_exit -ne 0 ]]; then
  bash "$_lib/loop-state.sh" inc-failure >/dev/null
  _consecutive=$(( _consecutive + 1 ))
  if (( _consecutive >= 3 )); then
    bash "$_lib/loop-state.sh" stop "consecutive-failures" >/dev/null
    bash "$_lib/journal.sh" "$_iter" "$_task" "L2-fail-stop" "" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj-magic:loop] 연속 %d회 게이트 실패 — 루프 자동 중단.\\n\\n%s\\n\\n수동으로 문제를 해결한 후 /wj-magic:loop start로 재시작하세요."}' "$_consecutive" "$_l2_out"
    exit 0
  fi

  bash "$_lib/journal.sh" "$_iter" "$_task" "L2-fail" "" 2>/dev/null || true
  printf '{"decision":"block","reason":"[wj-magic:loop] task=%s iter=%s — L2 타입체크 실패:\\n\\n%s\\n\\n이 타입 에러부터 수정하세요."}' "$_task" "$_iter" "$_l2_out"
  exit 0
fi

# === L3: targeted test (task 있을 때만) ===
if [[ -n "$_changed_files" && -n "$_task" ]]; then
  echo "[wj-magic:loop] ▶ L3 targeted 테스트 ..." >&2
  _l3_exit=0
  _l3_result=$(echo "$_changed_files" | bash "$_lib/gate-l3.sh" "$_project_root" 2>&1) || _l3_exit=$?

  if [[ $_l3_exit -ne 0 && "$_l3_result" != *"skip"* ]]; then
    echo "[wj-magic:loop] ✗ L3 실패" >&2
    bash "$_lib/loop-state.sh" inc-failure >/dev/null
    _consecutive=$(( _consecutive + 1 ))
    if (( _consecutive >= 3 )); then
      bash "$_lib/loop-state.sh" stop "consecutive-failures" >/dev/null
      bash "$_lib/journal.sh" "$_iter" "$_task" "L3-fail-stop" "" 2>/dev/null || true
      printf '{"decision":"block","reason":"[wj-magic:loop] 연속 %d회 게이트 실패 — 루프 자동 중단.\\n\\n%s\\n\\n수동으로 문제를 해결한 후 /wj-magic:loop start로 재시작하세요."}' "$_consecutive" "$_l3_result"
      exit 0
    fi

    bash "$_lib/journal.sh" "$_iter" "$_task" "L3-fail" "" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj-magic:loop] task=%s iter=%s — L3 테스트 실패:\\n\\n%s\\n\\n실패한 테스트를 먼저 수정하세요."}' "$_task" "$_iter" "$_l3_result"
    exit 0
  fi
  echo "[wj-magic:loop] ✓ L3 통과" >&2
else
  echo "[wj-magic:loop] ○ L3 skip (변경 파일 없음 또는 task 미지정)" >&2
fi

# === 게이트 전체 통과 ===
echo "[wj-magic:loop] ── 게이트 전체 통과 ✅ (L1→L2→L3) ──" >&2
bash "$_lib/loop-state.sh" reset-failure >/dev/null

# task 완료 여부 확인
_task_status=""
if [[ -n "$_task" ]]; then
  _task_status=$(jq -r --arg id "$_task" '.features[] | select(.id == $id) | .status // "pending"' "${_project_root}/.dev/tasks.json" 2>/dev/null || echo "pending")
fi

if [[ "$_task_status" == "done" ]]; then
  _next=$(bash "$_lib/tasks-sync.sh" next "$_task" 2>/dev/null || true)

  if [[ -n "$_next" ]]; then
    jq --arg t "$_next" '.current_task=$t' "$_state_file" > "$_state_file.tmp" && mv "$_state_file.tmp" "$_state_file"
    bash "$_lib/journal.sh" "$_iter" "$_task" "pass" "완료 → 다음: $_next" 2>/dev/null || true

    _spec_hint=""
    if [[ -f "${_project_root}/docs/specs/${_next}.md" ]]; then
      _spec_hint="docs/specs/${_next}.md를 먼저 읽고 "
    fi

    printf '{"decision":"block","reason":"[wj-magic:loop] task=%s 완료 ✅ (L1/L2/L3 통과)\\n\\n다음 eligible task: %s\\n\\n%sTDD로 구현하세요. 완료되면 .dev/tasks.json에서 이 task의 status를 done으로 업데이트하세요."}' "$_task" "$_next" "$_spec_hint"
    exit 0
  else
    _counts=$(bash "$_lib/tasks-sync.sh" count 2>/dev/null || echo '{}')
    bash "$_lib/loop-state.sh" stop "all-done" >/dev/null
    bash "$_lib/journal.sh" "$_iter" "$_task" "all-done" "전체 완료" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj-magic:loop] 🎉 모든 task 완료!\\n\\n%s\\n\\n/wj-magic:verify로 전체 빌드+테스트를 실행하세요."}' "$_counts"
    exit 0
  fi
else
  bash "$_lib/journal.sh" "$_iter" "$_task" "pass" "이어서 구현" 2>/dev/null || true

  _same_task_iters=$(jq -r '.iteration // 0' "$_state_file")
  if (( _same_task_iters >= 8 )); then
    printf '{"decision":"block","reason":"[wj-magic:loop] task=%s — %d회 iteration 경과. task가 너무 크거나 blocker가 있을 수 있습니다.\\n\\ntask를 더 작게 쪼개거나, blocker를 보고하세요."}' "$_task" "$_same_task_iters"
    exit 0
  fi

  printf '{"decision":"block","reason":"[wj-magic:loop] task=%s 게이트 통과 ✅ — 이어서 구현을 계속하세요.\\n\\n완료되면 .dev/tasks.json에서 이 task의 status를 done으로 업데이트하세요."}' "$_task"
  exit 0
fi
