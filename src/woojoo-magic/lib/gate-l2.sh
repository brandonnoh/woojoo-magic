#!/usr/bin/env bash
# gate-l2.sh — L2 다국어 타입체크 (TS/Python/Go/Rust/Swift/Kotlin)
# 인자: $1=프로젝트 루트 (기본: $PWD)
# 출력: 감지된 언어별 타입체크 실행, 하나라도 실패 시 exit 1
set -euo pipefail

_root="${1:-$PWD}"
cd "$_root"

# 멀티 언어 결과 추적
_fail=0
_detected=0

# ──────────────────────────────────────
# TypeScript
# ──────────────────────────────────────
if [[ -f "tsconfig.json" || -f "tsconfig.app.json" ]]; then
  _detected=$((_detected + 1))
  _tsconfig="tsconfig.json"
  [[ -f "$_tsconfig" ]] || _tsconfig="tsconfig.app.json"

  # tsc 바이너리 탐색
  _tsc=""
  if [[ -x "node_modules/.bin/tsc" ]]; then
    _tsc="node_modules/.bin/tsc"
  elif command -v npx >/dev/null 2>&1; then
    _tsc="npx tsc"
  fi

  if [[ -z "$_tsc" ]]; then
    echo "[L2] skip (TypeScript 미설치)"
  else
    # turbo monorepo → pnpm turbo typecheck 시도
    _ts_done=0
    if [[ -f "turbo.json" ]] && command -v pnpm >/dev/null 2>&1; then
      _typecheck_script=$(jq -r '.scripts.typecheck // empty' package.json 2>/dev/null || true)
      if [[ -n "$_typecheck_script" ]]; then
        echo "[L2] TypeScript pnpm turbo typecheck 실행"
        _log=$(mktemp)
        if pnpm turbo typecheck --cache-dir=.dev/state/.turbo > "$_log" 2>&1; then
          echo "[L2] OK (TypeScript)"
        else
          echo "[L2] 타입 에러 — TypeScript (마지막 20줄):"
          tail -20 "$_log"
          _fail=1
        fi
        rm -f "$_log"
        _ts_done=1
      fi
    fi

    # turbo 미사용 시 단일 tsc
    if [[ "$_ts_done" -eq 0 ]]; then
      mkdir -p .dev/state
      echo "[L2] TypeScript tsc --noEmit 실행"
      _log=$(mktemp)
      if $_tsc --noEmit -p "$_tsconfig" \
          --incremental --tsBuildInfoFile .dev/state/tsbuildinfo > "$_log" 2>&1; then
        echo "[L2] OK (TypeScript)"
      else
        echo "[L2] 타입 에러 — TypeScript (마지막 20줄):"
        tail -20 "$_log"
        _fail=1
      fi
      rm -f "$_log"
    fi
  fi
fi

# ──────────────────────────────────────
# Python
# ──────────────────────────────────────
if [[ -f "pyproject.toml" || -f "setup.py" || -f "requirements.txt" ]]; then
  _detected=$((_detected + 1))

  if command -v pyright >/dev/null 2>&1; then
    echo "[L2] Python pyright 실행"
    _log=$(mktemp)
    if pyright . > "$_log" 2>&1; then
      echo "[L2] OK (Python)"
    else
      echo "[L2] 타입 에러 — Python (마지막 20줄):"
      tail -20 "$_log"
      _fail=1
    fi
    rm -f "$_log"
  else
    echo "[L2] skip (Python 미설치)"
  fi
fi

# ──────────────────────────────────────
# Go
# ──────────────────────────────────────
if [[ -f "go.mod" ]]; then
  _detected=$((_detected + 1))

  if command -v go >/dev/null 2>&1; then
    echo "[L2] Go go build ./... 실행"
    _log=$(mktemp)
    if go build ./... > "$_log" 2>&1; then
      echo "[L2] OK (Go)"
    else
      echo "[L2] 타입 에러 — Go (마지막 20줄):"
      tail -20 "$_log"
      _fail=1
    fi
    rm -f "$_log"
  else
    echo "[L2] skip (Go 미설치)"
  fi
fi

# ──────────────────────────────────────
# Rust
# ──────────────────────────────────────
if [[ -f "Cargo.toml" ]]; then
  _detected=$((_detected + 1))

  if command -v cargo >/dev/null 2>&1; then
    echo "[L2] Rust cargo check 실행"
    _log=$(mktemp)
    if cargo check > "$_log" 2>&1; then
      echo "[L2] OK (Rust)"
    else
      echo "[L2] 타입 에러 — Rust (마지막 20줄):"
      tail -20 "$_log"
      _fail=1
    fi
    rm -f "$_log"
  else
    echo "[L2] skip (Rust 미설치)"
  fi
fi

# ──────────────────────────────────────
# Swift
# ──────────────────────────────────────
_swift_detected=0
if [[ -f "Package.swift" ]]; then
  _swift_detected=1
else
  # *.xcodeproj 디렉토리 존재 여부
  for _d in *.xcodeproj; do
    [[ -d "$_d" ]] && _swift_detected=1 && break
  done 2>/dev/null || true
fi

if [[ "$_swift_detected" -eq 1 ]]; then
  _detected=$((_detected + 1))

  if command -v swift >/dev/null 2>&1; then
    echo "[L2] Swift swift build 실행"
    _log=$(mktemp)
    if swift build > "$_log" 2>&1; then
      echo "[L2] OK (Swift)"
    else
      echo "[L2] 타입 에러 — Swift (마지막 20줄):"
      tail -20 "$_log"
      _fail=1
    fi
    rm -f "$_log"
  else
    echo "[L2] skip (Swift 미설치)"
  fi
fi

# ──────────────────────────────────────
# Kotlin
# ──────────────────────────────────────
if [[ -f "build.gradle.kts" || -f "build.gradle" ]]; then
  _detected=$((_detected + 1))

  if [[ -x "./gradlew" ]]; then
    echo "[L2] Kotlin ./gradlew compileKotlin 실행"
    _log=$(mktemp)
    if ./gradlew compileKotlin > "$_log" 2>&1; then
      echo "[L2] OK (Kotlin)"
    else
      echo "[L2] 타입 에러 — Kotlin (마지막 20줄):"
      tail -20 "$_log"
      _fail=1
    fi
    rm -f "$_log"
  elif command -v gradle >/dev/null 2>&1; then
    echo "[L2] Kotlin gradle compileKotlin 실행"
    _log=$(mktemp)
    if gradle compileKotlin > "$_log" 2>&1; then
      echo "[L2] OK (Kotlin)"
    else
      echo "[L2] 타입 에러 — Kotlin (마지막 20줄):"
      tail -20 "$_log"
      _fail=1
    fi
    rm -f "$_log"
  else
    echo "[L2] skip (Kotlin 미설치)"
  fi
fi

# ──────────────────────────────────────
# 최종 결과
# ──────────────────────────────────────
if [[ "$_detected" -eq 0 ]]; then
  echo "[L2] skip (지원 언어 미감지)"
  exit 0
fi

if [[ "$_fail" -ne 0 ]]; then
  exit 1
fi

exit 0
