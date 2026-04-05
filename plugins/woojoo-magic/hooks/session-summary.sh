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

# tests.json 진행률
if [[ -f tests.json ]] && command -v jq >/dev/null 2>&1; then
  TOTAL="$(jq '[.tasks[]?] | length' tests.json 2>/dev/null || echo 0)"
  DONE="$(jq '[.tasks[]? | select(.status=="done")] | length' tests.json 2>/dev/null || echo 0)"
  if [[ "${TOTAL}" != "0" ]]; then
    echo "  tests.json: ${DONE}/${TOTAL} 완료"
  fi
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

# any / !. 카운트 (간이)
if command -v grep >/dev/null 2>&1; then
  ANY=$(grep -rIn --include='*.ts' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
    -E ': any\b|<any>|as any\b' . 2>/dev/null | wc -l | tr -d ' ')
  BANG=$(grep -rIn --include='*.ts' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
    -E '!\.' . 2>/dev/null | wc -l | tr -d ' ')
  echo "  any 사용: ${ANY}곳 / !. 사용: ${BANG}곳"
fi
