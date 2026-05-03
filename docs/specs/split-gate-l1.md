# split-gate-l1: gate-l1.sh 언어별 파일 분리

## 배경
`src/wj-magic/lib/gate-l1.sh`가 363줄로 플러그인이 강제하는 300줄 규칙을 자가 위반한다. 6개 언어 + CC 검사가 단일 파일에 있어 유지보수가 어렵다. 각 언어 블록은 독립적이어서 분리가 가능하다.

## 현재 코드 구조 (gate-l1.sh 363줄)

```
줄  1- 18: shebang + 공통 초기화 (patterns.sh source, _files 읽기, _total_fail/messages 초기화)
줄 19- 92: TS/JS 검사 (_ts_files 필터, any/!./타입단언/silent catch 검사)
줄 93-161: Python 검사 (_py_files 필터, Any/bare_except/silent 검사)
줄 162-200: Go 검사 (_go_files 필터, err 무시/빈인터페이스 검사)
줄 201-239: Rust 검사 (_rs_files 필터, unwrap/unsafe 검사)
줄 240-278: Swift 검사 (_sw_files 필터, 강제언래핑/try! 검사)
줄 279-317: Kotlin 검사 (_kt_files 필터, !! 연산자/GlobalScope 검사)
줄 318-363: CC 검사 (Python ruff C901, Rust/Swift/Kotlin skip 안내)
```

마지막 줄 (~355-363):
```bash
if [[ $_total_fail -gt 0 ]]; then
  printf '%s' "$_total_messages"
  exit 1
fi
exit 0
```

## 변경 범위
| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `lib/gate-l1.sh` | 대폭 수정 | 오케스트레이터로 리팩토링 (~40줄) |
| `lib/gate-l1-ts.sh` | 생성 | TS/JS 검사 블록 (줄 19-92 기반, ~80줄) |
| `lib/gate-l1-py.sh` | 생성 | Python 검사 블록 (줄 93-161 기반, ~70줄) |
| `lib/gate-l1-go.sh` | 생성 | Go 검사 블록 (줄 162-200 기반, ~40줄) |
| `lib/gate-l1-rs.sh` | 생성 | Rust 검사 블록 (줄 201-239 기반, ~40줄) |
| `lib/gate-l1-sw.sh` | 생성 | Swift 검사 블록 (줄 240-278 기반, ~40줄) |
| `lib/gate-l1-kt.sh` | 생성 | Kotlin 검사 블록 (줄 279-317 기반, ~40줄) |
| `lib/gate-l1-cc.sh` | 생성 | CC 검사 블록 (줄 318-363 기반, ~50줄) |

## 구현 방향

### gate-l1.sh (오케스트레이터, ~40줄)
```bash
#!/usr/bin/env bash
# gate-l1.sh — L1 정적 감사 오케스트레이터 (언어별 서브모듈 위임)
set -euo pipefail

_l1_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_l1_dir}/patterns.sh"

_files=""
if [[ $# -gt 0 && -f "$1" ]]; then
  _files="$1"
else
  _files="$(cat || true)"
fi

[[ -n "$_files" ]] || exit 0

_total_fail=0
_total_messages=""

# 각 언어 서브모듈 실행
for _l1_mod in ts py go rs sw kt cc; do
  source "${_l1_dir}/gate-l1-${_l1_mod}.sh"
  _l1_check_"${_l1_mod}" "$_files"  # 또는 각 파일이 함수를 직접 정의
done

if [[ $_total_fail -gt 0 ]]; then
  printf '%s' "$_total_messages"
  exit 1
fi
exit 0
```

### 각 서브모듈 패턴 (예: gate-l1-ts.sh)
```bash
#!/usr/bin/env bash
# gate-l1-ts.sh — TS/JS L1 정적 감사
# 이 파일은 gate-l1.sh에서 source됨.
# _files, _total_fail, _total_messages 전역 변수를 읽고 업데이트함.

# TS/JS 파일만 필터
_ts_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx) ;;
    *) continue ;;
  esac
  _ts_files="${_ts_files}${f}"$'\n'
done <<< "$_files"

[[ -z "$_ts_files" ]] && return 0 2>/dev/null || exit 0

# ... 기존 TS 검사 로직 그대로 이식 ...
```

**주의**: 각 서브모듈은 `source`되어 실행되므로:
- `exit`는 `return`으로 변경 (또는 함수로 래핑)
- `_total_fail`, `_total_messages`는 전역 변수로 공유
- `_files` 변수를 인자로 받거나 전역으로 공유

가장 단순한 방법: 각 서브모듈을 `_l1_run_<lang>()` 함수로 정의하고 gate-l1.sh에서 호출.

## 의존 관계
- `hooks/stop-loop.sh`가 `lib/gate-l1.sh`를 source함 (줄 ~86) — gate-l1.sh 경로 변경 없음, 동작 변경 없음
- `hooks/subagent-gate.sh`도 gate-l1.sh를 사용 — 동일
- 서브모듈들은 gate-l1.sh만 source하면 되므로 호출자 변경 불필요

## 검증 명령
```bash
bash -n src/wj-magic/lib/gate-l1.sh
for f in ts py go rs sw kt cc; do bash -n src/wj-magic/lib/gate-l1-${f}.sh; done
wc -l src/wj-magic/lib/gate-l1.sh  # 100줄 이하
wc -l src/wj-magic/lib/gate-l1-*.sh | sort -rn | head -5  # 모두 100줄 이하

# 기능 검증 (TS any 사용 파일로 테스트)
echo 'const x: any = 1;' > /tmp/test-gate.ts
echo "/tmp/test-gate.ts" | bash src/wj-magic/lib/gate-l1.sh; echo "exit: $?"  # exit 1 예상
rm /tmp/test-gate.ts
```
