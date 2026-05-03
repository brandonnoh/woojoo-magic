# l4-broken-paths: 참조 경로 깨진 곳 전수 수정

> 우선순위: LOW
> 날짜: 2026-04-13

## 현황

`references/` 디렉토리가 재구조화되면서 하위 파일들이 `common/`, `typescript/`, `python/` 등의 서브디렉토리로 이동했다. 하지만 이를 참조하는 `.md` 파일들의 경로가 업데이트되지 않아 깨진 참조가 다수 존재한다.

### 현재 디렉토리 구조 (정상)

```
src/wj-magic/references/
  INDEX.md
  common/
    HIGH_QUALITY_CODE_STANDARDS.md
    REFACTORING_PREVENTION.md
  typescript/
    BRANDED_TYPES_PATTERN.md
    DISCRIMINATED_UNION.md
    LIBRARY_TYPE_HARDENING.md
    NON_NULL_ELIMINATION.md
    RESULT_PATTERN.md
    ZUSTAND_SLICE_PATTERN.md
    standards.md
  python/
    standards.md
  go/
    standards.md
  kotlin/
    standards.md
  rust/
    standards.md
  swift/
    standards.md
```

## 깨진 경로 전수 목록

### 1. `src/wj-magic/skills/cto-review/skill.md`

| 라인 | 깨진 경로 | 정상 경로 |
|------|----------|----------|
| **19행** | `../../references/BRANDED_TYPES_PATTERN.md` | `../../references/typescript/BRANDED_TYPES_PATTERN.md` |
| **20행** | `../../references/RESULT_PATTERN.md` | `../../references/typescript/RESULT_PATTERN.md` |
| **21행** | `../../references/DISCRIMINATED_UNION.md` | `../../references/typescript/DISCRIMINATED_UNION.md` |
| **38행** | `../../references/REFACTORING_PREVENTION.md` | `../../references/common/REFACTORING_PREVENTION.md` |

**수정 내역:**

19행 현재:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
```
19행 변경:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/typescript/BRANDED_TYPES_PATTERN.md`
```

20행 현재:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
```
20행 변경:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/typescript/RESULT_PATTERN.md`
```

21행 현재:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
```
21행 변경:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/typescript/DISCRIMINATED_UNION.md`
```

38행 현재:
```markdown
**상세: `../../references/REFACTORING_PREVENTION.md`**
```
38행 변경:
```markdown
**상세: `../../references/common/REFACTORING_PREVENTION.md`**
```

---

### 2. `src/wj-magic/skills/learn/skill.md`

| 라인 | 깨진 경로 | 정상 경로 |
|------|----------|----------|
| **17행** | `../../references/BRANDED_TYPES_PATTERN.md` | `../../references/typescript/BRANDED_TYPES_PATTERN.md` |
| **18행** | `../../references/RESULT_PATTERN.md` | `../../references/typescript/RESULT_PATTERN.md` |
| **19행** | `../../references/DISCRIMINATED_UNION.md` | `../../references/typescript/DISCRIMINATED_UNION.md` |
| **36행** | `../../references/REFACTORING_PREVENTION.md` | `../../references/common/REFACTORING_PREVENTION.md` |

**수정 내역:**

17행 현재:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
```
17행 변경:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/typescript/BRANDED_TYPES_PATTERN.md`
```

18행 현재:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
```
18행 변경:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/typescript/RESULT_PATTERN.md`
```

19행 현재:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
```
19행 변경:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/typescript/DISCRIMINATED_UNION.md`
```

36행 현재:
```markdown
**상세: `../../references/REFACTORING_PREVENTION.md`**
```
36행 변경:
```markdown
**상세: `../../references/common/REFACTORING_PREVENTION.md`**
```

---

### 3. `src/wj-magic/skills/team/skill.md`

