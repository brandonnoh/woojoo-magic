# c2-extract-preamble: 스킬 공통 "품질 기준" 블록 추출

> 상태: SPEC | 우선순위: CRITICAL
> 신규 파일: `src/wj-magic/references/common/SKILL_PREAMBLE.md`
> 수정 파일: 5개 스킬 (`commit`, `team`, `cto-review`, `learn`, `ideation`)

---

## 1. 현황: 중복 블록 정밀 분석

### 1.1 중복 블록 식별

5개 스킬 파일에 **완전히 동일한** 27줄 블록이 복사되어 있다 (MD5: `06f70bcf1688d29fe895bbc0e39b75a8`).

### 1.2 중복 블록 전문 (27줄)

아래가 5개 파일에 동일하게 존재하는 정확한 텍스트이다:

```markdown
## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
- 같은 패턴 2곳 이상 → 공통 유틸 추출
- CSS animation > JS animation (성능)
- Silent catch 금지

### MCP 필수 사용
- **serena**: 코드 탐색/수정 (symbolic tools)
- **context7**: 라이브러리 API 문서 조회
- **sequential-thinking**: 복잡한 리팩토링 계획

### 리팩토링 방지 시그널
파일 작성 중 다음 징후가 보이면 즉시 분할:
- 파일 200줄 돌파 → 300줄 넘기 전에 SRP 기준 분리
- 함수가 3가지 이상 책임 → 분해
- 같은 패턴 2곳 반복 → 공통 유틸
- Props 5개 초과 → 객체 그룹핑

**상세: `../../references/REFACTORING_PREVENTION.md`**
```

### 1.3 각 파일별 중복 블록 위치 (1-indexed 줄 번호)

| 파일 | 프론트매터 끝 줄 | 빈 줄 | 중복 시작 줄 | 중복 끝 줄 | 빈 줄 | 본문 시작 줄 | 총 줄 수 |
|------|---------------|-------|------------|----------|-------|------------|---------|
| `skills/commit/skill.md` | 4 (`---`) | 5 | **6** | **32** | 33 | 34 (`# 커밋 메시지 규칙`) | 107 |
| `skills/team/skill.md` | 4 (`---`) | 5 | **6** | **32** | 33 | 34 (`# Team Assembly & Execution`) | 143 |
| `skills/cto-review/skill.md` | 10 (`---`) | 11 | **12** | **38** | 39 | 40 (`# CTO Code Review & Optimization`) | 280 |
| `skills/learn/skill.md` | 8 (`---`) | 9 | **10** | **36** | 37 | 38 (`# Learn - 개발 규칙 자동 학습 스킬`) | 126 |
| `skills/ideation/skill.md` | 11 (`---`) | 12 | **13** | **39** | 40 | 41 (`# 아이데이션 스쿼드`) | 88 |

### 1.4 확인 사항

- 모든 파일에서 중복 블록 앞뒤로 빈 줄 1개씩 존재
- 중복 블록은 프론트매터(`---...---`) 직후, 스킬 본문(`# 제목`) 직전에 위치
- `skills/devrule/skill.md`에는 이 블록이 **없음** (별도 구조 사용)

---

## 2. 신규 파일: SKILL_PREAMBLE.md

### 2.1 파일 경로

`src/wj-magic/references/common/SKILL_PREAMBLE.md`

이미 `references/common/` 디렉토리에 `HIGH_QUALITY_CODE_STANDARDS.md`와 `REFACTORING_PREVENTION.md`가 존재하므로 디렉토리 생성 불필요.

### 2.2 파일 내용 (전문)

기존 중복 블록을 그대로 추출한다. 경로 참조만 스킬 파일 기준(`../../references/`)에서 `common/` 디렉토리 기준 상대 경로로 변경하지 **않는다** — 이 파일은 스킬 파일에서 참조되므로 스킬 파일 기준 경로를 유지한다.

```markdown
## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
- 같은 패턴 2곳 이상 → 공통 유틸 추출
- CSS animation > JS animation (성능)
- Silent catch 금지

### MCP 필수 사용
- **serena**: 코드 탐색/수정 (symbolic tools)
- **context7**: 라이브러리 API 문서 조회
- **sequential-thinking**: 복잡한 리팩토링 계획

### 리팩토링 방지 시그널
파일 작성 중 다음 징후가 보이면 즉시 분할:
- 파일 200줄 돌파 → 300줄 넘기 전에 SRP 기준 분리
- 함수가 3가지 이상 책임 → 분해
- 같은 패턴 2곳 반복 → 공통 유틸
- Props 5개 초과 → 객체 그룹핑

**상세: `../../references/REFACTORING_PREVENTION.md`**
```

