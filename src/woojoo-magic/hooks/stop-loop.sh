#!/usr/bin/env bash
# stop-loop.sh — 세션 내 Ralph 루프의 Stop hook
# Claude 응답 종료 시 실행. loop.state가 active일 때만 동작.
#
# 출력 형식 (JSON):
#   block:    {"decision":"block","reason":"..."}
#   continue: (빈 출력)
set -euo pipefail

_plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
_project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
_lib="${_plugin_root}/lib"

# loop.state 확인
_state_file="${_project_root}/.dev/state/loop.state"
if [[ ! -f "$_state_file" ]]; then
  exit 0
fi

_active=$(jq -r '.active' "$_state_file" 2>/dev/null || echo "false")
if [[ "$_active" != "true" ]]; then
  exit 0
fi

# 30분 타임아웃 체크
_started=$(jq -r '.started_at // empty' "$_state_file" 2>/dev/null || true)
if [[ -n "$_started" ]]; then
  _started_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$_started" +%s 2>/dev/null || date -d "$_started" +%s 2>/dev/null || echo 0)
  _now_epoch=$(date +%s)
  _elapsed=$(( _now_epoch - _started_epoch ))
  if (( _elapsed > 1800 )); then
    bash "$_lib/loop-state.sh" stop "timeout-30min" >/dev/null
    echo '{"decision":"block","reason":"[wj:loop] 30분 타임아웃 — 루프 자동 중단. /wj:loop start로 재시작 가능."}'
    exit 0
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
_l1_exit=0
_l1_result=""
if [[ -n "$_changed_files" ]]; then
  _l1_result=$(echo "$_changed_files" | bash "$_lib/gate-l1.sh" 2>&1) || _l1_exit=$?
fi

if [[ $_l1_exit -ne 0 ]]; then
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

# === L2: tsc 증분 (TS 파일 편집 시만) ===
_has_ts=$(echo "$_changed_files" | grep -E '\.(ts|tsx|mts|cts)$' || true)
if [[ -n "$_has_ts" ]]; then
  _l2_exit=0
  _l2_result=$(bash "$_lib/gate-l2.sh" "$_project_root" 2>&1) || _l2_exit=$?

  if [[ $_l2_exit -ne 0 ]]; then
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

# === L3: targeted test (task 있을 때만) ===
if [[ -n "$_changed_files" && -n "$_task" ]]; then
  _l3_exit=0
  _l3_result=$(echo "$_changed_files" | bash "$_lib/gate-l3.sh" "$_project_root" 2>&1) || _l3_exit=$?

  if [[ $_l3_exit -ne 0 && "$_l3_result" != *"skip"* ]]; then
    bash "$_lib/loop-state.sh" inc-failure >/dev/null
    _consecutive=$(( _consecutive + 1 ))
    if (( _consecutive >= 3 )); then
      bash "$_lib/loop-state.sh" stop "consecutive-failures" >/dev/null
      bash "$_lib/journal.sh" "$_iter" "$_task" "L3-fail-stop" "" 2>/dev/null || true
      printf '{"decision":"block","reason":"[wj:loop] 연속 %d회 게이트 실패 — 루프 자동 중단.\\n\\n%s\\n\\n수동으로 문제를 해결한 후 /wj:loop start로 재시작하세요."}' "$_consecutive" "$_l3_result"
      exit 0
    fi

    bash "$_lib/journal.sh" "$_iter" "$_task" "L3-fail" "" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj:loop] task=%s iter=%s — L3 테스트 실패:\\n\\n%s\\n\\n실패한 테스트를 먼저 수정하세요."}' "$_task" "$_iter" "$_l3_result"
    exit 0
  fi
fi

# === 게이트 전체 통과 ===
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

    printf '{"decision":"block","reason":"[wj:loop] task=%s 완료 ✅ (L1/L2/L3 통과)\\n\\n다음 eligible task: %s\\n\\n%sTDD로 구현하세요. 완료되면 .dev/tasks.json에서 이 task의 status를 done으로 업데이트하세요."}' "$_task" "$_next" "$_spec_hint"
    exit 0
  else
    _counts=$(bash "$_lib/tasks-sync.sh" count 2>/dev/null || echo '{}')
    bash "$_lib/loop-state.sh" stop "all-done" >/dev/null
    bash "$_lib/journal.sh" "$_iter" "$_task" "all-done" "전체 완료" 2>/dev/null || true
    printf '{"decision":"block","reason":"[wj:loop] 🎉 모든 task 완료!\\n\\n%s\\n\\n/wj:verify로 전체 빌드+테스트를 실행하세요."}' "$_counts"
    exit 0
  fi
else
  bash "$_lib/journal.sh" "$_iter" "$_task" "pass" "이어서 구현" 2>/dev/null || true

  _same_task_iters=$(jq -r '.iteration // 0' "$_state_file")
  if (( _same_task_iters >= 8 )); then
    printf '{"decision":"block","reason":"[wj:loop] task=%s — %d회 iteration 경과. task가 너무 크거나 blocker가 있을 수 있습니다.\\n\\ntask를 더 작게 쪼개거나, blocker를 보고하세요."}' "$_task" "$_same_task_iters"
    exit 0
  fi

  printf '{"decision":"block","reason":"[wj:loop] task=%s 게이트 통과 ✅ — 이어서 구현을 계속하세요.\\n\\n완료되면 .dev/tasks.json에서 이 task의 status를 done으로 업데이트하세요."}' "$_task"
  exit 0
fi