| 라인 | 깨진 경로 | 정상 경로 |
|------|----------|----------|
| **13행** | `../../references/BRANDED_TYPES_PATTERN.md` | `../../references/typescript/BRANDED_TYPES_PATTERN.md` |
| **14행** | `../../references/RESULT_PATTERN.md` | `../../references/typescript/RESULT_PATTERN.md` |
| **15행** | `../../references/DISCRIMINATED_UNION.md` | `../../references/typescript/DISCRIMINATED_UNION.md` |
| **32행** | `../../references/REFACTORING_PREVENTION.md` | `../../references/common/REFACTORING_PREVENTION.md` |

**수정 내역:**

13행 현재:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
```
13행 변경:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/typescript/BRANDED_TYPES_PATTERN.md`
```

14행 현재:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
```
14행 변경:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/typescript/RESULT_PATTERN.md`
```

15행 현재:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
```
15행 변경:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/typescript/DISCRIMINATED_UNION.md`
```

32행 현재:
```markdown
**상세: `../../references/REFACTORING_PREVENTION.md`**
```
32행 변경:
```markdown
**상세: `../../references/common/REFACTORING_PREVENTION.md`**
```

---

### 4. `src/wj-magic/skills/commit/skill.md`

| 라인 | 깨진 경로 | 정상 경로 |
|------|----------|----------|
| **13행** | `../../references/BRANDED_TYPES_PATTERN.md` | `../../references/typescript/BRANDED_TYPES_PATTERN.md` |
| **14행** | `../../references/RESULT_PATTERN.md` | `../../references/typescript/RESULT_PATTERN.md` |
| **15행** | `../../references/DISCRIMINATED_UNION.md` | `../../references/typescript/DISCRIMINATED_UNION.md` |
| **32행** | `../../references/REFACTORING_PREVENTION.md` | `../../references/common/REFACTORING_PREVENTION.md` |

**수정 내역:**

13행 현재:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
```
13행 변경:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/typescript/BRANDED_TYPES_PATTERN.md`
```

14행 현재:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
```
14행 변경:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/typescript/RESULT_PATTERN.md`
```

15행 현재:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
```
15행 변경:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/typescript/DISCRIMINATED_UNION.md`
```

32행 현재:
```markdown
**상세: `../../references/REFACTORING_PREVENTION.md`**
```
32행 변경:
```markdown
**상세: `../../references/common/REFACTORING_PREVENTION.md`**
```

---

### 5. `src/wj-magic/skills/ideation/skill.md`

| 라인 | 깨진 경로 | 정상 경로 |
|------|----------|----------|
| **20행** | `../../references/BRANDED_TYPES_PATTERN.md` | `../../references/typescript/BRANDED_TYPES_PATTERN.md` |
| **21행** | `../../references/RESULT_PATTERN.md` | `../../references/typescript/RESULT_PATTERN.md` |
| **22행** | `../../references/DISCRIMINATED_UNION.md` | `../../references/typescript/DISCRIMINATED_UNION.md` |
| **39행** | `../../references/REFACTORING_PREVENTION.md` | `../../references/common/REFACTORING_PREVENTION.md` |

**수정 내역:**

20행 현재:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
```
20행 변경:
```markdown
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/typescript/BRANDED_TYPES_PATTERN.md`
```

21행 현재:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
```
21행 변경:
```markdown
- Result<T,E> 패턴으로 에러 처리 — `../../references/typescript/RESULT_PATTERN.md`
```

22행 현재:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
```
22행 변경:
```markdown
- Discriminated Union으로 상태 모델링 — `../../references/typescript/DISCRIMINATED_UNION.md`
```

39행 현재:
```markdown
**상세: `../../references/REFACTORING_PREVENTION.md`**
```
39행 변경:
```markdown
**상세: `../../references/common/REFACTORING_PREVENTION.md`**
```

---

### 6. `src/wj-magic/commands/check.md`

