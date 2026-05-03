# m1-pattern-lib: gate-l1과 quality-check 공통 패턴을 lib/patterns.sh로 추출

> 우선순위: MEDIUM  
> 예상 작업량: ~120줄 신규 + 두 파일 리팩토링  
> 의존성: 없음 (독립 작업)

## 1. 현황 분석

`lib/gate-l1.sh`와 `hooks/quality-check.sh`는 동일한 안티패턴 검출 정규식을 **중복**으로 유지하고 있다.
패턴 하나를 수정하면 두 파일을 모두 수정해야 하며, 이미 미묘한 차이가 발생하고 있다.

## 2. 중복 패턴 상세 비교

### 2.1 TS/JS 패턴

| 검사 항목 | gate-l1.sh 위치 | gate-l1.sh 정규식 | quality-check.sh 위치 | quality-check.sh 정규식 | 차이 |
|-----------|-----------------|--------------------|-----------------------|--------------------------|------|
| any 타입 | 49줄 | `':\s*any\b\|<any>\|\bas\s+any\b'` | 29줄 | `': any\b\|<any>\|as any\b'` | gate-l1은 `\s*` 사용, quality-check은 공백 리터럴 |
| non-null assertion (!.) | 57줄 | `'[A-Za-z0-9_\)\]]!\.'` | 32줄 | `'[A-Za-z0-9_)\]]!\.'` | 동일 (이스케이프 방식만 다름) |
| silent catch | 65줄 | `'catch\s*\(\s*\w*\s*\)\s*\{\s*\}'` | 36줄 | perl 사용: `'catch\s*(?:\([^)]*\))?\s*\{\s*\}'` | quality-check은 perl 멀티라인, gate-l1은 grep 단일줄 |
| eslint-disable any | 73줄 | `'eslint-disable.*no-explicit-any'` | 40줄 | `'eslint-disable.*no-explicit-any'` | **동일** |
| 300줄 제한 | 42줄 | `(( _lines > 300 ))` | 26줄 | `[[ "${LINES}" -gt 300 ]]` | 동일 의미 |

### 2.2 Python 패턴

| 검사 항목 | gate-l1.sh 위치 | quality-check.sh 위치 | 차이 |
|-----------|-----------------|------------------------|------|
| Any 타입 | 117줄 | 56줄 | gate-l1은 `List[Any]`, `Dict[.*, Any]`도 포함 |
| bare except | 125줄 | 59줄 | 동일: `'^\s*except\s*:'` |
| silent except | 126-129줄 | 62줄 | gate-l1은 -A1 grep으로 pass 검출, quality-check은 단일줄 |
| type: ignore | 142줄 | 65줄 | 동일: `'#\s*type:\s*ignore\s*$'` |
| 600줄 제한 | 110줄 | 51줄 | 동일 |

### 2.3 Go 패턴

| 검사 항목 | gate-l1.sh 위치 | quality-check.sh 위치 | 차이 |
|-----------|-----------------|------------------------|------|
| _ = err | 177줄 | 75줄 | 동일: `'^\s*_\s*=\s*\w+\('` |
| interface{} | 183줄 | 78줄 | 동일: `'interface\{\}'` |
| 500줄 제한 | 172줄 | 72줄 | 동일 |

### 2.4 Rust 패턴

| 검사 항목 | gate-l1.sh 위치 | quality-check.sh 위치 | 차이 |
|-----------|-----------------|------------------------|------|
| unwrap() | 217줄 | 88줄 | gate-l1은 test 파일 제외 필터 있음, quality-check은 없음 |
| 500줄 제한 | 212줄 | 85줄 | 동일 |

### 2.5 Swift 패턴

| 검사 항목 | gate-l1.sh 위치 | quality-check.sh 위치 | 차이 |
|-----------|-----------------|------------------------|------|
| try! | 263줄 | 98줄 | 동일: `'\btry!'` |
| 400줄 제한 | 252줄 | 95줄 | 동일 |

### 2.6 Kotlin 패턴

| 검사 항목 | gate-l1.sh 위치 | quality-check.sh 위치 | 차이 |
|-----------|-----------------|------------------------|------|
| !! | 297줄 | 108줄 | 동일: `'!!'` |
| GlobalScope | 303줄 | 111줄 | 동일: `'GlobalScope'` |
| 400줄 제한 | 293줄 | 105줄 | 동일 |

## 3. 설계: lib/patterns.sh

### 3.1 파일 경로

```
src/wj-magic/lib/patterns.sh
```