---

## 3. 각 스킬 파일 수정: 상세 지침

### 3.1 공통 교체 패턴

**삭제할 문자열** (27줄 — 앞뒤 빈 줄 포함하면 29줄 범위):

각 파일에서 중복 블록 시작 줄의 **직전 빈 줄** ~ 중복 블록 끝 줄의 **직후 빈 줄**까지 (빈줄-블록-빈줄) 삭제하고, 아래 **대체 문자열**로 교체한다:

**대체 문자열** (2줄 — 앞뒤 빈 줄 포함):

```markdown

**품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)

```

즉, 빈 줄 + 포인터 1줄 + 빈 줄로 교체.

---

### 3.2 skills/commit/skill.md

**현재 (줄 4-34)**:
```
4: ---
5: (빈 줄)
6: ## 품질 기준 (woojoo-magic 표준)
7: (빈 줄)
... (중복 블록 27줄) ...
32: **상세: `../../references/REFACTORING_PREVENTION.md`**
33: (빈 줄)
34: # 커밋 메시지 규칙
```

**변경 후 (줄 4-7)**:
```
4: ---
5: (빈 줄)
6: **품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)
7: (빈 줄)
8: # 커밋 메시지 규칙
```

**수정 후 파일 첫 10줄**:
```
1: ---
2: name: commit
3: description: 커밋, commit, 커밋해줘, 변경사항 저장, 커밋 메시지 등의 요청 시 사용. 한글 커밋 메시지 작성 규칙과 타입 분류(feat/fix/ui/ux/docs/refactor/chore/test/perf) 적용.
4: ---
5:
6: **품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)
7:
8: # 커밋 메시지 규칙
9:
10: ## When to use this skill
```

**줄 수 변화**: 107줄 → 80줄 (27줄 삭제, 1줄 추가 = -26줄)

---

### 3.3 skills/team/skill.md

**현재 (줄 4-34)**:
```
4: ---
5: (빈 줄)
6: ## 품질 기준 (woojoo-magic 표준)
... (중복 블록 27줄) ...
32: **상세: `../../references/REFACTORING_PREVENTION.md`**
33: (빈 줄)
34: # Team Assembly & Execution
```

**변경 후 (줄 4-8)**:
```
4: ---
5: (빈 줄)
6: **품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)
7: (빈 줄)
8: # Team Assembly & Execution
```

**수정 후 파일 첫 10줄**:
```
1: ---
2: name: team
3: description: 팀 구성, 에이전트, 전문가, 스웜, 병렬 작업, 부서 투입 등의 키워드 시 사용. agents.md 조직도를 참조하여 적절한 전문가 에이전트를 선별하고 TeamCreate + Task 도구로 병렬 팀 작업을 수행. "팀 구성해줘", "에이전트 소환", "전문가 투입", "QA 돌려줘", "보안 점검", "SEO 분석", "성능 최적화", "개발팀 소환", "운영팀 투입" 등의 요청에 트리거.
4: ---
5:
6: **품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)
7:
8: # Team Assembly & Execution
9:
10: ## When to use this skill
```

**줄 수 변화**: 143줄 → 117줄 (-26줄)

---

### 3.4 skills/cto-review/skill.md

**현재 (줄 10-40)**:
```
10: ---
11: (빈 줄)
12: ## 품질 기준 (woojoo-magic 표준)
... (중복 블록 27줄) ...
38: **상세: `../../references/REFACTORING_PREVENTION.md`**
39: (빈 줄)
40: # CTO Code Review & Optimization
```

**변경 후 (줄 10-14)**:
```
10: ---
11: (빈 줄)
12: **품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)
13: (빈 줄)
14: # CTO Code Review & Optimization
```

**수정 후 파일 첫 10줄**:
```
 1: ---
 2: name: cto-review
 3: description: >
 4:   코드베이스 전수 점검 + 최적화 스킬. CTO 도메인별 분석팀을 병렬 투입하여
 5:   파인 코드, 확장성, 모듈화, 마이크로서비스, 성능, 보안, 접근성을 전수 점검하고,
 6:   충돌 제로 Wave 전략으로 수정 에이전트를 투입하여 리팩토링을 수행한다.
 7:   트리거: 전수 점검, 코드 리뷰, 최적화, 파인 코드, 모듈화, 리팩토링,
 8:   CTO 리뷰, 코드 품질, 확장성 점검, 마이크로서비스, 코드 검수,
 9:   fine code, code review, optimization, refactoring
10: ---
```

**줄 수 변화**: 280줄 → 254줄 (-26줄)

---

### 3.5 skills/learn/skill.md

