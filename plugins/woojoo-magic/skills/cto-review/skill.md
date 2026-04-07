---
name: cto-review
description: >
  코드베이스 전수 점검 + 최적화 스킬. CTO 도메인별 분석팀을 병렬 투입하여
  파인 코드, 확장성, 모듈화, 마이크로서비스, 성능, 보안, 접근성을 전수 점검하고,
  충돌 제로 Wave 전략으로 수정 에이전트를 투입하여 리팩토링을 수행한다.
  트리거: 전수 점검, 코드 리뷰, 최적화, 파인 코드, 모듈화, 리팩토링,
  CTO 리뷰, 코드 품질, 확장성 점검, 마이크로서비스, 코드 검수,
  fine code, code review, optimization, refactoring
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

# CTO Code Review & Optimization

도메인별 CTO 분석팀을 병렬 투입하여 전체 코드베이스를 전수 점검하고,
충돌 제로 Wave 전략으로 자동 리팩토링을 수행하는 스킬.

## When to use this skill

- 코드베이스가 일정 규모 이상 쌓였을 때 전수 품질 점검
- 새로운 Phase 진입 전 기존 코드 안정화
- 기술 부채 청산
- 프로덕션 배포 전 최종 검수
- "파인 코드", "최적화", "모듈화", "리팩토링" 등 키워드

## References

- [review-checklist.md](references/review-checklist.md) — 도메인별 점검 항목, 이슈 분류 체계, Wave 전략 상세

## Critical Rules

### MCP 기반 분석 우선 (최우선 규칙)

**모든 CTO 분석 에이전트는 반드시 다음 MCP 도구를 활용하여 점검한다:**

1. **Context7** (`mcp__context7__resolve-library-id` → `mcp__context7__query-docs`)
   - 프로젝트에서 사용하는 라이브러리의 **최신 공식 문서**를 조회하여 deprecated API, 안티패턴 사용 여부를 점검
   - 예: React 18 훅 규칙, Zustand v5 패턴, Framer Motion 최신 API, Zod v4 변경점 등
   - "이미 아는 내용"이라도 반드시 최신 문서와 대조 확인

2. **Serena** (`mcp__serena__find_symbol`, `mcp__serena__get_symbols_overview`, `mcp__serena__find_referencing_symbols`)
   - 코드 분석 시 **심볼 의존성 그래프**를 반드시 조회
   - 수정 대상 함수/컴포넌트를 참조하는 모든 파일을 확인하여 영향 범위 파악
   - 순환 참조, 미사용 export, 깨진 의존성 탐지에 활용

**CTO 분석 에이전트 프롬프트에 반드시 포함:**
```
## MCP 도구 활용 (필수)
- Context7으로 사용 중인 라이브러리 최신 문서를 조회하여 deprecated/안티패턴 점검
- Serena로 심볼 의존성을 분석하여 영향 범위 파악 및 순환 참조 탐지
이 규칙을 건너뛰면 안 된다. "이미 알고 있는 내용"이라도 반드시 확인한다.
```

---

## Workflow

### Phase 1: 코드베이스 스캔 (Claude = PM)

Claude가 직접 수행:

```bash
# 1. 전체 규모 파악
find src/ -name "*.ts" -o -name "*.tsx" | wc -l
find src/ -name "*.ts" -o -name "*.tsx" | xargs wc -l | tail -1

# 2. 200줄 이상 파일 식별 (리팩토링 대상)
find src/ -name "*.ts" -o -name "*.tsx" | xargs wc -l | sort -rn | awk '$1 >= 200'

# 3. 도메인별 줄 수
```

### Phase 2: 도메인 분할 & CTO 분석팀 편성

프로젝트 구조를 분석하여 **파일 소유권이 겹치지 않는** 도메인으로 분할한다.