### 3.2 구조

```bash
#!/usr/bin/env bash
# patterns.sh — 언어별 안티패턴 정규식 공통 라이브러리
# source로 가져와서 사용. 단독 실행 불가.
set -euo pipefail

# === 줄 수 제한 ===
declare -A WJ_LINE_LIMITS=(
  [ts]=300
  [py]=600
  [py_soft]=400
  [go]=500
  [rs]=500
  [swift]=400
  [kt]=400
)

# === TS/JS 패턴 ===
WJ_TS_ANY=':\s*any\b|<any>|\bas\s+any\b'
WJ_TS_NONNULL='[A-Za-z0-9_)\]]!\.'
WJ_TS_SILENT_CATCH='catch\s*\(\s*\w*\s*\)\s*\{\s*\}'
WJ_TS_ESLINT_ANY='eslint-disable.*no-explicit-any'
WJ_TS_AS_CAST='\bas\b\s+[A-Z]'

# === Python 패턴 ===
WJ_PY_ANY=':\s*Any\b|-> Any\b|List\[Any\]|Dict\[.*, Any\]'
WJ_PY_BARE_EXCEPT='^\s*except\s*:'
WJ_PY_SILENT_EXCEPT='except.*:\s*$'
WJ_PY_TYPE_IGNORE='#\s*type:\s*ignore\s*$'

# === Go 패턴 ===
WJ_GO_IGNORED_ERR='^\s*_\s*=\s*\w+\('
WJ_GO_EMPTY_IFACE='interface\{\}'

# === Rust 패턴 ===
WJ_RS_UNWRAP='\.unwrap\(\)'
WJ_RS_UNSAFE='^\s*unsafe\s'

# === Swift 패턴 ===
WJ_SW_FORCE_UNWRAP='[a-zA-Z0-9_)\]]!'
WJ_SW_TRY_FORCE='\btry!'

# === Kotlin 패턴 ===
WJ_KT_BANGBANG='!!'
WJ_KT_GLOBALSCOPE='GlobalScope'

# === 파일 필터 제외 패턴 ===
WJ_TS_EXCLUDE='*.d.ts|*__tests__*|*.test.*|*.spec.*|*node_modules*|*dist/*'
WJ_PY_EXCLUDE='*__pycache__*|*.pyc|*node_modules*|*dist/*|*venv/*|*.venv/*'
WJ_GO_EXCLUDE='*vendor/*|*_test.go'
WJ_RS_EXCLUDE='*target/*'
WJ_SW_EXCLUDE='*.build/*|*DerivedData/*'
WJ_KT_EXCLUDE='*build/*|*generated/*'
```

### 3.3 gate-l1.sh 변경 방법

**Before (49-54줄):**
```bash
# 2) any 금지
_any_hits=$(echo "$_ts_files" | xargs grep -HnE ':\s*any\b|<any>|\bas\s+any\b' 2>/dev/null | grep -v '// @ts-' || true)
if [[ -n "$_any_hits" ]]; then
  _messages="${_messages}  any 타입 감지:"$'\n'
  _messages="${_messages}$(echo "$_any_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi
```

**After:**
```bash
# 2) any 금지
_any_hits=$(echo "$_ts_files" | xargs grep -HnE "$WJ_TS_ANY" 2>/dev/null | grep -v '// @ts-' || true)
if [[ -n "$_any_hits" ]]; then
  _messages="${_messages}  any 타입 감지:"$'\n'
  _messages="${_messages}$(echo "$_any_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi
```

gate-l1.sh 파일 상단(7줄 뒤)에 source 추가:

```bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patterns.sh"
```

**치환 목록 (gate-l1.sh):**

