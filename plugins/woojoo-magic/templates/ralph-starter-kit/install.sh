#!/usr/bin/env bash
# Ralph v2 자가 설치 스크립트
# 사용법:
#   bash install.sh                        — 기본 (safe, 기존 파일 전부 보존)
#   bash install.sh --force-code           — Ralph 코드만 덮어쓰기 (PRD/tests/progress 보존) ⭐ 권장
#   bash install.sh --force                — 전체 덮어쓰기 (PRD/tests/progress 포함)
#   bash install.sh --force --no-backup    — 백업 없이 전체 덮어쓰기 (권장 안 함)
#   bash install.sh [TARGET_DIR]           — 대상 디렉토리 지정 (기본: 현재 디렉토리)
#
# 파일 카테고리:
#   CODE : ralph.sh, lib/, prompts/, schemas/ (플러그인 소스, 업그레이드 안전)
#   DATA : prd.md, tests.json, progress.md (사용자 작성 데이터, 업그레이드 위험)
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR=""
FORCE_CODE=0
FORCE_ALL=0
NO_BACKUP=0

# 인자 파싱
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-code) FORCE_CODE=1; shift ;;
    --force) FORCE_ALL=1; shift ;;
    --no-backup) NO_BACKUP=1; shift ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# //'
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

# --force는 --force-code를 함축 (전체 덮어쓰기는 코드도 포함)
if [[ "${FORCE_ALL}" == "1" ]]; then
  FORCE_CODE=1
fi

TARGET_DIR="${TARGET_DIR:-$PWD}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${BLUE}━━━ Ralph v2 설치 ━━━${NC}"
echo -e "  소스: ${SOURCE_DIR}"
echo -e "  대상: ${TARGET_DIR}"

if [[ "${FORCE_ALL}" == "1" ]]; then
  echo -e "  모드: ${YELLOW}--force (전체 덮어쓰기: 코드 + 데이터)${NC}"
elif [[ "${FORCE_CODE}" == "1" ]]; then
  echo -e "  모드: ${CYAN}--force-code (Ralph 코드만 덮어쓰기, 데이터 보존)${NC}"
else
  echo -e "  모드: safe (기존 파일 전부 보존)"
fi

if [[ "${FORCE_ALL}" == "1" || "${FORCE_CODE}" == "1" ]]; then
  if [[ "${NO_BACKUP}" == "0" ]]; then
    echo -e "  백업: 활성 (기존 파일을 .wj-backup-<timestamp>/로 이동)"
  else
    echo -e "  백업: ${RED}비활성 (복구 불가)${NC}"
  fi
fi
echo ""

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo -e "${RED}대상 디렉토리 없음: ${TARGET_DIR}${NC}"
  exit 1
fi

cd "${TARGET_DIR}"

# 백업 디렉토리 (force 모드에서만 사용)
BACKUP_DIR=""
if [[ ("${FORCE_ALL}" == "1" || "${FORCE_CODE}" == "1") && "${NO_BACKUP}" == "0" ]]; then
  TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR=".wj-backup-${TIMESTAMP}"
  mkdir -p "${BACKUP_DIR}"
fi

COPIED=0
SKIPPED=0
BACKED_UP=0

# 기존 파일 처리 (백업 or skip)
# category: "code" or "data"
handle_existing() {
  local dst="$1"
  local category="$2"

  if [[ ! -e "${dst}" ]]; then
    return 0  # 없음 → 바로 복사 가능
  fi

  # 이 카테고리가 덮어쓰기 대상인지 판단
  local should_overwrite=0
  if [[ "${category}" == "code" && ("${FORCE_CODE}" == "1" || "${FORCE_ALL}" == "1") ]]; then
    should_overwrite=1
  fi
  if [[ "${category}" == "data" && "${FORCE_ALL}" == "1" ]]; then
    should_overwrite=1
  fi

  if [[ "${should_overwrite}" == "0" ]]; then
    echo -e "  ${YELLOW}skip${NC}   ${dst} (이미 존재, ${category})"
    SKIPPED=$((SKIPPED + 1))
    return 1  # 복사 중단
  fi

  # 덮어쓰기 진행
  if [[ -n "${BACKUP_DIR}" ]]; then
    local backup_target="${BACKUP_DIR}/$(basename "${dst}")"
    mv "${dst}" "${backup_target}"
    echo -e "  ${CYAN}backup${NC} ${dst} → ${backup_target}"
    BACKED_UP=$((BACKED_UP + 1))
  else
    rm -rf "${dst}"
    echo -e "  ${RED}delete${NC} ${dst}"
  fi
  return 0
}

copy_code() {
  local src="$1"
  local dst="$2"
  if ! handle_existing "${dst}" "code"; then
    return
  fi
  cp -r "${src}" "${dst}"
  echo -e "  ${GREEN}copy${NC}   ${dst}"
  COPIED=$((COPIED + 1))
}

copy_data() {
  local src="$1"
  local dst="$2"
  if ! handle_existing "${dst}" "data"; then
    return
  fi
  cp "${src}" "${dst}"
  echo -e "  ${GREEN}copy${NC}   ${dst} (from template)"
  COPIED=$((COPIED + 1))
}

# === CODE: Ralph 실행 코드 ===
copy_code "${SOURCE_DIR}/ralph.sh" "./ralph.sh"
copy_code "${SOURCE_DIR}/lib" "./lib"
copy_code "${SOURCE_DIR}/prompts" "./prompts"
copy_code "${SOURCE_DIR}/schemas" "./schemas"

# === DATA: 사용자 작성 데이터 (기본 템플릿 제공) ===
[[ -f "${SOURCE_DIR}/templates/prd.template.md" ]]    && copy_data "${SOURCE_DIR}/templates/prd.template.md"    "./prd.md"
[[ -f "${SOURCE_DIR}/templates/tests.template.json" ]] && copy_data "${SOURCE_DIR}/templates/tests.template.json" "./tests.json"
[[ -f "${SOURCE_DIR}/templates/progress.template.md" ]] && copy_data "${SOURCE_DIR}/templates/progress.template.md" "./progress.md"

# .ralph-state 디렉토리 (항상 유지)
mkdir -p "./.ralph-state/logs"

# .gitignore 패치 — Ralph 런타임 산출물 차단 (stack.json은 커밋 대상)
ensure_gitignore_block() {
  local gi=".gitignore"
  [[ -f "$gi" ]] || touch "$gi"
  if ! grep -q "^# Ralph 런타임 상태$" "$gi" 2>/dev/null; then
    {
      echo ""
      echo "# Ralph 런타임 상태"
      echo ".ralph-state/"
      echo "!.ralph-state/stack.json"
    } >> "$gi"
    echo -e "  ${GREEN}patch${NC}  .gitignore (+ .ralph-state/ 제외, stack.json 유지)"
  fi
}
ensure_gitignore_block

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
