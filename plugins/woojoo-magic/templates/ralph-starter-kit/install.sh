#!/usr/bin/env bash
# Ralph v2 자가 설치 스크립트
# 사용법: bash "${CLAUDE_PLUGIN_ROOT}/templates/ralph-starter-kit/install.sh" [TARGET_DIR]
#
# TARGET_DIR 기본값: 현재 디렉토리
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-$PWD}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}━━━ Ralph v2 설치 ━━━${NC}"
echo -e "  소스: ${SOURCE_DIR}"
echo -e "  대상: ${TARGET_DIR}"
echo ""

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo -e "${RED}대상 디렉토리 없음: ${TARGET_DIR}${NC}"
  exit 1
fi

cd "${TARGET_DIR}"

# 복사 대상 (기존 파일이 있으면 스킵)
COPIED=0
SKIPPED=0

copy_if_missing() {
  local src="$1"
  local dst="$2"
  if [[ -e "${dst}" ]]; then
    echo -e "  ${YELLOW}skip${NC}  ${dst} (이미 존재)"
    SKIPPED=$((SKIPPED + 1))
  else
    cp -r "${src}" "${dst}"
    echo -e "  ${GREEN}copy${NC}  ${dst}"
    COPIED=$((COPIED + 1))
  fi
}

# 핵심 파일/디렉토리
copy_if_missing "${SOURCE_DIR}/ralph.sh" "./ralph.sh"
copy_if_missing "${SOURCE_DIR}/lib" "./lib"
copy_if_missing "${SOURCE_DIR}/prompts" "./prompts"
copy_if_missing "${SOURCE_DIR}/schemas" "./schemas"

# 템플릿 → 실제 파일명으로
if [[ ! -f "./prd.md" ]] && [[ -f "${SOURCE_DIR}/templates/prd.template.md" ]]; then
  cp "${SOURCE_DIR}/templates/prd.template.md" "./prd.md"
  echo -e "  ${GREEN}copy${NC}  ./prd.md (from template)"
  COPIED=$((COPIED + 1))
fi

if [[ ! -f "./tests.json" ]] && [[ -f "${SOURCE_DIR}/templates/tests.template.json" ]]; then
  cp "${SOURCE_DIR}/templates/tests.template.json" "./tests.json"
  echo -e "  ${GREEN}copy${NC}  ./tests.json (from template)"
  COPIED=$((COPIED + 1))
fi

if [[ ! -f "./progress.md" ]] && [[ -f "${SOURCE_DIR}/templates/progress.template.md" ]]; then
  cp "${SOURCE_DIR}/templates/progress.template.md" "./progress.md"
  echo -e "  ${GREEN}copy${NC}  ./progress.md (from template)"
  COPIED=$((COPIED + 1))
fi

# .ralph-state 디렉토리
mkdir -p "./.ralph-state/logs"

# 실행 권한 부여
chmod +x ./ralph.sh 2>/dev/null || true
find ./lib -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# 스택 감지 실행
if [[ -x "./lib/detect-stack.sh" ]]; then
  ./lib/detect-stack.sh > ./.ralph-state/stack.json 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}━━━ 설치 완료 ━━━${NC}"
echo -e "  복사: ${COPIED}개 / 스킵: ${SKIPPED}개"
echo ""
echo -e "  다음 단계:"
echo -e "  1. ${BLUE}prd.md${NC} 편집 → 개발할 태스크 작성"
echo -e "  2. ${BLUE}tests.json${NC}에 태스크 추가 (acceptance_criteria, depends_on 포함)"
echo -e "  3. ${BLUE}bash ralph.sh --dry-run${NC} 으로 파이프라인 미리보기"
echo -e "  4. ${BLUE}bash ralph.sh --iter 10${NC} 으로 자율 루프 시작"
