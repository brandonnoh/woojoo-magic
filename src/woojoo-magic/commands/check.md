---
description: 프로젝트 전체 품질 전수 점검 (TS/Python 자동 감지, 300줄/복잡도/any/silent catch/중복)
---

현재 프로젝트를 전수 점검하고 woojoo-magic 표준 위반 사항을 리포트한다.

## 0단계: 언어 감지

프로젝트 루트에서 다음 파일 존재 여부로 언어 판별:

- **TypeScript/JavaScript**: `package.json`, `tsconfig.json`, `*.ts`, `*.tsx`
- **Python**: `pyproject.toml`, `requirements.txt`, `setup.py`, `*.py`
- **둘 다** → polyglot, 두 섹션 모두 실행

제외 경로(공통): `node_modules, .git, dist, build, .next, coverage, .venv, venv, __pycache__, .pytest_cache, .ruff_cache`

---

## TypeScript/JavaScript 점검

대상: `*.ts, *.tsx, *.js, *.jsx`
기준: `shared-references/standards/typescript.md`

1. **300줄 초과 파일**
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

---

## Python 점검

대상: `*.py`
기준: `shared-references/standards/python.md`

1. **400줄 초과 파일**
   - 상위 20개 + 총 개수

2. **`Any` 사용 위치**
   - 정규식: `: Any\b|\[Any\]|-> Any\b|Any,`
   - 파일:라인:스니펫 출력

3. **Bare/Silent except**
   - 정규식 1: `except\s*:` (bare except)
   - 정규식 2 (multiline): `except\s+\w+[^:]*:\s*pass\s*$`
   - 정규식 3 (multiline): `except\s+Exception[^:]*:\s*pass`

4. **Mutable default argument**
   - 정규식: `def\s+\w+\([^)]*=\s*\[\]|def\s+\w+\([^)]*=\s*\{\}`

5. **Cyclomatic Complexity > 10**
   - `ruff` 설치되어 있으면: `ruff check . --select C901 --output-format concise`
   - 미설치 시: "ruff 미설치 — 복잡도 점검 스킵" 표기

6. **추가 자동 검증 (ruff 존재 시)**
   - `ruff check . --statistics` 출력 요약
   - `pyright --outputjson` 존재 시 strict 에러 개수

---

## 출력 형식

```
## woojoo-magic 품질 리포트

### 감지된 언어
- TypeScript: ✅ (src/ 하위 TS 123개 파일)
- Python: ✅ (scripts/ 하위 PY 45개 파일)

### 요약 (TypeScript)
- 300줄 초과: N개
- any 사용: N곳
- !. 사용: N곳
- silent catch: N곳

### 요약 (Python)
- 400줄 초과: N개
- Any 사용: N곳
- bare/silent except: N곳
- mutable default: N곳
- 복잡도 > 10 함수: N개

### 상세
...
```

마지막에 **치명 / 경고 / 권장** 3단계로 우선순위 제시.

- **치명**: `any`/`Any`, `!.`/bare except, silent catch, mutable default
- **경고**: 파일 크기 초과, 복잡도 > 10
- **권장**: 중복 코드 후보, 복잡도 7-10 함수

---

## ⚡ 즉시 실행

**대기하지 마라. 이 프롬프트를 받는 즉시 위 절차대로 실행하라.**
