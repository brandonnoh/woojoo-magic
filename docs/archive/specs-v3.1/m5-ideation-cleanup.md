# m5-ideation-cleanup: ideation 스킬에서 불필요한 코드 품질 블록 제거

> 우선순위: MEDIUM  
> 예상 작업량: ~5분, 28줄 삭제  
> 의존성: 없음 (독립 작업)

## 1. 현황 분석

`skills/ideation/skill.md`는 **아이데이션/기획 전용 스킬**이다.
PM, UX, 사업전략, 마케팅, 데이터분석 전문가 스쿼드를 병렬 실행하여 리서치를 수행한다.

그런데 파일에 **코드 품질 기준 블록** (13-39줄)이 포함되어 있다:
- TS/JS 코딩 규칙 (300줄 제한, any 금지, !. 금지 등)
- MCP 도구 사용법 (serena, context7)
- 리팩토링 방지 시그널

이것은 **코드 구현 스킬(devrule 등)에 속하는 내용**으로, 아이데이션 스킬과 무관하다.
아이데이션 스킬은 코드를 작성하지 않고 리서치와 분석만 수행하므로, 이 블록은 **컨텍스트 낭비**이자 **에이전트 혼란 요인**이다.

## 2. 제거 대상: 정확한 범위

**파일:** `src/wj-magic/skills/ideation/skill.md`

**제거 범위:** 12줄 ~ 40줄 (빈 줄 포함 29줄)

```markdown
12:
13: ## 품질 기준 (woojoo-magic 표준)
14:
15: **반드시 참조: `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md`**
16:
17: ### 핵심 규칙
18: - 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
19: - `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
20: - Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
21: - Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
22: - Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
23: - 같은 패턴 2곳 이상 → 공통 유틸 추출
24: - CSS animation > JS animation (성능)
25: - Silent catch 금지
26:
27: ### MCP 필수 사용
28: - **serena**: 코드 탐색/수정 (symbolic tools)
29: - **context7**: 라이브러리 API 문서 조회
30: - **sequential-thinking**: 복잡한 리팩토링 계획
31:
32: ### 리팩토링 방지 시그널
33: 파일 작성 중 다음 징후가 보이면 즉시 분할:
34: - 파일 200줄 돌파 → 300줄 넘기 전에 SRP 기준 분리
35: - 함수가 3가지 이상 책임 → 분해
36: - 같은 패턴 2곳 반복 → 공통 유틸
37: - Props 5개 초과 → 객체 그룹핑
38:
39: **상세: `../../references/REFACTORING_PREVENTION.md`**
40:
```

## 3. 의존성 확인

### 3.1 제거 블록이 참조하는 외부 파일

- `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md`
- `../../references/BRANDED_TYPES_PATTERN.md`
- `../../references/RESULT_PATTERN.md`
- `../../references/DISCRIMINATED_UNION.md`
- `../../references/REFACTORING_PREVENTION.md`

이 파일들은 다른 스킬(devrule, senior-frontend 등)에서도 참조하므로 **삭제 대상이 아니다**.
ideation skill.md에서 참조를 제거하는 것만으로 충분하다.

### 3.2 파일 내 다른 부분의 의존성

41줄부터의 "아이데이션 스쿼드" 섹션을 확인:
- 51줄: `[references/squad.md](references/squad.md)` — 품질 기준과 무관
- 62줄: "프로젝트 컨텍스트" — 품질 기준과 무관
- 63줄: "코드 변경은 하지 마. 리서치와 분석만 수행." — **이 문구가 코드 품질 블록의 불필요함을 명시적으로 확인**

**결론: 파일 내 다른 부분이 제거 대상 블록을 참조하지 않음. 안전하게 제거 가능.**

## 4. 제거 후 파일 모습 (1-20줄)

```markdown
---
name: ideation
description: >
  새 기능 기획, 아이데이션, 브레인스토밍, 제품 전략 논의 시 사용.
  PM/UX/사업전략/마케팅/데이터분석 5명의 전문가 스쿼드를 병렬 실행하여
  심층 리서치 후 통합 리포트를 도출하는 스킬.
  트리거: 아이데이션, ideation, 기획, brainstorm, 아이디어, 어떻게 만들까,
  기능 기획, 제품 전략, 새 기능 논의, 전문가 논의, 스쿼드 논의,
  멤버들로 논의, 리서치해줘, 분석해줘, 기획해줘.
  코드 구현 전 제품/전략/UX/마케팅 관점의 심층 분석이 필요할 때 트리거.
---

# 아이데이션 스쿼드

5명의 전문가 에이전트를 병렬 실행하여 새 기능/전략에 대한 심층 리서치를 수행하고 통합 스펙을 도출한다.

## 워크플로우

### Step 1: 주제 확인
ARGUMENTS가 제공되면 바로 사용. 없으면 사용자에게 기획 주제를 확인.
```

## 5. 구체적 편집 작업

**삭제할 텍스트** (12줄의 빈 줄부터 40줄의 빈 줄까지):

```
(12줄 빈줄)
## 품질 기준 (woojoo-magic 표준)
(빈줄)
**반드시 참조: `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md`**
(빈줄)
### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
- 같은 패턴 2곳 이상 → 공통 유틸 추출
- CSS animation > JS animation (성능)
- Silent catch 금지
(빈줄)
### MCP 필수 사용
- **serena**: 코드 탐색/수정 (symbolic tools)
- **context7**: 라이브러리 API 문서 조회
- **sequential-thinking**: 복잡한 리팩토링 계획
(빈줄)
### 리팩토링 방지 시그널
파일 작성 중 다음 징후가 보이면 즉시 분할:
- 파일 200줄 돌파 → 300줄 넘기 전에 SRP 기준 분리
- 함수가 3가지 이상 책임 → 분해
- 같은 패턴 2곳 반복 → 공통 유틸
- Props 5개 초과 → 객체 그룹핑
(빈줄)
**상세: `../../references/REFACTORING_PREVENTION.md`**
(빈줄)
```

위 블록을 **빈 줄 하나**로 교체한다.

## 6. 줄 수 변화

- Before: 89줄
- After: 60줄 (29줄 삭제)

## 7. 테스트 계획

- `skill.md`의 YAML frontmatter가 유효한지 확인 (name, description 필드 존재)
- `# 아이데이션 스쿼드` 섹션이 정상적으로 시작하는지 확인
- ideation 스킬 트리거 시 정상 동작 확인

## 8. 파일 변경 요약

| 파일 | 동작 |
|------|------|
| `src/wj-magic/skills/ideation/skill.md` | 12-40줄 (품질 기준 블록) 삭제 |
