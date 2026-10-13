#!/usr/bin/env bash
# wj-magic: 세션 시작 프로젝트 상태 요약
set -euo pipefail

_project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "${_project_root}" || exit 0

if [[ ! -d .git ]]; then
  exit 0
fi

_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
_recent="$(git log -3 --pretty=format:'  - %h %s' 2>/dev/null || true)"

echo "IMPORTANT: 아래 세션 시작 요약을 사용자에게 첫 응답에서 반드시 보여주세요:"
echo ""
echo "  ──── MCP 필수 도구 (HARD RULE — 위반 시 품질 결함) ────"
echo "  [필수] Serena MCP — 코드 수정 전 find_symbol + find_referencing_symbols로 참조 확인 필수"
echo "  [필수] Context7 MCP — 라이브러리 API 사용 시 resolve-library-id → query-docs 호출 필수"
echo "  [금지] 추측으로 파일명·함수명 지목 — Serena/Grep 증거 없이 수정 시도 금지"
echo "  [강제] Edit/Write 전에 Serena를 사용하지 않으면 PreToolUse 훅이 매번 경고를 출력합니다."
echo "  [강제] CLAUDE.md § MCP 필수 사용 규칙에 상세 기준이 명시되어 있습니다. 반드시 준수하세요."
echo ""
echo "[wj-magic] 세션 시작 요약"
echo "  브랜치: ${_branch}"
if [[ -n "${_recent}" ]]; then
  echo "  최근 커밋:"
  echo "${_recent}"
fi

# 300줄 초과 파일 · any / !. 카운트 — git 저장소면 추적 중인 파일만(git ls-files·git grep) 본다.
# find·grep -r로 훑으면 .claude/worktrees(저장소 사본 여러 개)·가상환경까지 들어가 세션 시작이 몇 분씩 멈춘다.
_code_globs=('*.ts' '*.tsx' '*.js' '*.jsx')
_ts_globs=('*.ts' '*.tsx')
_PRUNE_DIRS=(node_modules .git dist build .next coverage .claude worktrees .venv venv __pycache__ target out)
_in_git=0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && _in_git=1

_list_code_files() {
  if [[ "${_in_git}" == "1" ]]; then
    git ls-files -z -- "${_code_globs[@]}" 2>/dev/null
    return
  fi
  local prune=() d
  for d in "${_PRUNE_DIRS[@]}"; do prune+=(-o -name "${d}"); done
  find . -type d \( "${prune[@]:1}" \) -prune \
    -o -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) -print0 2>/dev/null
}

_count_ts_matches() {
  local pattern="$1"
  if [[ "${_in_git}" == "1" ]]; then
    { git grep -nIE "${pattern}" -- "${_ts_globs[@]}" 2>/dev/null || true; } | wc -l | tr -d ' '
    return
  fi
  local excl=() d
  for d in "${_PRUNE_DIRS[@]}"; do excl+=(--exclude-dir="${d}"); done
  { grep -rIn --include='*.ts' --include='*.tsx' "${excl[@]}" -E "${pattern}" . 2>/dev/null || true; } | wc -l | tr -d ' '
}

_over=$( { _list_code_files | xargs -0 wc -l 2>/dev/null || true; } | awk '$2 != "total" && $1 > 300' | wc -l | tr -d ' ')
echo "  300줄 초과 파일: ${_over}개"

_any=$(_count_ts_matches ': any([^A-Za-z0-9_]|$)|<any>|as any([^A-Za-z0-9_]|$)') # \b는 git grep -E가 지원하지 않는다
_bang=$(_count_ts_matches '[A-Za-z0-9_)\]]!\.')
echo "  any 사용: ${_any}곳 / !. 사용: ${_bang}곳"

# .dev/tasks.json 진행률
if [[ -f "${_project_root}/.dev/tasks.json" ]] && command -v jq >/dev/null 2>&1; then
  _total=$(jq '[.features[]?] | length' "${_project_root}/.dev/tasks.json" 2>/dev/null || echo 0)
  _done=$(jq '[.features[]? | select(.status=="done")] | length' "${_project_root}/.dev/tasks.json" 2>/dev/null || echo 0)
  if [[ "${_total}" != "0" ]]; then
    echo "  tasks: ${_done}/${_total} 완료"
    _current=$(jq -r '[.features[]? | select(.status!="done")][0].id // empty' "${_project_root}/.dev/tasks.json" 2>/dev/null || true)
    if [[ -n "${_current}" ]]; then
      echo "  다음 task: ${_current}"
    fi
  fi
fi

# 핵심 규칙 리마인더 (개발 작업 시 자동 참조)
_plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -n "${_plugin_root}" ]]; then
  echo "  ──── 품질 기준 (매 턴 자동 검증) ────"
  echo "  파일 300줄 | 함수 20줄 | any 금지 | !. 금지 | silent catch 금지"
  echo "  Stop hook이 매 응답마다 L1 정적 감사를 자동 실행합니다."
  echo "  상세: shared-references/HIGH_QUALITY_CODE_STANDARDS.md"
fi

exit 0
