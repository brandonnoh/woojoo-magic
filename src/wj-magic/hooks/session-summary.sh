#!/usr/bin/env bash
# woojoo-magic: 세션 시작 프로젝트 상태 요약
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
echo "  ──── MCP 필수 도구 (코드 분석·탐색·수정 시 강제) ────"
echo "  [필수] Serena MCP — 심볼 추적(find_symbol, find_referencing_symbols, find_declaration, find_implementations, get_symbols_overview)"
echo "  [필수] Context7 MCP — 외부 라이브러리 API 문서 조회(resolve-library-id → query-docs)"
echo "  [금지] 추측으로 파일명·함수명 지목 — Serena/Grep 증거 필수"
echo "  코드 수정 전 Serena로 참조 관계를 반드시 확인. 추측 기반 수정은 2차 버그를 만듭니다."
echo ""
echo "[woojoo-magic] 세션 시작 요약"
echo "  브랜치: ${_branch}"
if [[ -n "${_recent}" ]]; then
  echo "  최근 커밋:"
  echo "${_recent}"
fi

# 300줄 초과 파일
if command -v find >/dev/null 2>&1; then
  _over=0
  while IFS= read -r f; do
    _lines=$(wc -l < "${f}" 2>/dev/null || echo 0)
    if [[ "${_lines}" -gt 300 ]]; then
      _over=$((_over + 1))
    fi
  done < <(find . \
      -type d \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .next -o -name coverage \) -prune \
      -o -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) -print 2>/dev/null)
  echo "  300줄 초과 파일: ${_over}개"
fi

# any / !. 카운트 (간이) — grep 매치 0 시 exit 1 나므로 || true 필수
if command -v grep >/dev/null 2>&1; then
  _any=$( { grep -rIn --include='*.ts' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
    -E ': any\b|<any>|as any\b' . 2>/dev/null || true; } | wc -l | tr -d ' ')
  _bang=$( { grep -rIn --include='*.ts' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
    -E '[A-Za-z0-9_)\]]!\.' . 2>/dev/null || true; } | wc -l | tr -d ' ')
  echo "  any 사용: ${_any}곳 / !. 사용: ${_bang}곳"
fi

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
