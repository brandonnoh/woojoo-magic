# m3-l1-early-exit: gate-l1.sh 조기 종료 버그 수정

> 우선순위: MEDIUM  
> 예상 작업량: ~30줄 변경  
> 의존성: 없음 (m1과 병렬 가능하지만, m1 적용 후라면 변수명이 달라짐)

## 1. 버그 설명

`lib/gate-l1.sh`는 TS 검사에서 실패하면 **83줄에서 즉시 `exit 1`**한다.
이로 인해 동일 커밋에 Python, Go, Rust, Swift, Kotlin 파일이 포함되어 있어도 **전혀 검사되지 않는다**.

예시 시나리오:
1. 사용자가 `app.ts` (any 타입 사용) + `main.py` (bare except) + `handler.go` (interface{}) 를 동시에 수정
2. gate-l1.sh 실행 → TS any 감지 → 83줄에서 `exit 1`
3. Python/Go 검사는 **실행되지 않음**
4. 사용자가 TS any만 수정 후 재실행 → 이제야 Python bare except 감지
5. 이 과정이 **언어 수만큼 반복**될 수 있음

## 2. 현재 exit 1 위치 (전수 조사)

| 줄 | 언어 | 코드 | 영향 |
|----|------|------|------|
| **83줄** | TS/JS | `exit 1` | Python/Go/Rust/Swift/Kotlin 검사 차단 |
| **152줄** | Python | `exit 1` | Go/Rust/Swift/Kotlin 검사 차단 |
| **192줄** | Go | `exit 1` | Rust/Swift/Kotlin 검사 차단 |
| **232줄** | Rust | `exit 1` | Swift/Kotlin 검사 차단 |
| **272줄** | Swift | `exit 1` | Kotlin 검사 차단 |
| **312줄** | Kotlin | `exit 1` | 마지막이므로 영향 없음 |
| **317줄** | 성공 | `exit 0` | 정상 |

## 3. 현재 코드 흐름 (문제점 표시)

```
파일 입력
  ├─ TS 필터 → TS 검사 → 실패? → exit 1  ← 여기서 끝!
  ├─ Python 필터 → Python 검사 → 실패? → exit 1  ← 도달 불가
  ├─ Go 필터 → Go 검사 → 실패? → exit 1  ← 도달 불가
  ├─ Rust 필터 → Rust 검사 → 실패? → exit 1  ← 도달 불가
  ├─ Swift 필터 → Swift 검사 → 실패? → exit 1  ← 도달 불가
  ├─ Kotlin 필터 → Kotlin 검사 → 실패? → exit 1  ← 도달 불가
  └─ exit 0
```

## 4. 수정 설계

### 4.1 전역 누적 변수

파일 상단(기존 36줄)의 `_fail=0` / `_messages=""`를 **전체 공유 변수**로 변경:

**현재 (36-37줄):**
```bash
_fail=0
_messages=""
```

**변경 (36-37줄 — 이름 변경):**
```bash
_total_fail=0
_total_messages=""
```

### 4.2 TS 블록 수정 (80-84줄)

**Before (80-84줄):**
```bash
if (( _fail == 1 )); then
  echo "[L1] TS/JS 정적 감사 실패:"
  echo "$_messages"
  exit 1
fi
```

**After:**
```bash
if (( _fail == 1 )); then
  _total_messages="${_total_messages}[L1] TS/JS 정적 감사 실패:"$'\n'"${_messages}"$'\n'
  _total_fail=1
fi
```

### 4.3 Python 블록 수정 (149-153줄)

**Before (149-153줄):**
```bash
  if (( _py_fail == 1 )); then
    echo "[L1] Python 정적 감사 실패:"
    echo "$_py_messages"
    exit 1
  fi
```

**After:**
```bash
  if (( _py_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Python 정적 감사 실패:"$'\n'"${_py_messages}"$'\n'
    _total_fail=1
  fi
```

### 4.4 Go 블록 수정 (189-193줄)

**Before (189-193줄):**
```bash
  if (( _go_fail == 1 )); then
    echo "[L1] Go 정적 감사 실패:"
    echo "$_go_messages"
    exit 1
  fi
```

**After:**
```bash
  if (( _go_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Go 정적 감사 실패:"$'\n'"${_go_messages}"$'\n'
    _total_fail=1
  fi
```

### 4.5 Rust 블록 수정 (229-233줄)

