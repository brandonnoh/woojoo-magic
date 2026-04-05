#!/usr/bin/env bash
# Ralph v2 자가 설치 스크립트
# 사용법:
#   bash install.sh                        — 기본 (기존 파일 보존, 스킵)
#   bash install.sh --force                — 강제 재설치 (기존 파일을 .wj-backup-<timestamp>/로 백업 후 덮어쓰기)
#   bash install.sh --force --no-backup    — 백업 없이 덮어쓰기 (권장 안 함)
#   bash install.sh [TARGET_DIR]           — 대상 디렉토리 지정 (기본: 현재 디렉토리)
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR=""
FORCE=0
NO_BACKUP=0

# 인자 파싱
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --no-backup) NO_BACKUP=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *)
      if [[ -z "${TARGET_DIR}" ]]; then
        TARGET_DIR="$1"
      fi
      shift
      ;;
  esac
done

TARGET_DIR="${TARGET_DIR:-$PWD}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${BLUE}━━━ Ralph v2 설치 ━━━${NC}"
echo -e "  소스: ${SOURCE_DIR}"
echo -e "  대상: ${TARGET_DIR}"
if [[ "${FORCE}" == "1" ]]; then
  echo -e "  모드: ${YELLOW}--force (덮어쓰기)${NC}"
  if [[ "${NO_BACKUP}" == "0" ]]; then
    echo -e "  백업: 활성 (기존 파일을 .wj-backup-<timestamp>/로 이동)"
  else
    echo -e "  백업: ${RED}비활성 (복구 불가)${NC}"
  fi
else
  echo -e "  모드: safe (기존 파일 보존)"
fi
echo ""

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo -e "${RED}대상 디렉토리 없음: ${TARGET_DIR}${NC}"
  exit 1
fi

cd "${TARGET_DIR}"

# 백업 디렉토리 (force 모드에서만 사용)
BACKUP_DIR=""
if [[ "${FORCE}" == "1" && "${NO_BACKUP}" == "0" ]]; then
  TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR=".wj-backup-${TIMESTAMP}"
  mkdir -p "${BACKUP_DIR}"
fi

COPIED=0
SKIPPED=0
BACKED_UP=0

# 기존 파일 처리 (백업 또는 skip)
handle_existing() {
  local dst="$1"
  if [[ ! -e "${dst}" ]]; then
    return 0  # 없음 → 바로 복사 가능
  fi

  if [[ "${FORCE}" == "0" ]]; then
    echo -e "  ${YELLOW}skip${NC}  ${dst} (이미 존재)"
    SKIPPED=$((SKIPPED + 1))
    return 1  # 복사 중단
  fi

  # force 모드
  if [[ -n "${BACKUP_DIR}" ]]; then
    local backup_target="${BACKUP_DIR}/$(basename "${dst}")"
    mv "${dst}" "${backup_target}"
    echo -e "  ${CYAN}backup${NC} ${dst} → ${backup_target}"
    BACKED_UP=$((BACKED_UP + 1))
  else
    rm -rf "${dst}"
    echo -e "  ${RED}delete${NC} ${dst}"
  fi
  return 0  # 복사 진행
}

copy_item() {
  local src="$1"
  local dst="$2"
  if ! handle_existing "${dst}"; then
    return
  fi
  cp -r "${src}" "${dst}"
  echo -e "  ${GREEN}copy${NC}   ${dst}"
  COPIED=$((COPIED + 1))
}

# 핵심 파일/디렉토리
copy_item "${SOURCE_DIR}/ralph.sh" "./ralph.sh"
copy_item "${SOURCE_DIR}/lib" "./lib"
copy_item "${SOURCE_DIR}/prompts" "./prompts"
copy_item "${SOURCE_DIR}/schemas" "./schemas"

# 템플릿 → 실제 파일명으로
if [[ -f "${SOURCE_DIR}/templates/prd.template.md" ]]; then
  copy_item_template() {
    local src="$1"
    local dst="$2"
    if ! handle_existing "${dst}"; then
      return
    fi
    cp "${src}" "${dst}"
    echo -e "  ${GREEN}copy${NC}   ${dst} (from template)"
    COPIED=$((COPIED + 1))
  }
  copy_item_template "${SOURCE_DIR}/templates/prd.template.md" "./prd.md"
fi

if [[ -f "${SOURCE_DIR}/templates/tests.template.json" ]]; then
  if handle_existing "./tests.json"; then
    cp "${SOURCE_DIR}/templates/tests.template.json" "./tests.json"
    echo -e "  ${GREEN}copy${NC}   ./tests.json (from template)"
    COPIED=$((COPIED + 1))
  fi
fi

if [[ -f "${SOURCE_DIR}/templates/progress.template.md" ]]; then
  if handle_existing "./progress.md"; then
    cp "${SOURCE_DIR}/templates/progress.template.md" "./progress.md"
    echo -e "  ${GREEN}copy${NC}   ./progress.md (from template)"
    COPIED=$((COPIED + 1))
  fi
fi

# .ralph-state 디렉토리 (항상 유지)
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
if [[ "${BACKED_UP}" -gt 0 ]]; then
  echo -e "  백업: ${BACKED_UP}개 → ${BACKUP_DIR}/"
fi
echo ""
echo -e "  다음 단계:"
echo -e "  1. ${BLUE}prd.md${NC} 편집 → 개발할 태스크 작성"
echo -e "  2. ${BLUE}tests.json${NC}에 태스크 추가 (acceptance_criteria, depends_on 포함)"
echo -e "  3. ${BLUE}bash ralph.sh --dry-run${NC} 으로 파이프라인 미리보기"
echo -e "  4. ${BLUE}bash ralph.sh --iter 10${NC} 으로 자율 루프 시작"
