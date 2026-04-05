---
description: 프로젝트 전체 품질 전수 점검 (300줄/any/!./silent catch/중복)
---

현재 프로젝트의 TypeScript/JavaScript 소스를 전수 점검하고 woojoo-magic 표준 위반 사항을 리포트한다.

점검 항목:

1. **300줄 초과 파일 목록**
   - `*.ts, *.tsx, *.js, *.jsx` 대상
   - `node_modules, .git, dist, build, .next, coverage` 제외
   - 상위 20개 + 총 개수

2. **`any` 사용 위치**
   - 정규식: `: any\b|<any>|as any\b`
   - 파일:라인:스니펫 출력

3. **`!.` (non-null assertion) 사용 위치**

4. **Silent catch 위치**
   - 정규식 (multiline): `catch\s*\([^)]*\)\s*\{\s*\}`

5. **중복 코드 패턴 (휴리스틱)**
   - 동일 10+ 라인 블록 grep 기반 추정
   - 확신이 없으면 "후보" 로 표기

출력 형식:

```
## woojoo-magic 품질 리포트

### 요약
- 300줄 초과: N개
- any 사용: N곳
- !. 사용: N곳
- silent catch: N곳

### 상세
...
```

마지막에 "치명 / 경고 / 권장" 3단계로 우선순위 제시.