**분할 원칙:**
- 패키지/폴더 단위로 분할 (모노레포: 패키지별, 단일 프로젝트: 레이어별)
- 한 파일을 2개 팀이 동시에 분석하지 않도록 엄격 분리
- 공유 의존성(types, utils)은 기반 도메인에 할당

**일반적인 분할 예시:**

| 도메인 | 대상 | CTO 역할 |
|--------|------|----------|
| Core/Engine | 비즈니스 로직, 공유 타입, 유틸 | CTO-1: 엔진 아키텍트 |
| Frontend | UI 컴포넌트, 상태 관리, 페이지 | CTO-2: 프론트엔드 리드 |
| Backend | API, 서버, DB, 인증 | CTO-3: 백엔드 리드 |
| DX/Infra | 빌드, CI/CD, 린팅, 설정, 문서 | CTO-4: DX 엔지니어 |

프로젝트 규모에 따라 2~6팀으로 조절.

### Phase 3: CTO 분석팀 병렬 투입

각 CTO 에이전트를 `run_in_background: true`로 동시 실행.

**프롬프트 필수 포함:**
```
[CTO - {도메인}] 전문가로서 {폴더}의 코드 품질을 전수 점검해줘.
코드 변경은 하지 마. 분석과 개선 플랜만 수행.

## MCP 도구 활용 (필수)
- Context7으로 사용 중인 라이브러리 최신 문서를 조회하여 deprecated/안티패턴 점검
- Serena로 심볼 의존성을 분석하여 영향 범위 파악 및 순환 참조 탐지
이 규칙을 건너뛰면 안 된다. "이미 알고 있는 내용"이라도 반드시 확인한다.

## 분석 범위
{소유 파일 목록}

## 점검 항목
{review-checklist.md의 해당 도메인 체크리스트}

## 산출물
1. 이슈 목록 [심각도-카테고리-번호] 형식 (최소 20개)
2. 리팩토링 우선순위 매트릭스 (영향도 x 복잡도)
3. 구체적 리팩토링 플랜 (파일별 변경 사항)
```

### Phase 4: 이슈 통합 & 우선순위 매트릭스

전원 완료 후 합성:

1. **중복 이슈 제거** — 여러 CTO가 동일 이슈를 다른 관점에서 보고할 수 있음
2. **심각도 정렬** — CRITICAL > HIGH > MEDIUM > LOW
3. **Quick Win 식별** — 낮은 노력 + 높은 영향도
4. **현 Phase에서 수정 가능한 이슈만 선별** — 미래 기능(서버, 인증 등)은 백로그

```
통합 결과 테이블:
| 도메인 | CRITICAL | HIGH | MEDIUM | LOW | 합계 |
```

### Phase 5: 충돌 제로 Wave 전략 수립

**핵심 원칙: 같은 파일을 2개 에이전트가 동시에 수정하지 않는다.**

**Wave 분할 규칙:**
1. **의존성 방향 파악** — A가 B를 import하면, A를 먼저 수정
2. **기반 패키지 먼저** — shared/types 등 다른 패키지가 의존하는 코드를 Wave 1에
3. **독립 패키지는 병렬** — 서로 import하지 않는 패키지는 같은 Wave에서 병렬 실행

**일반적인 Wave 구성:**
```
Wave 1: 기반 패키지 (shared, types, utils) — 단독 실행
         ↓ (머지 후)
Wave 2: 앱 패키지들 병렬 실행
         ├── frontend (client/)
         ├── backend (server/)
         └── infra (config, CI/CD)
```

### Phase 6: 수정 에이전트 투입

각 Wave의 에이전트를 `isolation: "worktree"` + `run_in_background: true`로 투입.

**프롬프트 필수 포함:**
```
## 소유 파일 (이 파일들만 수정/생성/삭제 가능)
{파일 목록}

⚠️ 절대 건드리면 안 되는 파일: {다른 Wave/팀의 파일}

## 수정 태스크 (우선순위순)
{CTO 리뷰에서 도출된 이슈 목록}

## 코드 규칙
- TypeScript strict, any/as/! 사용 금지
- 각 파일 200줄 이내 목표
- 수정 후 빌드/테스트 통과 필수
```

