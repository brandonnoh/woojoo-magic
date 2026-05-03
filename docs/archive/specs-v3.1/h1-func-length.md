# h1-func-length: quality-check.sh에 함수 길이 체크 추가

## 배경

`quality-check.sh`는 PostToolUse 훅으로, Edit/Write 후 파일 품질을 즉시 경고한다.
현재 **파일 줄 수**, **any/!.**, **silent catch** 등을 체크하지만,
**함수 길이**(TS 20줄, Python 50줄 등)는 체크하지 않는다.
`references/INDEX.md`에 명시된 Hard limits에 함수 길이가 포함되어 있으므로 추가가 필요하다.

## 대상 파일

- `src/wj-magic/hooks/quality-check.sh` (현재 128줄)

## 현재 구조 (줄 번호 기준)

| 구간 | 줄 번호 | 내용 |
|------|---------|------|
| 입력 파싱 | 1-18 | stdin JSON → `FILE` 추출 |
| `WARN=()` | 20 | 경고 배열 초기화 |
| TS/JS 검사 | 22-47 | `*.ts\|*.tsx\|*.js\|*.jsx` — 파일 줄 수(300줄), any, !., silent catch, eslint-disable, as 캐스팅 |
| Python 검사 | 48-68 | `*.py` — 파일 줄 수(600/400줄), Any, bare except, except+pass, type:ignore |
| Go 검사 | 69-81 | `*.go` — 파일 줄 수(500줄), _ = err, interface{} |
| Rust 검사 | 82-91 | `*.rs` — 파일 줄 수(500줄), unwrap() |
| Swift 검사 | 92-101 | `*.swift` — 파일 줄 수(400줄), try! |
| Kotlin 검사 | 102-114 | `*.kt\|*.kts` — 파일 줄 수(400줄), !!, GlobalScope |
| 기본 탈출 | 115-117 | `*) exit 0` |
| 경고 출력 | 120-127 | `WARN` 배열 출력 + exit 0 |

## 변경 내용

### 1. TS/JS 섹션 (줄 46 직전, `as 캐스팅` 체크 뒤에 추가)

현재 줄 43-46:
```bash
    AS_COUNT=$(grep -cE '\bas\b\s+[A-Z]' "${FILE}" 2>/dev/null || echo 0)
    if [[ "${AS_COUNT}" -gt 3 ]]; then
      WARN+=("as 캐스팅 ${AS_COUNT}회 — 타입 가드/제네릭 사용 권장 → LIBRARY_TYPE_HARDENING.md")
    fi
```

**줄 46(`fi`) 다음, 줄 47(`;;`) 직전에** 아래 블록 삽입:

```bash
    # 함수 길이 체크 (rough estimate, 20줄 초과)
    _LONG_FUNCS=""
    if command -v awk >/dev/null 2>&1; then
      _LONG_FUNCS=$(awk '
        /^[[:space:]]*(export[[:space:]]+)?(async[[:space:]]+)?function[[:space:]]+[A-Za-z_]/ ||
        /^[[:space:]]*(export[[:space:]]+)?(const|let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*(async[[:space:]]*)?\(/ {
          if (fname != "" && (NR - start) > 20) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
          fname = $0; sub(/^[[:space:]]+/, "", fname); sub(/[({].*/, "", fname)
          start = NR
        }
        END {
          if (fname != "" && (NR - start) > 20) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
        }
      ' "${FILE}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_FUNCS}" ]]; then
      _FUNC_COUNT=$(echo "${_LONG_FUNCS}" | wc -l | tr -d ' ')
      WARN+=("20줄 초과 함수 ${_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        WARN+=("  ${_fl}")
      done <<< "$(echo "${_LONG_FUNCS}" | head -3)"
    fi
```

**정확한 삽입 위치**:

```
기존 줄 46:     fi
>>> 여기에 삽입 <<<
기존 줄 47:     ;;
```

### 2. Python 섹션 (줄 67 직전, `type:ignore` 체크 뒤에 추가)

