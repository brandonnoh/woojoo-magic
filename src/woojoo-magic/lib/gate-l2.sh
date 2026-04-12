#!/usr/bin/env bash
# gate-l2.sh — L2 tsc 증분 타입체크 (2~10초)
# 인자: $1=프로젝트 루트 (기본: $PWD)
# 출력: 실패 시 타입 에러를 stdout에 출력하고 exit 1
set -euo pipefail

_root="${1:-$PWD}"
cd "$_root"

# TS 프로젝트가 아니면 skip
if [[ ! -f "tsconfig.json" && ! -f "tsconfig.app.json" ]]; then
  echo "[L2] skip (tsconfig 없음)"
  exit 0
fi

_tsconfig="tsconfig.json"
[[ -f "$_tsconfig" ]] || _tsconfig="tsconfig.app.json"

# tsc 바이너리 탐색
_tsc=""
if [[ -x "node_modules/.bin/tsc" ]]; then
  _tsc="node_modules/.bin/tsc"
elif command -v npx >/dev/null 2>&1; then
  _tsc="npx tsc"
else
  echo "[L2] skip (tsc 바이너리 없음)"
  exit 0
fi

# turbo monorepo → pnpm turbo typecheck 시도
if [[ -f "turbo.json" ]] && command -v pnpm >/dev/null 2>&1; then
  _typecheck_script=$(jq -r '.scripts.typecheck // empty' package.json 2>/dev/null || true)
  if [[ -n "$_typecheck_script" ]]; then
    echo "[L2] turbo typecheck 실행"
    _log=$(mktemp)
    if pnpm turbo typecheck --cache-dir=.dev/state/.turbo > "$_log" 2>&1; then
      echo "[L2] OK (turbo)"
      rm -f "$_log"
      exit 0
    else
      echo "[L2] 타입 에러 (마지막 20줄):"
      tail -20 "$_log"
      rm -f "$_log"
      exit 1
    fi
  fi
fi

# 단일 프로젝트: tsc --noEmit --incremental
mkdir -p .dev/state

echo "[L2] tsc --noEmit 실행"
_log=$(mktemp)
if $_tsc --noEmit -p "$_tsconfig" \
    --incremental --tsBuildInfoFile .dev/state/tsbuildinfo > "$_log" 2>&1; then
  echo "[L2] OK"
  rm -f "$_log"
  exit 0
else
  echo "[L2] 타입 에러 (마지막 20줄):"
  tail -20 "$_log"
  rm -f "$_log"
  exit 1
fi
