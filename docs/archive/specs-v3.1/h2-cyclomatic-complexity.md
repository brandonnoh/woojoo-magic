# h2-cyclomatic-complexity: gate-l1.sh에 Cyclomatic Complexity 체크 추가

## 배경

`gate-l1.sh`는 L1 정적 감사로, grep 기반 패턴 매칭으로 <2초 내에 코드 품질을 검증한다.
`references/INDEX.md`에 "CC <= 10"이 Python/Go 공통 Hard limit으로 명시되어 있으나,
현재 gate-l1.sh에는 CC(Cyclomatic Complexity) 체크가 없다.

## 대상 파일

- `src/woojoo-magic/lib/gate-l1.sh` (현재 317줄)

## 현재 구조 (줄 번호 기준)

| 구간 | 줄 번호 | 내용 |
|------|---------|------|
| 입력 파싱 | 1-15 | stdin/인자 → `_files` |
| TS/JS 파일 필터 | 17-34 | `_ts_files` 구성 |
| TS/JS 검사 | 36-84 | 300줄 초과, any 금지, !., silent catch, eslint-disable |
| Python 파일 필터 | 86-101 | `_py_files` 구성 |
| Python 검사 | 103-154 | 600줄 초과, Any, bare except, type:ignore |
| Go 파일 필터 | 156-165 | `_go_files` 구성 |
| Go 검사 | 167-194 | 500줄 초과, _ = err, interface{} |
| Rust 파일 필터 | 196-205 | `_rs_files` 구성 |
| Rust 검사 | 207-234 | 500줄 초과, unwrap(), unsafe |
| Swift 파일 필터 | 236-245 | `_swift_files` 구성 |
| Swift 검사 | 247-274 | 400줄 초과, force unwrap, try! |
| Kotlin 파일 필터 | 276-285 | `_kt_files` 구성 |
| Kotlin 검사 | 287-314 | 400줄 초과, !!, GlobalScope |
| 최종 OK | 316-317 | `echo "[L1] OK"` + exit 0 |

## 변경 내용

### 삽입 위치: 줄 314(`fi`) 다음, 줄 316(`echo "[L1] OK"`) 직전

현재:
```bash
# 줄 313:   fi
# 줄 314: fi
# 줄 315: (빈 줄)
# 줄 316: echo "[L1] OK"
# 줄 317: exit 0
```

줄 314(`fi`) 다음에 아래 블록 삽입:

```bash
# === Cyclomatic Complexity 체크 (외부 도구 의존, 선택적) ===

# Python CC: ruff C901 (ruff 설치 시만)
if [[ -n "$_py_files" ]] && command -v ruff >/dev/null 2>&1; then
  _cc_violations=""
  while IFS= read -r f; do
    _cc_out=$(ruff check --select C901 --output-format json "$f" 2>/dev/null || true)
    if [[ -n "$_cc_out" && "$_cc_out" != "[]" ]]; then
      # JSON 배열에서 위반 추출
      _cc_parsed=$(echo "$_cc_out" | jq -r '.[] | "\(.filename):\(.location.row) \(.message)"' 2>/dev/null || true)
      if [[ -n "$_cc_parsed" ]]; then
        _cc_violations="${_cc_violations}${_cc_parsed}"$'\n'
      fi
    fi
  done <<< "$_py_files"
  _cc_violations="$(echo "$_cc_violations" | sed '/^$/d')"
  if [[ -n "$_cc_violations" ]]; then
    echo "[L1] Python Cyclomatic Complexity 초과:"
    echo "$_cc_violations" | head -5 | sed 's/^/  /'
    exit 1
  fi
fi

# Go CC: gocyclo (설치 시만)
if [[ -n "$_go_files" ]] && command -v gocyclo >/dev/null 2>&1; then
  _go_cc=$(echo "$_go_files" | xargs gocyclo -over 10 2>/dev/null || true)
  if [[ -n "$_go_cc" ]]; then
    echo "[L1] Go Cyclomatic Complexity 초과 (>10):"
    echo "$_go_cc" | head -5 | sed 's/^/  /'
    exit 1
  fi
fi

# TS/JS CC: 현재 skip (eslint complexity 규칙은 .eslintrc 의존성이 높아 L1에 부적합)
# 향후 biome 또는 oxlint에 CC 규칙이 추가되면 여기서 확장

# Rust CC: 현재 skip (cargo clippy cognitive_complexity는 L2에서 처리)
# Swift CC: 현재 skip (swiftlint cyclomatic_complexity는 L2에서 처리)
# Kotlin CC: 현재 skip (detekt CyclomaticComplexMethod는 L2에서 처리)
```