현재 줄 65-67:
```bash
    if grep -En '#\s*type:\s*ignore\s*$' "${FILE}" >/dev/null 2>&1; then
      WARN+=("type: ignore (사유 없음) — 사유 주석 필수 (예: # type: ignore[arg-type])")
    fi
```

**줄 67(`fi`) 다음, 줄 68(`;;`) 직전에** 아래 블록 삽입:

```bash
    # 함수 길이 체크 (rough estimate, 50줄 초과)
    _LONG_PY_FUNCS=""
    if command -v awk >/dev/null 2>&1; then
      _LONG_PY_FUNCS=$(awk '
        /^[[:space:]]*def [A-Za-z_]/ {
          if (fname != "" && (NR - start) > 50) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
          fname = $0; sub(/^[[:space:]]+/, "", fname); sub(/\(.*/, "", fname)
          start = NR
        }
        END {
          if (fname != "" && (NR - start) > 50) {
            printf "%s:%d (%d줄)\n", fname, start, (NR - start)
          }
        }
      ' "${FILE}" 2>/dev/null || true)
    fi
    if [[ -n "${_LONG_PY_FUNCS}" ]]; then
      _PY_FUNC_COUNT=$(echo "${_LONG_PY_FUNCS}" | wc -l | tr -d ' ')
      WARN+=("50줄 초과 함수 ${_PY_FUNC_COUNT}개 감지 — 함수를 분할하세요:")
      while IFS= read -r _fl; do
        WARN+=("  ${_fl}")
      done <<< "$(echo "${_LONG_PY_FUNCS}" | head -3)"
    fi
```

### 3. Go/Rust/Swift/Kotlin 섹션 — 동일 패턴 적용

| 언어 | 함수 한도 | 패턴 | 삽입 위치 (현재 줄) |
|------|----------|------|-------------------|
| Go | 40줄 | `/^func /` | 줄 80 `fi` 다음, 줄 81 `;;` 직전 |
| Rust | 40줄 | `/^[[:space:]]*(pub[[:space:]]+)?(async[[:space:]]+)?fn /` | 줄 90 `fi` 다음, 줄 91 `;;` 직전 |
| Swift | 30줄 | `/^[[:space:]]*(public\|private\|internal\|open)?[[:space:]]*(static\|class)?[[:space:]]*func /` | 줄 100 `fi` 다음, 줄 101 `;;` 직전 |
| Kotlin | 30줄 | `/^[[:space:]]*(public\|private\|internal\|protected)?[[:space:]]*(suspend[[:space:]]+)?fun /` | 줄 113 `fi` 다음, 줄 114 `;;` 직전 |

각 언어의 awk 블록은 TS/Python과 동일한 구조이며, 함수 시작 패턴과 한도만 다르다.

## 구현 원칙

- **정확도보다 속도 우선**: awk로 함수 시작 ~ 다음 함수 시작 사이 줄 수를 단순 계산. AST 파싱 없음.
- **중첩 함수/클로저**: 중첩 함수는 별도로 카운트하지 않음 (rough estimate OK).
- **출력 제한**: `head -3`으로 최대 3개만 보여준다 (PostToolUse라 간결해야 함).
- `awk`가 없는 환경이면 skip (`command -v awk` 체크).
- 경고만 (WARN 배열에 추가) — exit 1 하지 않음 (quality-check.sh는 항상 exit 0).

## 의존성

- 없음. `awk`만 사용. 외부 도구 의존 없음.

## 수락 조건

1. TS/JS 파일에서 20줄 초과 함수가 있으면 경고 출력
2. Python 파일에서 50줄 초과 함수가 있으면 경고 출력
3. Go(40줄), Rust(40줄), Swift(30줄), Kotlin(30줄) 동일
4. 함수가 없는 파일에서는 경고 없음
5. `awk`가 없는 환경에서 에러 없이 skip
6. 기존 체크에 영향 없음 (새 블록은 기존 `fi` 뒤에 삽입)