| 현재 줄 | 현재 정규식 리터럴 | 변수 치환 |
|---------|---------------------|-----------|
| 49줄 | `':\s*any\b\|<any>\|\bas\s+any\b'` | `"$WJ_TS_ANY"` |
| 57줄 | `'[A-Za-z0-9_\)\]]!\.'` | `"$WJ_TS_NONNULL"` |
| 65줄 | `'catch\s*\(\s*\w*\s*\)\s*\{\s*\}'` | `"$WJ_TS_SILENT_CATCH"` |
| 73줄 | `'eslint-disable.*no-explicit-any'` | `"$WJ_TS_ESLINT_ANY"` |
| 117줄 | `':\s*Any\b\|-> Any\b\|List\[Any\]\|Dict\[.*, Any\]'` | `"$WJ_PY_ANY"` |
| 125줄 | `'^\s*except\s*:'` | `"$WJ_PY_BARE_EXCEPT"` |
| 142줄 | `'#\s*type:\s*ignore\s*$'` | `"$WJ_PY_TYPE_IGNORE"` |
| 177줄 | `'^\s*_\s*=\s*\w+\('` | `"$WJ_GO_IGNORED_ERR"` |
| 183줄 | `'interface\{\}'` | `"$WJ_GO_EMPTY_IFACE"` |
| 217줄 | `'\.unwrap\(\)'` | `"$WJ_RS_UNWRAP"` |
| 223줄 | `'^\s*unsafe\s'` | `"$WJ_RS_UNSAFE"` |
| 257줄 | `'[a-zA-Z0-9_\)\]]!'` | `"$WJ_SW_FORCE_UNWRAP"` |
| 263줄 | `'\btry!'` | `"$WJ_SW_TRY_FORCE"` |
| 297줄 | `'!!'` | `"$WJ_KT_BANGBANG"` |
| 303줄 | `'GlobalScope'` | `"$WJ_KT_GLOBALSCOPE"` |

### 3.4 quality-check.sh 변경 방법

파일 상단(4줄 뒤)에 source 추가:

```bash
set -euo pipefail

_plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${_plugin_root}/lib/patterns.sh"
```

**치환 목록 (quality-check.sh):**

| 현재 줄 | 현재 정규식 리터럴 | 변수 치환 |
|---------|---------------------|-----------|
| 29줄 | `': any\b\|<any>\|as any\b'` | `"$WJ_TS_ANY"` |
| 32줄 | `'[A-Za-z0-9_)\]]!\.'` | `"$WJ_TS_NONNULL"` |
| 40줄 | `'eslint-disable.*no-explicit-any'` | `"$WJ_TS_ESLINT_ANY"` |
| 43줄 | `'\bas\b\s+[A-Z]'` | `"$WJ_TS_AS_CAST"` |
| 56줄 | `':\s*Any\b\|-> Any\b'` | `"$WJ_PY_ANY"` |
| 59줄 | `'^\s*except\s*:'` | `"$WJ_PY_BARE_EXCEPT"` |
| 65줄 | `'#\s*type:\s*ignore\s*$'` | `"$WJ_PY_TYPE_IGNORE"` |
| 75줄 | `'^\s*_\s*=\s*\w+\('` | `"$WJ_GO_IGNORED_ERR"` |
| 78줄 | `'interface\{\}'` | `"$WJ_GO_EMPTY_IFACE"` |
| 88줄 | `'\.unwrap\(\)'` | `"$WJ_RS_UNWRAP"` |
| 98줄 | `'\btry!'` | `"$WJ_SW_TRY_FORCE"` |
| 108줄 | `'!!'` | `"$WJ_KT_BANGBANG"` |
| 111줄 | `'GlobalScope'` | `"$WJ_KT_GLOBALSCOPE"` |

### 3.5 quality-check.sh 29줄 정규식 불일치 해결

quality-check.sh 29줄의 `': any\b'`는 `\s*` 없이 공백 리터럴을 사용한다.
`WJ_TS_ANY`로 통일하면 `:\s*any\b`가 되어 공백 없는 경우도 잡을 수 있다 (상위 호환).

### 3.6 quality-check.sh 36줄 perl silent catch 처리

quality-check.sh의 silent catch는 perl 멀티라인 검사로 gate-l1.sh보다 정밀하다.
`$WJ_TS_SILENT_CATCH`는 grep 단일줄 용도로만 사용하고, quality-check.sh의 perl 로직은 그대로 둔다.
대신 주석으로 "멀티라인 검사는 perl 사용, 단일줄은 WJ_TS_SILENT_CATCH" 명시.

## 4. 테스트 계획

- 기존 `tests/gate-l1.bats` 테스트가 모두 통과하는지 확인
- patterns.sh에 `shellcheck` 통과 확인
- 새 패턴 추가 시 patterns.sh 한 곳만 수정하면 되는지 확인

## 5. 파일 변경 요약

| 파일 | 동작 |
|------|------|
| `src/wj-magic/lib/patterns.sh` | **신규 생성** (~70줄) |
| `src/wj-magic/lib/gate-l1.sh` | source 추가 (7줄 뒤) + 정규식 15곳 변수 치환 |
| `src/wj-magic/hooks/quality-check.sh` | source 추가 (4줄 뒤) + 정규식 13곳 변수 치환 |
