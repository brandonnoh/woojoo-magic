# h3-session-v2-cleanup: session-summary.sh v2 잔재 제거

## 배경

`session-summary.sh`는 세션 시작 시 프로젝트 상태를 요약하는 훅이다.
v2에서 사용하던 `tests.json` 기반 진행률 블록이 아직 남아있다.
v3에서는 `.dev/tasks.json`으로 이전했으므로 `tests.json` 블록을 제거해야 한다.

## 대상 파일

- `src/wj-magic/hooks/session-summary.sh` (현재 79줄)

## 현재 구조 (줄 번호 기준)

| 구간 | 줄 번호 | 내용 | 상태 |
|------|---------|------|------|
| 초기화, git 정보 | 1-20 | PROJECT_ROOT, BRANCH, RECENT | 유지 |
| **tests.json 진행률** | **22-29** | **v2 잔재 — 제거 대상** | **삭제** |
| 300줄 초과 파일 카운트 | 31-43 | find로 TS/JS 파일 스캔 | 유지 |
| any/!. 카운트 | 45-54 | grep으로 간이 카운트 | 유지 |
| .dev/tasks.json 진행률 | 56-67 | v3 tasks 진행률 | 유지 |
| 핵심 규칙 리마인더 | 69-77 | 품질 기준 출력 | 유지 |
| exit 0 | 79 | 종료 | 유지 |

## 변경 내용

### 삭제 대상: 줄 22-29 (정확히 8줄)

삭제할 코드:
```bash
# tests.json 진행률
if [[ -f tests.json ]] && command -v jq >/dev/null 2>&1; then
  TOTAL="$(jq '[.tasks[]?] | length' tests.json 2>/dev/null || echo 0)"
  DONE="$(jq '[.tasks[]? | select(.status=="done")] | length' tests.json 2>/dev/null || echo 0)"
  if [[ "${TOTAL}" != "0" ]]; then
    echo "  tests.json: ${DONE}/${TOTAL} 완료"
  fi
fi
```

### 삭제 전 줄 20-31:
```
20  fi
21  (빈 줄)
22  # tests.json 진행률           ← 삭제 시작
23  if [[ -f tests.json ]] ...    ← 삭제
24    TOTAL=...                   ← 삭제
25    DONE=...                    ← 삭제
26    if [[ ...                   ← 삭제
27      echo ...                  ← 삭제
28    fi                          ← 삭제
29  fi                            ← 삭제 끝
30  (빈 줄)
31  # 300줄 초과 파일
```

### 삭제 후 줄 20-22:
```
20  fi
21  (빈 줄)
22  # 300줄 초과 파일
```

## 영향 범위

- 없음. `tests.json` 블록은 독립적이며, 다른 변수나 로직을 참조하지 않는다.
- 삭제 후 파일은 79줄 → 71줄.

## 의존성

- 없음. 단순 삭제 작업.

## 수락 조건

1. `tests.json` 관련 코드 8줄 (줄 22-29) 완전 삭제
2. `.dev/tasks.json` 블록 (현재 줄 56-67) 그대로 유지
3. 나머지 모든 기능 정상 동작
4. `set -euo pipefail` 하에서 에러 없음
