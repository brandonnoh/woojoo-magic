---
name: devrule
description: >
  규모(S/M/L)에 따라 직접 구현하거나 전문 에이전트 팀에 위임하는 코드 구현 스킬.
  코드를 작성하거나 수정하는 모든 작업에 이 스킬을 사용하라.
  "구현해줘", "만들어줘", "수정해줘", "추가해줘", "고쳐줘", "리팩토링",
  "기능 추가", "버그 수정", "코드 작성", 개발 작업 요청 시 반드시 트리거.
---

## Step -1: Serena/Context7 참조 확인 (HARD GATE — 건너뛸 수 없음)

<HARD-GATE>
코드를 수정하기 전에 반드시 아래를 실행한다. 이 단계를 건너뛰면 2차 버그가 발생한다.
</HARD-GATE>

### Serena 심볼 추적 (수정 대상이 명확할 때)

수정하려는 함수/클래스/변수가 있다면:
1. `find_symbol` — 대상 심볼의 정확한 위치 확인
2. `find_referencing_symbols` — 이 심볼을 참조하는 모든 곳 파악
3. 참조하는 곳이 있으면 → 변경 시 깨지는 곳을 미리 파악

### Context7 문서 조회 (외부 라이브러리 API 사용 시)

라이브러리 API를 호출하는 코드를 작성/수정한다면:
1. `resolve-library-id` — 라이브러리 ID 확인
2. `query-docs` — 해당 API의 현재 문서 조회

### 면제 조건 (이 경우에만 생략 가능)

- 순수 텍스트/설정 파일 (README, JSON config 등) 수정
- 새 파일 생성으로 기존 코드에 참조가 없는 경우
- bash 스크립트 내부 로직만 수정 (심볼 추적 불가)

위 면제에 해당하지 않으면 **반드시** Serena를 사용한다.

---

## Step 0: 언어 감지 + 레퍼런스 로드 (INDEX.md 기반)

코드 작성 전에 **반드시** 아래 순서를 실행한다.

### 0-1. 언어 감지

```bash
# 프로젝트 루트에서 — 존재하는 파일로 언어 판정
ls tsconfig.json package.json pyproject.toml go.mod Cargo.toml Package.swift build.gradle.kts 2>/dev/null || true
ls pnpm-lock.yaml yarn.lock package-lock.json poetry.lock uv.lock go.sum Cargo.lock 2>/dev/null || true
```

### 0-2. INDEX.md 읽기 → 해당 언어 레퍼런스만 로드

**반드시 Read 도구로** 아래 문서를 실제 파일로 읽는다:

1. `references/INDEX.md` — 언어별 레퍼런스 매핑 + 빌드 명령 확인
2. `references/common/HIGH_QUALITY_CODE_STANDARDS.md` — 공통 품질 기준 (필수)
3. 감지된 언어의 standards 파일 (INDEX.md의 "언어별 로드 맵" 참조):
   - TS/JS → `references/typescript/standards.md` + 필요 시 패턴 문서
   - Python → `references/python/standards.md`
   - Go → `references/go/standards.md`
   - Rust → `references/rust/standards.md`
   - Swift → `references/swift/standards.md`
   - Kotlin → `references/kotlin/standards.md`

> **핵심**: 감지된 언어의 레퍼런스만 로드. 전부 읽지 않는다.

---

## Step 2: 규모 판정 → 실행 전략 결정

코드를 직접 쓰기 전에 **반드시** 작업 규모를 판정하고 적절한 실행 전략을 선택한다.

### 규모 판정 기준

| 규모 | 기준 | 실행 전략 |
|------|------|----------|
| **S (Small)** | 단일 파일 또는 파일 1~3개 변경 | Claude 직접 구현 |
| **M (Medium)** | 단일 패키지, 파일 4~10개 또는 테스트 포함 | **전문 에이전트 1개 위임** + QA 리뷰 |
| **L (Large)** | 복수 패키지 또는 파일 10개+ | **팀 에이전트 병렬 위임** + QA 리뷰 |

### 판정 방법

1. 사용자 요청을 분석하여 변경 대상 파일/패키지 범위를 추정
2. Glob/Grep으로 관련 파일 수를 빠르게 스캔
3. 위 기준에 따라 S/M/L 판정

### S 규모: Claude 직접 구현

```
Claude → 코드 작성 → 빌드/테스트 검증 → 완료
```

- 파일 1~3개 수정으로 끝나는 단순 작업
- 에이전트 오버헤드가 더 큰 경우

### M 규모: 전문 에이전트 위임