### Phase 7: 순차 머지 & 검증

1. Wave 1 워크트리 커밋 → main 머지 → 테스트 확인
2. Wave 2 워크트리들 각각 커밋 → main에 순차 머지 (충돌 발생 시 수동 해결)
3. 전체 테스트 실행
4. 푸쉬

### Phase 8: 리포트 저장 & 커밋 (자동)

**분석 완료 후 자동으로 실행:**

1. `docs/CTO_REVIEW_REPORT.md`에 통합 리포트 저장
   - 도메인별 이슈 수 테이블
   - CRITICAL 이슈 전체 목록
   - HIGH 상위 10개
   - 긍정적 평가
   - Wave 1~4 수정 전략
2. `git add && git commit && git push`
3. **사용자에게 묻기**: "Wave 1 수정 에이전트를 투입할까요?"
   - Yes → Phase 5~7 진행 (충돌 제로 Wave 전략 → 수정 에이전트 → 머지)
   - No → 리포트만 저장하고 종료

### Phase 9: 워크트리 정리 (수정 진행 시)

```bash
# 모든 워크트리 삭제
for wt in .claude/worktrees/agent-*; do
  git worktree remove "$wt" --force
done

# 워크트리 브랜치 삭제
for br in $(git branch | grep worktree-agent); do
  git branch -D $br
done
```

## 이슈 분류 체계

### 심각도
| 레벨 | 의미 | 예시 |
|------|------|------|
| **CRITICAL** | 즉시 수정 필수, 기능/보안에 직접 영향 | 런타임 크래시, 보안 취약점, 데이터 손실 |
| **HIGH** | 빠른 시일 내 수정 권장, 품질에 큰 영향 | God Object, 메모리 누수, 성능 병목 |
| **MEDIUM** | 기회가 되면 개선, 유지보수성 향상 | 중복 코드, 매직 넘버, 느슨한 타입 |
| **LOW** | 코드 품질 향상, 선택적 | 네이밍 일관성, 주석 누락, 미사용 코드 |

### 카테고리
| 코드 | 의미 |
|------|------|
| ARCH | 아키텍처 / 구조 |
| QUAL | 코드 품질 |
| PERF | 성능 |
| SEC | 보안 |
| MOD | 모듈화 |
| EXT | 확장성 |
| A11Y | 접근성 |
| TEST | 테스트 |
| DX | 개발자 경험 |
| OPS | 운영 |

### 이슈 ID 형식
```
[심각도-카테고리-번호] 파일명:라인 — 문제 설명
  수정 방향: ...
```

### 서비스 레이어 점검
- [ ] 비즈니스 로직이 서비스 모듈에 분리되어 있는가?
- [ ] Store가 얇은 레이어 역할만 하는가?
- [ ] 도메인별 전담 서비스가 존재하는가? (예: UserService, OrderService)
- [ ] 서비스 함수가 순수 함수인가? (사이드 이펙트 없음)
- [ ] 서비스 간 의존성이 단방향으로 유지되는가?

## 실행 규칙

1. **Claude = PM** — 분석 지시 + 이슈 통합 + Wave 설계 + 에이전트 관리
2. **분석 에이전트**: `run_in_background: true` (워크트리 불필요)
3. **수정 에이전트**: `isolation: "worktree"` + `run_in_background: true`
4. **파일 소유권 엄격 분리** — 동일 파일을 2개 에이전트가 수정 금지
5. **Wave 간 머지 필수** — Wave N 머지 후 Wave N+1 시작
6. **테스트 통과 필수** — 각 Wave 머지 후 전체 테스트 실행
7. **워크트리 정리** — 모든 작업 완료 후 워크트리 + 브랜치 삭제
