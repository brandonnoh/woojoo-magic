# fix-hooks-test-jq: hooks.json 래퍼 구조에 맞게 테스트 jq 쿼리 수정

## 배경
오늘 `src/wj-studybook/hooks/hooks.json`에 `"hooks"` 래퍼를 추가했다 (woojoo-magic 포맷 통일).
그 결과 두 테스트 파일의 jq 쿼리가 null을 반환하며 hooks.json 구조 검증 테스트가 전부 실패한다.

## 현재 코드

### tests/wj-studybook/test-capture-stop.bats (줄 36, 42)
```bash
run jq -r '.Stop[0].hooks[0].command' "$HOOKS_JSON"   # null 반환
run jq -r '.Stop | type' "$HOOKS_JSON"                 # null
```

### tests/wj-studybook/test-capture-session-end.bats (줄 59, 65 근처)
```bash
run jq -r '.SessionEnd[0].hooks[0].command' "$HOOKS_JSON"
run jq -r '.SessionEnd | type' "$HOOKS_JSON"
```

### hooks.json 실제 구조
```json
{ "hooks": { "Stop": [...], "SessionEnd": [...] } }
```

## 변경 범위
| 파일 | 줄 | 변경 내용 |
|------|---|---------|
| `tests/wj-studybook/test-capture-stop.bats` | 36, 42 | `.Stop` → `.hooks.Stop` |
| `tests/wj-studybook/test-capture-session-end.bats` | ~59, ~65 | `.SessionEnd` → `.hooks.SessionEnd` |

## 구현 방향
단순 문자열 치환:
```bash
# Before
jq -r '.Stop[0].hooks[0].command'
jq -r '.Stop | type'

# After
jq -r '.hooks.Stop[0].hooks[0].command'
jq -r '.hooks.Stop | type'
```

## 검증 명령
```bash
jq -r '.hooks.Stop[0].hooks[0].command' src/wj-studybook/hooks/hooks.json  # 경로 문자열 출력
jq -r '.hooks.SessionEnd[0].hooks[0].command' src/wj-studybook/hooks/hooks.json  # 경로 문자열 출력
bats tests/wj-studybook/test-capture-stop.bats 2>&1 | grep -E "PASS|FAIL|ok|not ok"
```