```
Claude (PM) → 분석 + 프롬프트 작성
  └→ Agent(전문 에이전트) → 구현
       └→ 결과 수신 → Agent(qa-reviewer) → 검수 → 커밋
```

**에이전트 유형 선택:**

| 변경 대상 | 에이전트 | subagent_type (Agent 도구) |
|----------|---------|--------------------------|
| UI, 컴포넌트, 스토어, CSS, 레이아웃 | frontend-dev | `wj-magic:frontend-dev` |
| API, WebSocket, DB, 세션, 인증 | backend-dev | `wj-magic:backend-dev` |
| 도메인 규칙, 타입, 순수 함수, 엔진 | engine-dev | `wj-magic:engine-dev` |
| 디자인 구현, 비주얼, 스타일링, 애니메이션 | design-dev | `wj-magic:design-dev` (**새 UI 작업 시 반드시 `wj:design` 스킬 먼저 호출**) |
| 디자인 리뷰, 시각 품질 검증, Anti-Slop | design-reviewer | `wj-magic:design-reviewer` |
| 보안 감사, OWASP, 취약점 검증 | security-auditor | `wj-magic:security-auditor` |
| 테스트 설계, 커버리지 보강, 엣지케이스 | test-engineer | `wj-magic:test-engineer` |
| 문서 동기화, LESSONS, progress | docs-keeper | `wj-magic:docs-keeper` |

**에이전트 프롬프트에 반드시 포함:**
- 수락 조건 (사용자 요청에서 추출)
- 소유 파일 범위
- 프로젝트 기술 스택 (Step 0에서 감지한 결과)
- git commit 금지 (Claude가 커밋)

### L 규모: 팀 에이전트 병렬 위임

```
Claude (PM)
  ├→ Agent(engine-dev, isolation: "worktree", run_in_background: true)
  ├→ Agent(backend-dev, isolation: "worktree", run_in_background: true)
  └→ Agent(frontend-dev, isolation: "worktree", run_in_background: true)
       ↓ 전체 완료 대기
  └→ Agent(test-engineer) → 테스트 보강
  └→ Agent(security-auditor) + Agent(qa-reviewer) → 병렬 검수 → 커밋
```

**L 규모 필수 규칙:**
- 파일 소유권 엄격 분리 — 같은 파일을 2개 에이전트가 수정 금지
- `isolation: "worktree"` 필수 — 충돌 방지
- `run_in_background: true` — 병렬 실행
- 의존 순서가 있으면 (engine → backend → frontend) 순차 실행

### Claude의 역할: PM/오케스트레이터 (M/L 규모)

M/L 규모에서 Claude는 **직접 코드를 작성하지 않는다:**
- 분석, 에이전트 프롬프트 작성, 위임, 결과 검수, 커밋만 수행
- 모든 구현은 전문 에이전트에게 위임
- 에이전트 결과를 QA 리뷰어에게 검수 위임
- 최종 커밋은 Claude가 직접 수행

---

## Step 3: 품질 기준 Quick Reference (INDEX.md에서 발췌)

### 공통 (언어 불문)
- Cyclomatic Complexity ≤ 10 / 같은 ���턴 2곳 → 추출 / Silent error ��지 / 타입 회피 금지 / 불변 기본

### 언어별 Hard Limits

| 언어 | 파일 | 함수 | 금지 패턴 |
|------|------|------|----------|
| **TypeScript** | 300줄 | 20줄 | `any`, `!`, `as` 남용, silent catch |
| **Python** | 600줄 | 50줄 | `Any`, bare `except:`, `except: pass` |
| **Go** | 500줄 | 40줄 | `interface{}`, `_ = err`, `panic()` |
| **Rust** | 500줄 | 40줄 | `unwrap()`, `unsafe` 남용, `clone()` 남용 |
| **Swift** | 400줄 | 30줄 | force unwrap `!`, `Any`, `try!`, `as!` |
| **Kotlin** | 400줄 | 30줄 | `!!`, `Any`, `var` 남용, `GlobalScope` |

> 상세 규칙은 각 ���어의 `references/<lang>/standards.md` 참조.

---

## Step 4: 작업 순서

1. **먼저 읽는다** — 관련 파일을 읽고 현재 구조 확인
   - **새 UI/페이지/컴포넌트 생성이 포함된 작업이면**: 구현 전 반드시 `wj:design` 스킬 호출 → 디자인 방향·와이어프레임 확정 후 진행 (기존 UI 수정은 `wj:polish`)
