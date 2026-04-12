#!/usr/bin/env bash
# woojoo-magic v3: 세션 시작 부트스트랩
# - 프로젝트에 파일을 복사하지 않음
# - .gitignore, .mcp.json을 수정하지 않음
# - 자동 git commit을 하지 않음
#
# 비활성화: WOOJOO_MAGIC_SKIP_BOOTSTRAP=1
set -euo pipefail

if [[ "${WOOJOO_MAGIC_SKIP_BOOTSTRAP:-0}" == "1" ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# .dev/state/ 디렉토리 보장 (Stop hook loop에 필요)
if [[ -d "${PROJECT_ROOT}/.dev" ]]; then
  mkdir -p "${PROJECT_ROOT}/.dev/state"
  mkdir -p "${PROJECT_ROOT}/.dev/journal"
fi

exit 0