**현재 (줄 8-38)**:
```
 8: ---
 9: (빈 줄)
10: ## 품질 기준 (woojoo-magic 표준)
... (중복 블록 27줄) ...
36: **상세: `../../references/REFACTORING_PREVENTION.md`**
37: (빈 줄)
38: # Learn - 개발 규칙 자동 학습 스킬
```

**변경 후 (줄 8-12)**:
```
 8: ---
 9: (빈 줄)
10: **품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)
11: (빈 줄)
12: # Learn - 개발 규칙 자동 학습 스킬
```

**수정 후 파일 첫 10줄**:
```
 1: ---
 2: name: learn
 3: description: |
 4:   개발 중 발견된 실수, 패턴, 교훈을 개발 규칙 파일과 references에 자동 반영하는 스킬.
 5:   트리거: "기억해", "remember", "learn", "이거 규칙에 추가", "devrule 업데이트", "다음에도 이렇게 해",
 6:   또는 버그 수정/트러블슈팅 완료 후 반복 가능한 교훈이 감지되었을 때 자동 트리거.
 7:   실수를 반복하지 않도록 프로젝트 개발 규칙을 지속적으로 학습·축적하는 시스템.
 8: ---
 9:
10: **품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)
```

**줄 수 변화**: 126줄 → 100줄 (-26줄)

---

### 3.6 skills/ideation/skill.md (특수 처리)

**ideation 특수 처리 이유**:
ideation은 **기획/전략 스킬**이다. PM, UX 리서처, 사업 전략가, 마케터, 데이터 분석가 5명의 전문가 스쿼드를 운영하여 제품 전략을 논의하는 스킬로, **코드를 작성하지 않는다**. 품질 기준 블록의 내용(파일 300줄, `any` 금지, JSX 100줄, tsc, Branded Types 등)은 모두 코드 작성에 관한 것이므로 ideation에는 부적합하다.

**처리 방식**: 중복 블록을 **완전 제거** (포인터도 삽입하지 않음)

**현재 (줄 11-41)**:
```
11: ---
12: (빈 줄)
13: ## 품질 기준 (woojoo-magic 표준)
... (중복 블록 27줄) ...
39: **상세: `../../references/REFACTORING_PREVENTION.md`**
40: (빈 줄)
41: # 아이데이션 스쿼드
```

**변경 후 (줄 11-13)**:
```
11: ---
12: (빈 줄)
13: # 아이데이션 스쿼드
```

**수정 후 파일 첫 10줄**:
```
 1: ---
 2: name: ideation
 3: description: >
 4:   새 기능 기획, 아이데이션, 브레인스토밍, 제품 전략 논의 시 사용.
 5:   PM/UX/사업전략/마케팅/데이터분석 5명의 전문가 스쿼드를 병렬 실행하여
 6:   심층 리서치 후 통합 리포트를 도출하는 스킬.
 7:   트리거: 아이데이션, ideation, 기획, brainstorm, 아이디어, 어떻게 만들까,
 8:   기능 기획, 제품 전략, 새 기능 논의, 전문가 논의, 스쿼드 논의,
 9:   멤버들로 논의, 리서치해줘, 분석해줘, 기획해줘.
10:   코드 구현 전 제품/전략/UX/마케팅 관점의 심층 분석이 필요할 때 트리거.
```

**줄 수 변화**: 88줄 → 60줄 (-28줄, 포인터 줄도 없으므로 -27-1)

---

## 4. 정확한 삭제/교체 문자열

에이전트가 각 파일에서 찾아 교체할 **정확한 old_string → new_string** 쌍이다.

### 4.1 commit, team, cto-review, learn (동일 패턴)

**old_string** (모든 4개 파일에서 동일):
```

## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
- 같은 패턴 2곳 이상 → 공통 유틸 추출
- CSS animation > JS animation (성능)
- Silent catch 금지

### MCP 필수 사용
- **serena**: 코드 탐색/수정 (symbolic tools)
- **context7**: 라이브러리 API 문서 조회
- **sequential-thinking**: 복잡한 리팩토링 계획

### 리팩토링 방지 시그널
파일 작성 중 다음 징후가 보이면 즉시 분할:
- 파일 200줄 돌파 → 300줄 넘기 전에 SRP 기준 분리
- 함수가 3가지 이상 책임 → 분해
- 같은 패턴 2곳 반복 → 공통 유틸
- Props 5개 초과 → 객체 그룹핑

**상세: `../../references/REFACTORING_PREVENTION.md`**

```

**new_string** (commit, team, cto-review, learn):
```

**품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)

```

### 4.2 ideation (특수 처리)