**Before (229-233줄):**
```bash
  if (( _rs_fail == 1 )); then
    echo "[L1] Rust 정적 감사 실패:"
    echo "$_rs_messages"
    exit 1
  fi
```

**After:**
```bash
  if (( _rs_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Rust 정적 감사 실패:"$'\n'"${_rs_messages}"$'\n'
    _total_fail=1
  fi
```

### 4.6 Swift 블록 수정 (269-273줄)

**Before (269-273줄):**
```bash
  if (( _sw_fail == 1 )); then
    echo "[L1] Swift 정적 감사 실패:"
    echo "$_sw_messages"
    exit 1
  fi
```

**After:**
```bash
  if (( _sw_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Swift 정적 감사 실패:"$'\n'"${_sw_messages}"$'\n'
    _total_fail=1
  fi
```

### 4.7 Kotlin 블록 수정 (309-313줄)

**Before (309-313줄):**
```bash
  if (( _kt_fail == 1 )); then
    echo "[L1] Kotlin 정적 감사 실패:"
    echo "$_kt_messages"
    exit 1
  fi
```

**After:**
```bash
  if (( _kt_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Kotlin 정적 감사 실패:"$'\n'"${_kt_messages}"$'\n'
    _total_fail=1
  fi
```

### 4.8 파일 끝 (현재 316-317줄) 수정

**Before (316-317줄):**
```bash
echo "[L1] OK"
exit 0
```

**After:**
```bash
if (( _total_fail == 1 )); then
  echo "$_total_messages"
  exit 1
fi

echo "[L1] OK"
exit 0
```

## 5. 수정 후 흐름

```
파일 입력
  ├─ TS 필터 → TS 검사 → 실패? → _total_messages에 누적
  ├─ Python 필터 → Python 검사 → 실패? → _total_messages에 누적
  ├─ Go 필터 → Go 검사 → 실패? → _total_messages에 누적
  ├─ Rust 필터 → Rust 검사 → 실패? → _total_messages에 누적
  ├─ Swift 필터 → Swift 검사 → 실패? → _total_messages에 누적
  ├─ Kotlin 필터 → Kotlin 검사 → 실패? → _total_messages에 누적
  └─ _total_fail==1? → 전체 메시지 출력 + exit 1
     아니면 → "[L1] OK" + exit 0
```

## 6. 출력 형식 변경

**Before (TS만 실패 시):**
```
[L1] TS/JS 정적 감사 실패:
  any 타입 감지:
    src/app.ts:42: const x: any = ...
```

**After (TS+Python 동시 실패 시):**
```
[L1] TS/JS 정적 감사 실패:
  any 타입 감지:
    src/app.ts:42: const x: any = ...

[L1] Python 정적 감사 실패:
  bare except: 감지:
    src/main.py:15: except:
```

stop-loop.sh에서 이 출력을 `$_l1_out`으로 받아 JSON reason에 넣으므로, 여러 언어 실패가 한 번에 보인다.

## 7. 기존 TS 블록 내부 _fail / _messages 변수 유지

TS 블록 내부(36-78줄)의 `_fail`/`_messages`는 그대로 둔다. 이 변수들은 TS 블록 범위 내에서만 사용되며, 80줄의 조건문에서 `_total_messages`로 합산되는 역할이다.

다만 **36줄의 초기화 위치가 TS 전용**이라는 점에 주의: TS 파일이 없어서 34줄 `exit 0`으로 빠지는 경우를 대비해 `_total_fail=0` / `_total_messages=""`는 **15줄 근처 (파일 초반)** 에 선언한다.

**삽입 위치: 15줄 (`[[ -n "$_files" ]] || exit 0`) 바로 뒤:**
```bash
[[ -n "$_files" ]] || exit 0

_total_fail=0
_total_messages=""
```

## 8. 테스트 계획

- 기존 `tests/gate-l1.bats` 통과 확인
- **새 테스트 추가**: TS 실패 파일 + Python 실패 파일을 동시 입력 → 두 언어 모두 실패 메시지에 포함되는지 확인
- **새 테스트 추가**: TS 실패 + Go 성공 → TS 실패 메시지만 출력, Go는 검사되었으나 통과
- exit 코드가 1인지 확인

## 9. 파일 변경 요약

| 파일 | 동작 |
|------|------|
| `src/wj-magic/lib/gate-l1.sh` | 전역 누적 변수 추가 + 6개 `exit 1`을 누적으로 변경 + 파일 끝 최종 판정 추가 |
