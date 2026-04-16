# l3-session-bang-fix: session-summary.sh `!.` 카운트 정규식 수정

> 우선순위: LOW
> 날짜: 2026-04-13

## 현황

`src/woojoo-magic/hooks/session-summary.sh`에서 non-null assertion(`!.`) 사용을 카운트하는 정규식이
너무 넓어서 false positive가 발생한다. 한편, 같은 프로젝트의 `src/woojoo-magic/lib/gate-l1.sh`에서는
이미 정확한 정규식 `[A-Za-z0-9_\)\]]!\.`을 사용하고 있다.

## 문제

### session-summary.sh (52행) — 부정확한 패턴

```bash
BANG=$( { grep -rIn --include='*.ts' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
    -E '!\.' . 2>/dev/null || true; } | wc -l | tr -d ' ')
```

- 정규식 `'!\.'`는 `!.` 앞에 오는 문자를 제한하지 않음
- 주석 안의 `!.`, 문자열 리터럴 안의 `!.`, 마크다운 포맷 `!.` 등이 모두 매치됨
- 결과적으로 실제 non-null assertion보다 더 많은 수가 카운트됨

### gate-l1.sh (57행) — 정확한 패턴

```bash
_nn_hits=$(echo "$_ts_files" | xargs grep -HnE '[A-Za-z0-9_\)\]]!\.' 2>/dev/null || true)
```

- `[A-Za-z0-9_\)\]]` — `!.` 바로 앞에 식별자 문자, `)`, `]`가 와야 매치
- 실제 TypeScript non-null assertion 패턴(`foo!.bar`, `result)!.value`, `arr]!.length`)만 정확하게 포착

## 수정 대상

### 파일: `src/woojoo-magic/hooks/session-summary.sh`

**50~52행**:

현재:
```bash
  BANG=$( { grep -rIn --include='*.ts' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
    -E '!\.' . 2>/dev/null || true; } | wc -l | tr -d ' ')
```

변경:
```bash
  BANG=$( { grep -rIn --include='*.ts' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
    -E '[A-Za-z0-9_)\]]!\.' . 2>/dev/null || true; } | wc -l | tr -d ' ')
```

## 변경 전/후 diff

```diff
--- a/src/woojoo-magic/hooks/session-summary.sh
+++ b/src/woojoo-magic/hooks/session-summary.sh
@@ -49,7 +49,7 @@
   BANG=$( { grep -rIn --include='*.ts' --include='*.tsx' \
     --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
-    -E '!\.' . 2>/dev/null || true; } | wc -l | tr -d ' ')
+    -E '[A-Za-z0-9_)\]]!\.' . 2>/dev/null || true; } | wc -l | tr -d ' ')
   echo "  any 사용: ${ANY}곳 / !. 사용: ${BANG}곳"
```

핵심 변경점: **52행**의 `-E '!\.'`를 `-E '[A-Za-z0-9_)\]]!\.'`로 교체.

## 검증

1. 정규식 일치 확인 — gate-l1.sh 57행과 동일한 패턴인지 비교:
   ```bash
   grep -n 'A-Za-z0-9_' src/woojoo-magic/hooks/session-summary.sh
   grep -n 'A-Za-z0-9_' src/woojoo-magic/lib/gate-l1.sh
   ```
   두 파일 모두 `[A-Za-z0-9_\)\]]!\.` 패턴이 존재해야 함

2. 이전 패턴이 남아 있지 않은지 확인:
   ```bash
   grep -n "E '!\\\\.'" src/woojoo-magic/hooks/session-summary.sh
   ```
   결과: 매치 없어야 함

3. 스크립트 문법 검증:
   ```bash
   bash -n src/woojoo-magic/hooks/session-summary.sh
   ```
   결과: 에러 없어야 함
