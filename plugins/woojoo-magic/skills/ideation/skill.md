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

## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../shared-references/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../shared-references/BRANDED_TYPES_PATTERN.md`
- Result<T,E> 패턴으로 에러 처리 — `../../shared-references/RESULT_PATTERN.md`
- Discriminated Union으로 상태 모델링 — `../../shared-references/DISCRIMINATED_UNION.md`
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

**상세: `../../shared-references/REFACTORING_PREVENTION.md`**

# 아이데이션 스쿼드

5명의 전문가 에이전트를 병렬 실행하여 새 기능/전략에 대한 심층 리서치를 수행하고 통합 스펙을 도출한다.

## 워크플로우

### Step 1: 주제 확인
ARGUMENTS가 제공되면 바로 사용. 없으면 사용자에게 기획 주제를 확인.

### Step 2: 스쿼드 병렬 실행
[references/squad.md](references/squad.md) 참조하여 5개 에이전트를 `run_in_background: true`로 동시 실행.

| # | 역할 | subagent_type | 핵심 임무 |
|---|------|---------------|----------|
| 1 | PM | general-purpose | 경쟁사 벤치마크, IA 설계, 로드맵 |
| 2 | UX 리서처 | general-purpose | 사용자 심리학, 동기부여, 윤리적 설계 (논문 인용 필수) |
| 3 | 사업 전략가 | general-purpose | 수익화 모델, 전환 퍼널, ROI |
| 4 | 마케터 | general-purpose | SEO, 커뮤니티 마케팅, 콘텐츠 전략, 리텐션 |
| 5 | 데이터 분석가 | Explore | 코드베이스 분석, 기술 아키텍처 |

프롬프트 필수 포함 사항:
- 프로젝트 컨텍스트 (프로젝트의 도메인, 기술 스택, 수익 모델, 타겟 유저 등 핵심 정보를 포함)
- "코드 변경은 하지 마. 리서치와 분석만 수행."
- "웹 검색을 적극 활용하여 최신 데이터 수집"
- 역할별 상세 리서치 과제 (squad.md의 리서치 범위 참조)

### Step 3: 진행 상황 보고
에이전트 완료 시마다 사용자에게 진행 상황 테이블 업데이트.

### Step 4: 통합 리포트
전원 완료 후 합성:

```
# [기능명] 통합 아이데이션 리포트

## 스쿼드 컨센서스 요약 (테이블)
## 최종 스펙 (PM+UX 합의 기반)
## 설계 원칙 (UX 도출, 심리학 근거)
## 수익화 전략 (사업 전략가 추천 모델 + 근거)
## 플랫폼/인프라 전략 (프로젝트 기술 스택 활용 방안)
## 기술 아키텍처 (데이터 분석가 도출)
## 마케팅 전략 요약 (마케터 핵심만)
## 법적/규제 고려사항 (해당 도메인 관련 규제 분석)
## MVP 로드맵 (Phase별)
```

### Step 5: 사용자 확인
통합 리포트 제시 후 개발 진행 여부 확인.
