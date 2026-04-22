---
name: team
description: (wj-magic) 팀 구성, 에이전트, 전문가, 스웜, 병렬 작업, 부서 투입 등의 키워드 시 사용. agents.md 조직도를 참조하여 적절한 전문가 에이전트를 선별하고 TeamCreate + Task 도구로 병렬 팀 작업을 수행. "팀 구성해줘", "에이전트 소환", "전문가 투입", "QA 돌려줘", "보안 점검", "SEO 분석", "성능 최적화", "개발팀 소환", "운영팀 투입" 등의 요청에 트리거.
---

**품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)

# Team Assembly & Execution

## When to use this skill

사용자가 팀, 에이전트, 전문가 등을 언급하며 멀티 에이전트 협업 작업을 요청할 때.
또한 `/devrule` 스킬의 Step 0(팀 기반 개발 프로세스)에서 자동 호출됨.

## References

- [agents.md](references/agents.md) - 전체 조직도, 부서별 인원, 역할 정의, 투입 계획, 의존성 그래프

## Workflow

### Phase 1: 분석 (Claude = PM)
1. **관련 파일 전수 읽기** — 변경 대상 파일을 직접 Read로 분석
2. **나노 단위 과업 도출** — 50개 이상, 심각도별(CRITICAL/HIGH/MEDIUM/LOW) 분류
3. **파일:라인 수준 이슈 명세** — 각 과업에 파일명, 라인 번호, 문제 원인, 수정 방향 명시

### Phase 2: 리뷰 에이전트 투입 (선택)
1. 전문가별 리뷰 에이전트 `run_in_background: true`로 병렬 투입
2. 리뷰 결과 수집 → 추가 과업 도출
3. 리뷰 에이전트 shutdown

### Phase 3: 구현 에이전트 투입
1. **파일 소유권 기준 워크스트림 분리** — 같은 파일을 2개 에이전트가 수정하지 않도록 엄격 분리
2. **TeamCreate** → **TaskCreate** (과업 등록 + 의존성 설정)
3. **에이전트 병렬 투입** — `isolation: "worktree"` + `mode: "bypassPermissions"` + `run_in_background: true`
4. 각 에이전트 프롬프트에 소유 파일 목록 + 태스크 목록 + CLAUDE.md 규칙 포함
5. 완료 보고 수신 → TaskUpdate → shutdown_request

### Phase 4: CTO 리뷰
1. **CTO 리뷰 에이전트** 투입 — 모든 워크트리 변경 검수
2. 검수 항목: CLAUDE.md 준수, 보안, 코드 품질, 워크트리 간 호환성
3. 릴리즈 판정: PASS / 조건부 PASS / FAIL
4. 이슈 발견 시 수정 에이전트 재투입

### Phase 5: 머지 & 커밋
1. 워크트리 결과물을 main에 머지
2. 사용자에게 최종 결과 요약 보고

## Agent Mapping

조직도의 에이전트 → Task 도구 subagent_type 매핑:

| 부서 | 에이전트 | subagent_type | mode |
|------|---------|---------------|------|
| 개발팀 | frontend-dev (프론트엔드, client/) | `general-purpose` | `bypassPermissions` |
| 개발팀 | backend-dev (API/실시간 서버, server/) | `general-purpose` | `bypassPermissions` |
| 개발팀 | specialist-dev (특수 기술 담당, 프로젝트별 정의) | `general-purpose` | `bypassPermissions` |
| 개발팀 | fullstack-dev (공유 모듈, shared/) | `general-purpose` | `bypassPermissions` |
| 운영팀 | security-reviewer | `general-purpose` | `default` |
| 운영팀 | tester (QA) | `general-purpose` | `bypassPermissions` |
| 운영팀 | perf-analyst | `Explore` | `default` |
| 세일즈팀 | enterprise-sales | `general-purpose` | `default` |
| 세일즈팀 | partnership-manager | `general-purpose` | `default` |
| 세일즈팀 | growth-hacker | `general-purpose` | `default` |
| 세일즈팀 | customer-success | `general-purpose` | `default` |
| 세일즈팀 | sales-engineer | `general-purpose` | `default` |
| 마케팅팀 | seo-specialist | `Explore` | `default` |
| 마케팅팀 | content-creator | `general-purpose` | `default` |
| 사업팀 | biz-strategist | `Plan` | `default` |
| 기획팀 | product-manager | `Plan` | `default` |

## Prompt Template

각 에이전트에게 전달할 프롬프트 구조:

```
[{역할}] 전문가로서 다음 작업을 수행해줘.

## 프로젝트 컨텍스트
- 프로젝트의 기술 스택과 구조를 포함
- (CLAUDE.md 또는 프로젝트 문서에서 기술 스택, 아키텍처, 디렉토리 구조를 참조하여 기입)

## 작업
{구체적 작업 내용}

## 참조
{관련 파일/리포트 경로}

## 산출물
{기대하는 결과물 형식}
```

## Execution Rules

### Claude의 역할: PM/매니저 전용
- **Claude는 직접 코드를 수정하지 않는다** — 분석 + 과업 도출 + 에이전트 관리만 수행
- 모든 코드 수정은 워크트리 격리된 전문가 에이전트에게 위임

### 에이전트 운영
1. 구현 에이전트: `isolation: "worktree"` + `mode: "bypassPermissions"` + `run_in_background: true`
2. 리서치/분석 에이전트: `run_in_background: true` (워크트리 불필요)
3. 의존성이 있는 작업은 `TaskUpdate`의 `addBlockedBy`로 순서 보장
4. **파일 소유권 엄격 분리** — 동일 파일을 2개 에이전트가 수정 금지 (충돌 방지)
5. 에이전트 완료 시 즉시 `TaskUpdate` → `shutdown_request`
6. 전체 완료 후 **CTO 리뷰 에이전트** 필수 투입 (코드 검수 + 릴리즈 판정)

### 과업 관리
- 심각도: CRITICAL / HIGH / MEDIUM / LOW
- 과업 명명: `[심각도-카테고리-번호] 제목` (예: `[CRITICAL-AUTH-1] init()에서 ...`)
- 각 과업에 파일명, 라인 번호, 문제 원인, 수정 방향 포함
- 목표: 나노 단위 분석으로 50개+ 과업 도출

## 개발 규칙 연동

`/devrule` 스킬의 Step 0에서 팀 기반 개발을 요구할 때, 이 스킬의 워크플로우를 따름:
1. PM이 문제 정의 → 토론 진행
2. 토론 결과에 따라 적절한 에이전트 조합 선별
3. 기획 → 설계 → 개발 → QA → 보안 파이프라인 실행