### 상세 설명

#### Python (ruff C901)

- **도구**: `ruff` — Rust 기반 Python linter, 매우 빠름 (<0.5초)
- **규칙**: `C901` = McCabe cyclomatic complexity
- **기본 한도**: ruff 기본 CC > 10 (INDEX.md와 일치)
- **출력 형식**: `--output-format json`으로 구조화된 결과
- **jq 파싱**: `filename:row message` 형태로 변환
- **실패 조건**: 하나라도 C901 위반이 있으면 exit 1

ruff JSON 출력 예시:
```json
[{"code":"C901","filename":"app/service.py","location":{"row":42,"column":1},"message":"`process_data` is too complex (15 > 10)"}]
```

#### Go (gocyclo)

- **도구**: `gocyclo` — `go install github.com/fzipp/gocyclo/cmd/gocyclo@latest`
- **플래그**: `-over 10` — CC > 10인 함수만 출력
- **실패 조건**: 출력이 있으면 exit 1

#### TS/JS — 의도적 skip

eslint의 `complexity` 규칙은 `.eslintrc` 설정 의존성이 높고, 프로젝트마다 설정이 달라
L1의 "설정 없이 동작" 원칙에 부합하지 않는다. 향후 `biome`이나 `oxlint`에
CC 규칙이 추가되면 여기서 확장한다.

#### Rust/Swift/Kotlin — L2로 위임

각 언어의 CC 체크는 컴파일러/린터 수준 도구에 의존하므로 L2(gate-l2.sh)에서 처리하는 것이 적합하다.

## 속도 목표: <2초 유지

| 체크 | 예상 시간 | 조건 |
|------|----------|------|
| ruff C901 (Python) | ~0.3초 (파일 10개 기준) | ruff 설치 시만 |
| gocyclo (Go) | ~0.2초 (파일 10개 기준) | gocyclo 설치 시만 |
| 도구 미설치 시 | 0초 (skip) | `command -v` 체크로 즉시 통과 |

핵심: `command -v` 체크가 실패하면 **즉시 skip**. 도구 설치를 강제하지 않는다.

## 의존성

- `ruff` (선택): Python CC 체크. 미설치 시 skip.
- `gocyclo` (선택): Go CC 체크. 미설치 시 skip.
- `jq` (기존 의존): ruff JSON 파싱에 사용. gate-l1.sh는 jq 없이도 동작해야 하므로,
  jq가 없으면 ruff CC 체크도 skip해야 한다 → `command -v jq` 추가 체크 필요.

수정: ruff CC 체크 조건을 다음으로 변경:
```bash
if [[ -n "$_py_files" ]] && command -v ruff >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
```

## 수락 조건

1. Python 파일에서 CC > 10인 함수가 있고 ruff가 설치되어 있으면 L1 실패
2. Go 파일에서 CC > 10인 함수가 있고 gocyclo가 설치되어 있으면 L1 실패
3. ruff/gocyclo가 미설치인 환경에서 에러 없이 skip
4. jq가 미설치인 환경에서 ruff CC 체크 skip
5. TS/JS CC는 의도적으로 skip (주석으로 사유 명시)
6. 기존 언어별 검사에 영향 없음 (새 블록은 Kotlin 검사 뒤, `[L1] OK` 전에 삽입)
7. 전체 gate-l1.sh 실행 시간 <2초 유지
