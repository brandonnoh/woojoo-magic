# c1-l2-multilang: gate-l2.sh 다국어 타입체크 확장

> 상태: SPEC | 우선순위: CRITICAL
> 대상 파일: `src/woojoo-magic/lib/gate-l2.sh`
> 참조: `src/woojoo-magic/references/INDEX.md` (빌드/검증 명령 매핑 테이블)

---

## 1. 현재 코드 구조 (gate-l2.sh)

파일 경로: `src/woojoo-magic/lib/gate-l2.sh`
총 줄 수: 65줄

### 줄 번호별 플로우 (1-indexed)

| 줄 | 내용 | 역할 |
|----|------|------|
| 1 | `#!/usr/bin/env bash` | shebang |
| 2 | `# gate-l2.sh — L2 tsc 증분 타입체크 (2~10초)` | 주석 (변경 필요) |
| 3 | `# 인자: $1=프로젝트 루트 (기본: $PWD)` | 주석 |
| 4 | `# 출력: 실패 시 타입 에러를 stdout에 출력하고 exit 1` | 주석 (변경 필요) |
| 5 | `set -euo pipefail` | 에러 핸들링 |
| 6 | (빈 줄) | |
| 7 | `_root="${1:-$PWD}"` | 프로젝트 루트 설정 |
| 8 | `cd "$_root"` | 루트로 이동 |
| 9 | (빈 줄) | |
| 10 | `# TS 프로젝트가 아니면 skip` | 주석 |
| 11 | `if [[ ! -f "tsconfig.json" && ! -f "tsconfig.app.json" ]]; then` | TS 감지 조건 |
| 12 | `  echo "[L2] skip (tsconfig 없음)"` | skip 로그 |
| 13 | `  exit 0` | **문제: 여기서 즉시 종료 → 다른 언어 검사 불가** |
| 14 | `fi` | |
| 15 | (빈 줄) | |
| 16 | `_tsconfig="tsconfig.json"` | tsconfig 파일 선택 |
| 17 | `[[ -f "$_tsconfig" ]] \|\| _tsconfig="tsconfig.app.json"` | fallback |
| 18 | (빈 줄) | |
| 19 | `# tsc 바이너리 탐색` | 주석 |
| 20 | `_tsc=""` | 변수 초기화 |
| 21 | `if [[ -x "node_modules/.bin/tsc" ]]; then` | 로컬 tsc 탐색 |
| 22 | `  _tsc="node_modules/.bin/tsc"` | |
| 23 | `elif command -v npx >/dev/null 2>&1; then` | npx fallback |
| 24 | `  _tsc="npx tsc"` | |
| 25 | `else` | |
| 26 | `  echo "[L2] skip (tsc 바이너리 없음)"` | skip 로그 |
| 27 | `  exit 0` | 즉시 종료 |
| 28 | `fi` | |
| 29 | (빈 줄) | |
| 30 | `# turbo monorepo → pnpm turbo typecheck 시도` | 주석 |
| 31 | `if [[ -f "turbo.json" ]] && command -v pnpm >/dev/null 2>&1; then` | turbo 감지 |
| 32 | `  _typecheck_script=$(jq -r '.scripts.typecheck // empty' package.json 2>/dev/null \|\| true)` | typecheck 스크립트 확인 |
| 33 | `  if [[ -n "$_typecheck_script" ]]; then` | |
| 34 | `    echo "[L2] turbo typecheck 실행"` | 실행 로그 |
| 35 | `    _log=$(mktemp)` | 임시 파일 |
| 36 | `    if pnpm turbo typecheck --cache-dir=.dev/state/.turbo > "$_log" 2>&1; then` | turbo 실행 |
| 37 | `      echo "[L2] OK (turbo)"` | 성공 로그 |
| 38 | `      rm -f "$_log"` | 정리 |
| 39 | `      exit 0` | 즉시 종료 |
| 40 | `    else` | |
| 41 | `      echo "[L2] 타입 에러 (마지막 20줄):"` | 실패 로그 |
| 42 | `      tail -20 "$_log"` | 에러 출력 |
| 43 | `      rm -f "$_log"` | 정리 |
| 44 | `      exit 1` | 즉시 종료 |
| 45 | `    fi` | |
| 46 | `  fi` | |
| 47 | `fi` | |
| 48 | (빈 줄) | |
| 49 | `# 단일 프로젝트: tsc --noEmit --incremental` | 주석 |
| 50 | `mkdir -p .dev/state` | state 디렉토리 생성 |
| 51 | (빈 줄) | |
| 52 | `echo "[L2] tsc --noEmit 실행"` | 실행 로그 |
| 53 | `_log=$(mktemp)` | 임시 파일 |
| 54 | `if $_tsc --noEmit -p "$_tsconfig" \` | tsc 실행 |
| 55 | `    --incremental --tsBuildInfoFile .dev/state/tsbuildinfo > "$_log" 2>&1; then` | |
| 56 | `  echo "[L2] OK"` | 성공 로그 |
| 57 | `  rm -f "$_log"` | 정리 |
| 58 | `  exit 0` | 즉시 종료 |
| 59 | `else` | |
| 60 | `  echo "[L2] 타입 에러 (마지막 20줄):"` | 실패 로그 |
| 61 | `  tail -20 "$_log"` | 에러 출력 |
| 62 | `  rm -f "$_log"` | 정리 |
| 63 | `  exit 1` | 즉시 종료 |
| 64 | `fi` | |
| 65 | (EOF) | |

### 현재 한계

- **TypeScript 전용**: 줄 11-13에서 tsconfig 없으면 즉시 `exit 0` → 다른 언어 검사 불가
- **exit 전략**: 모든 분기에서 `exit 0` 또는 `exit 1`로 즉시 종료 → 복수 언어 실행 불가능
- **INDEX.md 불일치**: `references/INDEX.md` 줄 110에서 L2 지원 언어를 `TS, Python, Go/Rust/Swift/Kotlin`으로 명시했으나 구현은 TS뿐

---

## 2. 변경 전략: 전체 파일 재작성

### 2.1 아키텍처 변경

**현재**: tsconfig 없으면 즉시 exit 0 → TS 전용 로직
**변경 후**: 각 언어를 순차 감지, 모든 해당 언어 타입체크 실행, 하나라도 실패 시 exit 1

### 2.2 구조 개요

```
줄 1-5     : shebang + 주석 + set -euo pipefail (수정)
줄 7-8     : _root + cd (유지)
줄 10-11   : _fail=0, _detected=0 초기화 (신규)
줄 13-76   : TypeScript 섹션 (기존 로직 래핑)
줄 78-96   : Python 섹션 (신규)
줄 98-116  : Go 섹션 (신규)
줄 118-136 : Rust 섹션 (신규)
줄 138-162 : Swift 섹션 (신규)
줄 164-196 : Kotlin 섹션 (신규)
줄 198-206 : 최종 결과 판정 (신규)
```

### 2.3 수정 원칙

- `local` 금지 — `_prefix` 변수명 사용 (CLAUDE.md 규칙)
- `set -euo pipefail` 유지
- 각 언어 섹션은 독립적 — 해당 감지 파일 없으면 섹션 자체를 skip
- `set -e` 환경에서 에러 포착: `if command; then ... else ... fi` 패턴 (기존 코드와 동일)
- `exit 0`/`exit 1` 직접 호출 제거 → `_fail=1` 설정 후 계속 실행

---

## 3. 완전한 변경 후 파일 (gate-l2.sh)

아래 내용으로 `src/woojoo-magic/lib/gate-l2.sh`를 **전체 교체**한다.

```bash
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
```

---

## 4. 언어별 상세 명세

### 4.1 TypeScript (기존 로직 리팩토링)

| 항목 | 값 |
|------|-----|
| 감지 파일 | `tsconfig.json` 또는 `tsconfig.app.json` |
| 바이너리 체크 | `node_modules/.bin/tsc` (실행 가능) → `npx tsc` (command -v npx) |
| 타입체크 명령 (turbo) | `pnpm turbo typecheck --cache-dir=.dev/state/.turbo` |
| 타입체크 명령 (단일) | `{_tsc} --noEmit -p {_tsconfig} --incremental --tsBuildInfoFile .dev/state/tsbuildinfo` |
| turbo 조건 | `turbo.json` 존재 + `pnpm` 설치 + `package.json`에 `scripts.typecheck` 존재 |
| 로그: 실행 | `[L2] TypeScript tsc --noEmit 실행` 또는 `[L2] TypeScript pnpm turbo typecheck 실행` |
| 로그: 성공 | `[L2] OK (TypeScript)` |
| 로그: 실패 | `[L2] 타입 에러 — TypeScript (마지막 20줄):` |
| 로그: skip | `[L2] skip (TypeScript 미설치)` |

**변경점** (기존 대비):
- 줄 11-13의 `exit 0` 제거 → `if` 블록으로 래핑
- 줄 26-27의 `exit 0` 제거 → `skip` 로그만 출력
- 줄 39/44/58/63의 `exit 0`/`exit 1` 제거 → `_fail=1` 설정
- 로그에 `TypeScript` 언어명 추가 (기존: `[L2] OK` → `[L2] OK (TypeScript)`)
- turbo 경로 사용 여부를 `_ts_done` 플래그로 추적

### 4.2 Python (신규)

| 항목 | 값 |
|------|-----|
| 감지 파일 | `pyproject.toml` 또는 `setup.py` 또는 `requirements.txt` |
| 바이너리 체크 | `command -v pyright` |
| 타입체크 명령 | `pyright .` |
| 로그: 실행 | `[L2] Python pyright 실행` |
| 로그: 성공 | `[L2] OK (Python)` |
| 로그: 실패 | `[L2] 타입 에러 — Python (마지막 20줄):` |
| 로그: skip | `[L2] skip (Python 미설치)` |

**근거**: `references/INDEX.md` 줄 96에 `pyright --strict` 명시. 단, `--strict` 플래그는 프로젝트 설정(pyrightconfig.json / pyproject.toml의 `[tool.pyright]`)에서 관리하는 것이 표준이므로, 스크립트에서는 `pyright .`로 호출하여 프로젝트 설정을 존중한다.

### 4.3 Go (신규)

| 항목 | 값 |
|------|-----|
| 감지 파일 | `go.mod` |
| 바이너리 체크 | `command -v go` |
| 타입체크 명령 | `go build ./...` |
| 로그: 실행 | `[L2] Go go build ./... 실행` |
| 로그: 성공 | `[L2] OK (Go)` |
| 로그: 실패 | `[L2] 타입 에러 — Go (마지막 20줄):` |
| 로그: skip | `[L2] skip (Go 미설치)` |

**근거**: Go는 별도 타입체커 없이 컴파일러가 타입 검증. `references/INDEX.md` 줄 97 빌드 열: `go build ./...`. 타입체크 열: `(컴파일러)`.

### 4.4 Rust (신규)

| 항목 | 값 |
|------|-----|
| 감지 파일 | `Cargo.toml` |
| 바이너리 체크 | `command -v cargo` |
| 타입체크 명령 | `cargo check` |
| 로그: 실행 | `[L2] Rust cargo check 실행` |
| 로그: 성공 | `[L2] OK (Rust)` |
| 로그: 실패 | `[L2] 타입 에러 — Rust (마지막 20줄):` |
| 로그: skip | `[L2] skip (Rust 미설치)` |

**근거**: `cargo check`는 `cargo build`보다 빠름 (바이너리 미생성, 타입+문법만 검증). `references/INDEX.md` 줄 98 빌드 열은 `cargo build`이지만 타입체크 열은 `(컴파일러)`이므로 L2 목적에는 `cargo check`가 적합.

### 4.5 Swift (신규)

| 항목 | 값 |
|------|-----|
| 감지 파일 | `Package.swift` 또는 `*.xcodeproj` 디렉토리 |
| 바이너리 체크 | `command -v swift` |
| 타입체크 명령 | `swift build` |
| 로그: 실행 | `[L2] Swift swift build 실행` |
| 로그: 성공 | `[L2] OK (Swift)` |
| 로그: 실패 | `[L2] 타입 에러 — Swift (마지막 20줄):` |
| 로그: skip | `[L2] skip (Swift 미설치)` |

**근거**: `references/INDEX.md` 줄 99: `swift build`. `*.xcodeproj` 감지는 glob 패턴이 디렉토리에 매치되므로 `for` 루프 + `-d` 체크로 안전하게 처리. glob이 확장되지 않는 경우 `2>/dev/null || true`로 에러 방지.

### 4.6 Kotlin (신규)

| 항목 | 값 |
|------|-----|
| 감지 파일 | `build.gradle.kts` 또는 `build.gradle` |
| 바이너리 체크 (우선) | `./gradlew` 실행 가능 여부 (`-x`) |
| 바이너리 체크 (fallback) | `command -v gradle` |
| 타입체크 명령 | `./gradlew compileKotlin` 또는 `gradle compileKotlin` |
| 로그: 실행 | `[L2] Kotlin ./gradlew compileKotlin 실행` 또는 `[L2] Kotlin gradle compileKotlin 실행` |
| 로그: 성공 | `[L2] OK (Kotlin)` |
| 로그: 실패 | `[L2] 타입 에러 — Kotlin (마지막 20줄):` |
| 로그: skip | `[L2] skip (Kotlin 미설치)` |

**근거**: `compileKotlin`은 전체 빌드(`./gradlew build`) 없이 Kotlin 소스만 컴파일하여 L2 타입체크 목적에 적합. `./gradlew` wrapper 우선, 없으면 시스템 `gradle` 사용.

---

## 5. 멀티 언어 프로젝트 처리

### 5.1 동작 플로우

```
1. _fail=0, _detected=0 초기화
2. 각 언어 섹션 순차 실행 (TS → Python → Go → Rust → Swift → Kotlin)
3. 감지 파일 존재 → _detected++ → 바이너리 확인 → 실행
4. 바이너리 미설치 → skip 로그 (실패 아님, _fail 변경 없음)
5. 타입체크 실패 → _fail=1 (계속 다음 언어 실행)
6. 모든 섹션 완료 후:
   - _detected == 0 → "[L2] skip (지원 언어 미감지)" + exit 0
   - _fail != 0 → exit 1
   - 그 외 → exit 0
