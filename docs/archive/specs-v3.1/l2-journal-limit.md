# l2-journal-limit: journal.sh 변경 파일 제한 상향

> 우선순위: LOW
> 날짜: 2026-04-13

## 현황

`src/wj-magic/lib/journal.sh`에서 변경된 파일 목록을 기록할 때 `head -10`으로 최대 10개만 표시한다.
대규모 리팩토링이나 팀 에이전트 병렬 작업 시 변경 파일이 10개를 초과하는 경우가 빈번하여,
저널에 변경 이력이 누락된다.

## 문제

- `head -10` 제한으로 11번째 이후 변경 파일이 저널에 기록되지 않음
- 대규모 작업의 변경 범위를 사후 추적할 수 없음
- 누락된 파일로 인해 디버깅/회고 시 정보 부족

## 수정 대상

### 파일: `src/wj-magic/lib/journal.sh`

**27행** (`head -10` 첫 번째 위치):

현재:
```bash
  _changed=$(git diff --name-only HEAD 2>/dev/null | head -10 | sed 's/^/  - /' || true)
```

변경:
```bash
  _changed=$(git diff --name-only HEAD 2>/dev/null | head -30 | sed 's/^/  - /' || true)
```

**29행** (`head -10` 두 번째 위치):

현재:
```bash
    _changed=$(git diff --name-only 2>/dev/null | head -10 | sed 's/^/  - /' || true)
```

변경:
```bash
    _changed=$(git diff --name-only 2>/dev/null | head -30 | sed 's/^/  - /' || true)
```

## 변경 전/후 diff

```diff
--- a/src/wj-magic/lib/journal.sh
+++ b/src/wj-magic/lib/journal.sh
@@ -24,9 +24,9 @@
 # 변경된 파일 목록
 _changed=""
 if command -v git >/dev/null 2>&1; then
-  _changed=$(git diff --name-only HEAD 2>/dev/null | head -10 | sed 's/^/  - /' || true)
+  _changed=$(git diff --name-only HEAD 2>/dev/null | head -30 | sed 's/^/  - /' || true)
   if [[ -z "$_changed" ]]; then
-    _changed=$(git diff --name-only 2>/dev/null | head -10 | sed 's/^/  - /' || true)
+    _changed=$(git diff --name-only 2>/dev/null | head -30 | sed 's/^/  - /' || true)
   fi
 fi
```

## 검증

1. `head -10`이 코드에 더 이상 남아 있지 않은지 확인:
   ```bash
   grep -n 'head -10' src/wj-magic/lib/journal.sh
   ```
   결과: 매치 없어야 함

2. `head -30`이 27행과 29행에 있는지 확인:
   ```bash
   grep -n 'head -30' src/wj-magic/lib/journal.sh
   ```
   결과: 2개 매치

3. 스크립트 문법 검증:
   ```bash
   bash -n src/wj-magic/lib/journal.sh
   ```
   결과: 에러 없어야 함