2. **영향 범위를 본다** — 프론트엔드/백엔드/공유 패키지 어디까지 번지는지
3. **기준점 하나로 통일** — 중복 로직 만들지 않고 공유 패키지 기준
4. **규모에 맞게 실행** — S: 직접 구현 / M: 에이전트 위임 / L: 팀 병렬 위임 (Step 2 참조)
5. **빌드/테스트로 검증** — 감지된 패키지 매니저로 빌드·테스트 실행
6. **테스트 보강** — M/L 규모는 `Agent(subagent_type: "wj-magic:test-engineer")`로 커버리지 보강
7. **디자인 리뷰 + 보안 감사 + QA 리뷰** — UI 변경 시 `Agent(wj-magic:design-reviewer)` + 보안 변경 시 `Agent(wj-magic:security-auditor)` + `Agent(wj-magic:qa-reviewer)` 병렬 검수
8. **커밋** — `/wj:commit` 스킬 규칙으로 한글 메시지 작성
9. **docs-keeper 투입** — 구조 변경 시 `Agent(subagent_type: "wj-magic:docs-keeper")` 투입 (아래 기준 참조)
9. **학습 피드백** — QA FAIL 원인이 컨벤션 위반이거나 같은 실수 2회+ 시 `/wj:learn` 호출

### docs-keeper 투입 기준

다음 중 하나 이상이면 **필수 투입**:
- 새 공개 파일 3개+ 생성 또는 공개 API 시그니처 변경
- 아키텍처/디렉토리 구조 변경

다음이면 **생략 가능**:
- 기존 파일 내부 수정만 (구조 불변)
- 테스트 파일만 추가/수정

```
Agent(subagent_type: "wj-magic:docs-keeper", run_in_background: true, model: "sonnet")
→ 문서 동기화 + CLAUDE.md/ARCHITECTURE.md 반영
```

### learn 스킬 자동 트리거 기준

다음 상황에서 `/wj:learn` 스킬을 호출하여 교훈을 규칙에 축적:
- QA 리뷰 FAIL 원인이 프로젝트 컨벤션 위반일 때
- 같은 유형의 실수가 세션 내 2회 이상 발생했을 때
- 트러블슈팅 완료 후 교훈이 프로젝트 전반에 적용 가능할 때

### MCP 필수 사용
- **context7**: 라이브러리 API 문서 조회 (공식 문서 우선)
- **sequential-thinking**: 복잡한 리팩토링 계획 수립

### 리팩토링 방지 시그널
파일 작성 중 다음 징후가 보이면 즉시 분할:
- 파일이 soft limit 2/3 돌파 → 300줄(TS) / 400줄(Python) 넘기 전에 SRP 기준 분리
- 함수가 3가지 이상 책임 → 분해
- 같은 패턴 2곳 반복 → 공통 유틸
- Props/매개변수 5개 초과 → 객체 그룹핑

---

## 구조 원칙

### 공유 모듈이 단일 진실 공급원
- 핵심 비즈니스 로직과 공용 타입은 공유 패키지(shared)가 단일 진실 공급원
- 프론트엔드와 백엔드는 공유 패키지가 정의한 타입과 로직을 소비
- 같은 개념을 프론트엔드와 백엔드가 각각 다시 계산하지 않는다

### 패키지별 책임

| 패키지 | 책임 | 하지 말 것 |
|--------|------|-----------|
| `shared` | 비즈니스 로직, 공용 타입, 메시지 계약 | IO, 사이드 이펙트, 외부 의존 |
| `client` | 렌더링, 입력, 연출, 로컬 UI 상태 | 비즈니스 로직 재해석, 상태 중복 |
| `server` | authoritative state, 세션, 인증 | 클라이언트 전용 로직 |

---

## 코드 작성 원칙

- 이름만 보고 추측하지 않는다 — 선언부와 문서 확인
- 삭제된 구조를 기준으로 짜지 않는다 — 현재 코드베이스가 기준
- 기능 추가보다 구조 붕괴 방지가 우선
- 타입은 실제 소스 기준 — 예전 예시 코드 복붙 금지
- 현재 없는 인프라를 있는 것처럼 가정하지 않는다

### 레이아웃 변경 시 반드시 사전 검증 (프론트엔드)
1. 높이 예산 계산
2. 자식 컴포넌트 크기 제약 확인
3. absolute/fixed 요소 확인
4. flex 축 확인
5. 한 컴포넌트씩 패치하지 말 것 — 전체 레이아웃을 한 번에 설계

---

## 한 문장 결론

현재 코드의 진실을 먼저 존중하고, 공유 패키지 중심의 구조를 유지하면서, 기능 추가보다 구조 붕괴 방지를 우선하는 것이 좋은 개발이다.