```

### 5.2 핵심 원칙

| 원칙 | 설명 |
|------|------|
| 전부 실행 | 첫 번째 실패에서 중단하지 않음 — 모든 감지된 언어 실행 |
| 하나라도 실패 = 전체 실패 | `_fail=1` 한 번 설정되면 최종 exit 1 |
| skip =/= 실패 | 바이너리 미설치는 skip (exit 0에 영향 없음) |
| `set -e` 안전성 | `if cmd; then ... else ... fi` 패턴으로 에러 잡음 |

### 5.3 예시 시나리오

**시나리오 A**: `tsconfig.json` + `go.mod` + `Cargo.toml` (TS+Go+Rust 프로젝트)
```
[L2] TypeScript tsc --noEmit 실행
[L2] OK (TypeScript)
[L2] Go go build ./... 실행
[L2] OK (Go)
[L2] Rust cargo check 실행
[L2] 타입 에러 — Rust (마지막 20줄):
... (에러 내용) ...
→ exit 1 (Rust 실패)
```

**시나리오 B**: `pyproject.toml` 있으나 pyright 미설치
```
[L2] skip (Python 미설치)
→ exit 0 (_detected=1 이지만 _fail=0)
```

**시나리오 C**: 감지 파일 없음
```
[L2] skip (지원 언어 미감지)
→ exit 0
```

---

## 6. 로그 형식 규칙

기존 스타일 유지, 언어명 통일.

| 상황 | 로그 형식 | 예시 |
|------|----------|------|
| 타입체크 실행 | `[L2] {lang} {command} 실행` | `[L2] Python pyright 실행` |
| 성공 | `[L2] OK ({lang})` | `[L2] OK (Go)` |
| 타입 에러 | `[L2] 타입 에러 — {lang} (마지막 20줄):` | `[L2] 타입 에러 — Rust (마지막 20줄):` |
| 바이너리 미설치 | `[L2] skip ({lang} 미설치)` | `[L2] skip (Kotlin 미설치)` |
| 언어 미감지 | `[L2] skip (지원 언어 미감지)` | (단일 메시지) |

### 기존 로그 → 변경 로그 매핑

| 기존 (현재 코드) | 변경 후 |
|-----------------|---------|
| `[L2] skip (tsconfig 없음)` | (삭제 — TS 섹션 if문으로 자동 skip) |
| `[L2] skip (tsc 바이너리 없음)` | `[L2] skip (TypeScript 미설치)` |
| `[L2] turbo typecheck 실행` | `[L2] TypeScript pnpm turbo typecheck 실행` |
| `[L2] OK (turbo)` | `[L2] OK (TypeScript)` |
| `[L2] tsc --noEmit 실행` | `[L2] TypeScript tsc --noEmit 실행` |
| `[L2] OK` | `[L2] OK (TypeScript)` |
| `[L2] 타입 에러 (마지막 20줄):` | `[L2] 타입 에러 — TypeScript (마지막 20줄):` |

---

## 7. 의존성

| 파일 | 관계 | 변경 필요 여부 |
|------|------|---------------|
| `src/woojoo-magic/references/INDEX.md` 줄 90-100 | 빌드/검증 명령 매핑 — 이 스펙의 명령어 근거 | 불필요 |
| `src/woojoo-magic/references/INDEX.md` 줄 110 | `gate-l2.sh` 지원 언어 목록 (이미 6개 명시) | 불필요 |
| `src/woojoo-magic/lib/gate-l1.sh` | L1 정적 감사 (별도 파일) | 불필요 |
| `src/woojoo-magic/commands/loop.md` | 루프 실행 시 gate-l2.sh 호출 | 불필요 (인터페이스 유지: `$1=루트`, exit 0/1) |

---

## 8. 테스트 검증 항목

| # | 테스트 시나리오 | 기대 결과 |
|---|--------------|----------|
| 1 | 감지 파일 없는 빈 디렉토리에서 실행 | `[L2] skip (지원 언어 미감지)` + exit 0 |
| 2 | `tsconfig.json`만 있는 TS 프로젝트 | 기존과 동일하게 tsc 실행, `[L2] OK (TypeScript)` |
| 3 | `pyproject.toml`만 있고 pyright 설치됨 | `[L2] Python pyright 실행` → `[L2] OK (Python)` |
| 4 | `pyproject.toml`만 있고 pyright 미설치 | `[L2] skip (Python 미설치)` + exit 0 |
| 5 | `go.mod` + `pyproject.toml` 동시 존재 | Python, Go 둘 다 실행 |
| 6 | `Cargo.toml` 있으나 cargo 미설치 | `[L2] skip (Rust 미설치)` + exit 0 |
| 7 | `tsconfig.json` + `go.mod`, TS 성공/Go 실패 | 둘 다 실행, exit 1 |
| 8 | `turbo.json` + `pnpm` + `package.json`에 typecheck 스크립트 | `[L2] TypeScript pnpm turbo typecheck 실행` |
| 9 | `Package.swift` 있고 swift 설치됨 | `[L2] Swift swift build 실행` |
| 10 | `build.gradle.kts` + `./gradlew` 실행 가능 | `[L2] Kotlin ./gradlew compileKotlin 실행` |
| 11 | `build.gradle` + `./gradlew` 없음 + gradle 설치됨 | `[L2] Kotlin gradle compileKotlin 실행` |

---

## 9. 주의사항

1. **`set -e` 호환성**: `if` 블록 내부에서 실패하는 명령은 `set -e`에 의해 스크립트를 종료시키지 않음. 이 패턴은 기존 코드와 동일.
2. **tmpfile 누수 방지**: 모든 `_log=$(mktemp)` 이후 `rm -f "$_log"` 반드시 실행. if/else 양쪽 모두에서 정리.
3. **`*.xcodeproj` glob**: nullglob이 설정되지 않은 환경에서 glob이 확장되지 않으면 리터럴 `*.xcodeproj`가 되므로 `-d` 체크 + `2>/dev/null || true`로 방어.
4. **Kotlin `build.gradle` 감지**: `build.gradle`은 Groovy DSL이지만 Kotlin 프로젝트에서도 사용 가능. `build.gradle.kts`(Kotlin DSL)와 함께 감지.
