#!/usr/bin/env bash
# Ralph v2 자가 설치 스크립트
# 사용법:
#   bash install.sh                        — CODE 항상 최신화, DATA 없을 때만 생성
#   bash install.sh --force                — CODE 최신화 + DATA 백업 후 덮어쓰기
#   bash install.sh --force --no-backup    — 백업 없이 전체 덮어쓰기 (권장 안 함)
#   bash install.sh [TARGET_DIR]           — 대상 디렉토리 지정 (기본: 현재 디렉토리)
#
# 파일 카테고리:
#   CODE : ralph.sh, lib/, prompts/, schemas/ → 항상 최신 덮어쓰기 (플러그인 소스)
#   DATA : prd.md, tests.json, progress.md, smoke-test.sh → 사용자 데이터, 보존 우선
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR=""
FORCE_ALL=0
NO_BACKUP=0

# 인자 파싱
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-code) shift ;; # 하위 호환 — 이제 기본 동작이므로 무시
    --force) FORCE_ALL=1; shift ;;
    --no-backup) NO_BACKUP=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# //'
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

if [[ "${FORCE_ALL}" == "1" ]]; then
  echo -e "  모드: ${YELLOW}--force (코드 최신화 + 데이터 덮어쓰기)${NC}"
else
  echo -e "  모드: 기본 (코드 최신화, 데이터 보존)"
fi
echo ""

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo -e "${RED}대상 디렉토리 없음: ${TARGET_DIR}${NC}"
  exit 1
fi

cd "${TARGET_DIR}"

# 백업 디렉토리 (기존 CODE 백업 + force 모드 DATA 백업)
BACKUP_DIR=""
if [[ "${NO_BACKUP}" == "0" ]]; then
  TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR=".wj-backup-${TIMESTAMP}"
fi

COPIED=0
SKIPPED=0
BACKED_UP=0

# 기존 파일을 백업 후 덮어쓰기
backup_and_copy() {
  local src="$1"
  local dst="$2"

  if [[ -e "${dst}" && -n "${BACKUP_DIR}" ]]; then
    mkdir -p "${BACKUP_DIR}"
    local backup_target="${BACKUP_DIR}/$(basename "${dst}")"
    cp -r "${dst}" "${backup_target}"
    echo -e "  ${CYAN}backup${NC} ${dst} → ${backup_target}"
    BACKED_UP=$((BACKED_UP + 1))
  fi

  rm -rf "${dst}"
  cp -r "${src}" "${dst}"
  echo -e "  ${GREEN}update${NC} ${dst}"
  COPIED=$((COPIED + 1))
}

# 없을 때만 생성
copy_if_missing() {
  local src="$1"
  local dst="$2"

  if [[ -e "${dst}" ]]; then
    echo -e "  ${YELLOW}keep${NC}   ${dst} (이미 존재)"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  cp "${src}" "${dst}"
  echo -e "  ${GREEN}create${NC} ${dst}"
  COPIED=$((COPIED + 1))
}

# 백업 후 덮어쓰기 (--force 모드)
force_copy() {
  local src="$1"
  local dst="$2"

  if [[ -e "${dst}" && -n "${BACKUP_DIR}" ]]; then
    mkdir -p "${BACKUP_DIR}"
    local backup_target="${BACKUP_DIR}/$(basename "${dst}")"
    cp -r "${dst}" "${backup_target}"
    echo -e "  ${CYAN}backup${NC} ${dst} → ${backup_target}"
    BACKED_UP=$((BACKED_UP + 1))
  fi

  rm -f "${dst}"
  cp "${src}" "${dst}"
  echo -e "  ${GREEN}update${NC} ${dst}"
  COPIED=$((COPIED + 1))
}

# === CODE: 항상 최신화 ===
echo -e "${BOLD:-}[CODE] 플러그인 소스 최신화${NC}"
backup_and_copy "${SOURCE_DIR}/ralph.sh" "./ralph.sh"
backup_and_copy "${SOURCE_DIR}/lib" "./lib"
backup_and_copy "${SOURCE_DIR}/prompts" "./prompts"
backup_and_copy "${SOURCE_DIR}/schemas" "./schemas"

# === DATA: 사용자 데이터 (보존 우선) ===
echo -e "${BOLD:-}[DATA] 사용자 데이터${NC}"
if [[ "${FORCE_ALL}" == "1" ]]; then
  [[ -f "${SOURCE_DIR}/templates/prd.template.md" ]]         && force_copy "${SOURCE_DIR}/templates/prd.template.md"    "./prd.md"
  [[ -f "${SOURCE_DIR}/templates/tests.template.json" ]]     && force_copy "${SOURCE_DIR}/templates/tests.template.json" "./tests.json"
  [[ -f "${SOURCE_DIR}/templates/progress.template.md" ]]    && force_copy "${SOURCE_DIR}/templates/progress.template.md" "./progress.md"
  [[ -f "${SOURCE_DIR}/templates/smoke-test.template.sh" ]]  && force_copy "${SOURCE_DIR}/templates/smoke-test.template.sh" "./smoke-test.sh"
else
  [[ -f "${SOURCE_DIR}/templates/prd.template.md" ]]         && copy_if_missing "${SOURCE_DIR}/templates/prd.template.md"    "./prd.md"
  [[ -f "${SOURCE_DIR}/templates/tests.template.json" ]]     && copy_if_missing "${SOURCE_DIR}/templates/tests.template.json" "./tests.json"
  [[ -f "${SOURCE_DIR}/templates/progress.template.md" ]]    && copy_if_missing "${SOURCE_DIR}/templates/progress.template.md" "./progress.md"
  [[ -f "${SOURCE_DIR}/templates/smoke-test.template.sh" ]]  && copy_if_missing "${SOURCE_DIR}/templates/smoke-test.template.sh" "./smoke-test.sh"
fi

# .ralph-state 디렉토리 (항상 유지)
mkdir -p "./.ralph-state/logs"

# .gitignore 패치
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
    echo -e "  ${GREEN}patch${NC}  .gitignore (+ .ralph-state/ 제외)"
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
echo -e "  최신화: ${COPIED}개 / 보존: ${SKIPPED}개"
if [[ "${BACKED_UP}" -gt 0 ]]; then
  echo -e "  백업: ${BACKED_UP}개 → ${BACKUP_DIR}/"
fi
echo ""
echo -e "  다음: Claude가 누락 문서(specs/, smoke-test.sh)를 자동 생성합니다."
