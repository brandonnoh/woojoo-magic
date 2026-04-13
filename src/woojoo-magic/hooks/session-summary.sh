#!/usr/bin/env bash
# woojoo-magic: 세션 시작 프로젝트 상태 요약
set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "${PROJECT_ROOT}" || exit 0

if [[ ! -d .git ]]; then
  exit 0
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
RECENT="$(git log -3 --pretty=format:'  - %h %s' 2>/dev/null || true)"

echo "[woojoo-magic] 세션 시작 요약"
echo "  브랜치: ${BRANCH}"
if [[ -n "${RECENT}" ]]; then
  echo "  최근 커밋:"
  echo "${RECENT}"
fi

# 300줄 초과 파일
if command -v find >/dev/null 2>&1; then
  OVER=0
  while IFS= read -r f; do
    LINES=$(wc -l < "${f}" 2>/dev/null || echo 0)
    if [[ "${LINES}" -gt 300 ]]; then
      OVER=$((OVER + 1))
    fi
  done < <(find . \
      -type d \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .next -o -name coverage \) -prune \
      -o -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) -print 2>/dev/null)
  echo "  300줄 초과 파일: ${OVER}개"
fi

# any / !. 카운트 (간이) — grep 매치 0 시 exit 1 나므로 || true 필수
if command -v grep >/dev/null 2>&1; then
  ANY=$( { grep -rIn --include='*.ts' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
    -E ': any\b|<any>|as any\b' . 2>/dev/null || true; } | wc -l | tr -d ' ')
  BANG=$( { grep -rIn --include='*.ts' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
    -E '!\.' . 2>/dev/null || true; } | wc -l | tr -d ' ')
  echo "  any 사용: ${ANY}곳 / !. 사용: ${BANG}곳"
fi

# .dev/tasks.json 진행률
if [[ -f "${PROJECT_ROOT}/.dev/tasks.json" ]] && command -v jq >/dev/null 2>&1; then
  _total=$(jq '[.features[]?] | length' "${PROJECT_ROOT}/.dev/tasks.json" 2>/dev/null || echo 0)
  _done=$(jq '[.features[]? | select(.status=="done")] | length' "${PROJECT_ROOT}/.dev/tasks.json" 2>/dev/null || echo 0)
  if [[ "${_total}" != "0" ]]; then
    echo "  tasks: ${_done}/${_total} 완료"
    _current=$(jq -r '[.features[]? | select(.status!="done")][0].id // empty' "${PROJECT_ROOT}/.dev/tasks.json" 2>/dev/null || true)
    if [[ -n "${_current}" ]]; then
      echo "  다음 task: ${_current}"
    fi
  fi
fi

# 핵심 규칙 리마인더 (개발 작업 시 자동 참조)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -n "${PLUGIN_ROOT}" ]]; then
  echo "  ──── 품질 기준 (매 턴 자동 검증) ────"
  echo "  파일 300줄 | 함수 20줄 | any 금지 | !. 금지 | silent catch 금지"
  echo "  Stop hook이 매 응답마다 L1 정적 감사를 자동 실행합니다."
  echo "  상세: shared-references/HIGH_QUALITY_CODE_STANDARDS.md"
fi

exit 0