**old_string** (ideation만):
```

## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
- 같은 패턴 2곳 이상 → 공통 유틸 추출
- CSS animation > JS animation (성능)
- Silent catch 금지

### MCP 필수 사용
- **serena**: 코드 탐색/수정 (symbolic tools)
- **context7**: 라이브러리 API 문서 조회
- **sequential-thinking**: 복잡한 리팩토링 계획

### 리팩토링 방지 시그널
파일 작성 중 다음 징후가 보이면 즉시 분할:
- 파일 200줄 돌파 → 300줄 넘기 전에 SRP 기준 분리
- 함수가 3가지 이상 책임 → 분해
- 같은 패턴 2곳 반복 → 공통 유틸
- Props 5개 초과 → 객체 그룹핑

**상세: `../../references/REFACTORING_PREVENTION.md`**

```

**new_string** (ideation만):
```

```

(빈 줄 1개만 남김 — 프론트매터 `---`와 `# 아이데이션 스쿼드` 사이)

---

## 5. 실행 순서

에이전트는 아래 순서로 작업을 수행한다:

1. **SKILL_PREAMBLE.md 생성**: `src/wj-magic/references/common/SKILL_PREAMBLE.md`에 섹션 2.2의 내용을 Write
2. **commit/skill.md 수정**: 섹션 4.1의 old_string → new_string 교체
3. **team/skill.md 수정**: 섹션 4.1의 old_string → new_string 교체
4. **cto-review/skill.md 수정**: 섹션 4.1의 old_string → new_string 교체
5. **learn/skill.md 수정**: 섹션 4.1의 old_string → new_string 교체
6. **ideation/skill.md 수정**: 섹션 4.2의 old_string → new_string 교체

2~5는 동일 패턴이므로 순서 무관. 6은 반드시 다른 new_string 사용.

---

## 6. 의존성

| 파일 | 관계 | 변경 필요 여부 |
|------|------|---------------|
| `references/common/HIGH_QUALITY_CODE_STANDARDS.md` | SKILL_PREAMBLE.md에서 참조 | 불필요 |
| `references/common/REFACTORING_PREVENTION.md` | SKILL_PREAMBLE.md에서 참조 | 불필요 |
| `references/BRANDED_TYPES_PATTERN.md` | SKILL_PREAMBLE.md에서 참조 | 불필요 (경로 유지) |
| `references/RESULT_PATTERN.md` | SKILL_PREAMBLE.md에서 참조 | 불필요 (경로 유지) |
| `references/DISCRIMINATED_UNION.md` | SKILL_PREAMBLE.md에서 참조 | 불필요 (경로 유지) |
| `skills/devrule/skill.md` | 이 블록 **없음** — 변경 불필요 | 불필요 |
| `plugin.json` | 스킬 등록 파일 — 내용 변경 없음 | 불필요 |

---

## 7. 검증 항목

| # | 검증 | 방법 |
|---|------|------|
| 1 | SKILL_PREAMBLE.md 존재 확인 | `test -f src/wj-magic/references/common/SKILL_PREAMBLE.md` |
| 2 | 5개 스킬에서 "## 품질 기준" 문자열 제거 확인 | `grep -l "## 품질 기준" src/wj-magic/skills/*/skill.md` → 결과 없어야 함 |
| 3 | commit, team, cto-review, learn에 포인터 존재 | `grep -l "SKILL_PREAMBLE.md" src/wj-magic/skills/{commit,team,cto-review,learn}/skill.md` → 4개 |
| 4 | ideation에 포인터 **없음** | `grep -c "SKILL_PREAMBLE" src/wj-magic/skills/ideation/skill.md` → 0 |
| 5 | ideation 프론트매터 직후 본문 시작 | `sed -n '12p' src/wj-magic/skills/ideation/skill.md` → 빈 줄, 13번째 줄 → `# 아이데이션 스쿼드` |
| 6 | 경로 참조 정합성 | SKILL_PREAMBLE.md 내 `../../references/` 경로가 스킬 파일 기준으로 유효 (skills/X/ → ../../references/) |
| 7 | devrule 미변경 | `git diff src/wj-magic/skills/devrule/skill.md` → 변경 없음 |

---

## 8. 경로 참조 주의사항

SKILL_PREAMBLE.md 내부의 상대 경로 `../../references/...`는 **스킬 파일 기준**이다:
- 스킬 파일 위치: `skills/commit/skill.md`
- `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md` → `references/common/HIGH_QUALITY_CODE_STANDARDS.md` (정상)

SKILL_PREAMBLE.md 자체 위치(`references/common/`)에서 이 경로를 해석하면 잘못된 위치가 되지만, 이 파일은 AI 에이전트가 Read 도구로 로드하여 스킬 컨텍스트에서 해석하므로 문제없다. **경로를 변경하지 않는다**.
