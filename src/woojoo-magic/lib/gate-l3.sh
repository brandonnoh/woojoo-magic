#!/usr/bin/env bash
# gate-l3.sh — L3 targeted test (5~30초)
# 인자: stdin으로 편집 파일 목록, $1=프로젝트 루트
# 출력: 실패 시 테스트 에러를 stdout에 출력하고 exit 1
set -euo pipefail

_root="${1:-$PWD}"
cd "$_root"

_files="$(cat || true)"
[[ -n "$_files" ]] || { echo "[L3] skip (파일 목록 없음)"; exit 0; }

# 편집 파일 → 테스트 파일 매핑
_test_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # 이미 테스트 파일이면 그대로
  case "$f" in
    *.test.*|*.spec.*|*__tests__*) _test_files="${_test_files}${f}"$'\n'; continue ;;
  esac
  # TS/JS가 아니면 skip
  case "$f" in
    *.ts|*.tsx|*.js|*.jsx) ;;
    *) continue ;;
  esac
  # 같은 디렉토리의 .test. 파일 탐색
  _dir=$(dirname "$f")
  _base=$(basename "$f" | sed 's/\.[^.]*$//')
  _ext=$(basename "$f" | sed 's/.*\.//')
  for _pattern in \
    "${_dir}/${_base}.test.${_ext}" \
    "${_dir}/${_base}.spec.${_ext}" \
    "${_dir}/__tests__/${_base}.test.${_ext}" \
    "${_dir}/__tests__/${_base}.spec.${_ext}"; do
    if [[ -f "$_pattern" ]]; then
      _test_files="${_test_files}${_pattern}"$'\n'
    fi
  done
done <<< "$_files"

_test_files="$(echo "$_test_files" | sort -u | sed '/^$/d')"
if [[ -z "$_test_files" ]]; then
  echo "[L3] skip (매칭되는 테스트 없음)"
  exit 0
fi

echo "[L3] 대상 테스트:"
echo "$_test_files" | sed 's/^/  - /'

# 테스트 러너 감지
_runner=""
if [[ -f "vitest.config.ts" || -f "vitest.config.js" || -f "vitest.config.mts" ]]; then
  _runner="vitest"
elif [[ -f "jest.config.ts" || -f "jest.config.js" || -f "jest.config.cjs" ]]; then
  _runner="jest"
elif jq -e '.devDependencies.vitest // .dependencies.vitest' package.json >/dev/null 2>&1; then
  _runner="vitest"
elif jq -e '.devDependencies.jest // .dependencies.jest' package.json >/dev/null 2>&1; then
  _runner="jest"
else
  echo "[L3] skip (테스트 러너 감지 실패)"
  exit 0
fi

# 파일 목록을 인자로 전달
_file_args=$(echo "$_test_files" | tr '\n' ' ')

_log=$(mktemp)
case "$_runner" in
  vitest)
    echo "[L3] vitest run ${_file_args}"
    if npx vitest run $_file_args --reporter=verbose > "$_log" 2>&1; then
      echo "[L3] OK"
      rm -f "$_log"
      exit 0
    fi
    ;;
  jest)
    echo "[L3] jest ${_file_args}"
    if npx jest $_file_args --verbose > "$_log" 2>&1; then
      echo "[L3] OK"
      rm -f "$_log"
      exit 0
    fi
    ;;
esac

echo "[L3] 테스트 실패 (마지막 20줄):"
tail -20 "$_log"
rm -f "$_log"
exit 1