| 라인 | 깨진 경로 | 정상 경로 |
|------|----------|----------|
| **22행** | `references/standards/typescript.md` | `references/typescript/standards.md` |
| **45행** | `references/standards/python.md` | `references/python/standards.md` |

**수정 내역:**

22행 현재:
```markdown
기준: `references/standards/typescript.md`
```
22행 변경:
```markdown
기준: `references/typescript/standards.md`
```

45행 현재:
```markdown
기준: `references/standards/python.md`
```
45행 변경:
```markdown
기준: `references/python/standards.md`
```

---

## 요약 테이블

| 파일 | 깨진 경로 수 | 패턴 |
|------|-------------|------|
| `skills/cto-review/skill.md` | 4 | `BRANDED_TYPES`, `RESULT`, `DISCRIMINATED`, `REFACTORING` |
| `skills/learn/skill.md` | 4 | 동일 |
| `skills/team/skill.md` | 4 | 동일 |
| `skills/commit/skill.md` | 4 | 동일 |
| `skills/ideation/skill.md` | 4 | 동일 |
| `commands/check.md` | 2 | `standards/typescript`, `standards/python` |
| **합계** | **22** | |

## 정상 경로인 파일 (수정 불필요)

다음 파일들은 이미 정상 경로를 사용하고 있다:

- `agents/frontend-dev.md` 7행: `references/common/HIGH_QUALITY_CODE_STANDARDS.md` -- 정상
- `agents/backend-dev.md` 7행: `references/common/HIGH_QUALITY_CODE_STANDARDS.md` -- 정상
- `agents/engine-dev.md` 7행: `references/common/HIGH_QUALITY_CODE_STANDARDS.md` -- 정상
- `agents/qa-reviewer.md` 8행, 13행: `references/common/HIGH_QUALITY_CODE_STANDARDS.md` -- 정상
- `agents/docs-keeper.md` 7행: `references/common/HIGH_QUALITY_CODE_STANDARDS.md` -- 정상
- `skills/devrule/skill.md` 22~30행: 모두 정상 경로 (`references/INDEX.md`, `references/common/...`, `references/typescript/...` 등)
- 5개 skill의 `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md` 참조: 모두 정상

## 효율적 수정 전략

5개 skill 파일(cto-review, learn, team, commit, ideation)은 **동일한 품질 기준 프리앰블**을 공유하므로, 다음 4가지 치환을 모든 파일에 일괄 적용 가능:

```
../../references/BRANDED_TYPES_PATTERN.md       → ../../references/typescript/BRANDED_TYPES_PATTERN.md
../../references/RESULT_PATTERN.md               → ../../references/typescript/RESULT_PATTERN.md
../../references/DISCRIMINATED_UNION.md           → ../../references/typescript/DISCRIMINATED_UNION.md
../../references/REFACTORING_PREVENTION.md        → ../../references/common/REFACTORING_PREVENTION.md
```

`commands/check.md`는 별도 패턴:
```
references/standards/typescript.md  → references/typescript/standards.md
references/standards/python.md      → references/python/standards.md
```

## 검증

수정 완료 후 아래 명령으로 잔여 깨진 경로가 없는지 확인:

```bash
# 1. 이전 루트 레벨 참조 잔존 여부
grep -rn 'references/BRANDED_TYPES_PATTERN.md' src/wj-magic/ --include='*.md' | grep -v 'typescript/'
grep -rn 'references/RESULT_PATTERN.md' src/wj-magic/ --include='*.md' | grep -v 'typescript/'
grep -rn 'references/DISCRIMINATED_UNION.md' src/wj-magic/ --include='*.md' | grep -v 'typescript/'
grep -rn 'references/REFACTORING_PREVENTION.md' src/wj-magic/ --include='*.md' | grep -v 'common/'

# 2. 이전 standards/ 경로 잔존 여부
grep -rn 'references/standards/' src/wj-magic/ --include='*.md'

# 모든 명령의 결과가 비어 있어야 함
```
