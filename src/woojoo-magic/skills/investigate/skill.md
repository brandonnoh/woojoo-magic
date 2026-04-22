---
description: (wj-magic) 버그·성능·보안·아키텍처 심층 조사 (5 에이전트 팀 + 웹 리서치 + 자동 수정)
---

# /wj:investigate — 국정조사급 심층 이슈 분석

버그, 성능 저하, 보안 취약점, 아키텍처 문제 — 어떤 이슈든 5개 전문 에이전트 팀을
총동원해 근본 원인을 밝히고 수정까지 완료한다.

**대규모 토큰 사용은 의도된 설계다. 두렵지 않게 실행하라.**

<HARD-GATE>
Phase 1 (5개 에이전트 병렬 조사) 완료 전 수정 금지.
"빠르게 고치고 나중에 조사"는 금지. 반드시 근본 원인 확인 후 수정한다.
</HARD-GATE>

## 트리거

다음 상황에서 즉시 이 스킬을 사용한다:

```
"버그", "조사해줘", "분석해줘", "investigate", "확인해줘", "원인 찾아줘",
"안된다", "느려", "보안", "왜 이게", "뭐가 문제", "이슈", "에러",
"테스트 실패", "충돌", "성능 저하", "취약점", "이상함", "예상과 다름"
```

## 토큰 예산

| Phase | 예상 토큰 |
|-------|---------|
| Phase 0 (트리아지) | ~500 |
| Phase 1 (5 에이전트 × 2,000-4,000) | ~10,000–20,000 |
| Phase 2 (Sequential Thinking 7단계) | ~3,000–5,000 |
| Phase 3 (수정 구현, M 기준) | ~5,000–10,000 |
| Phase 4-5 (검증 + 리포트) | ~2,000 |
| **전체 예상** | **~20,000–40,000** |

## 선택적 MCP (설치 시 자동 활성화)

현재 사용 가능한 MCP 외에 다음을 설치하면 조사 품질이 크게 향상된다:

```
🔌 추천 추가 MCP:
- Sentry MCP (npx @sentry/mcp-server): 프로덕션 에러 데이터 자동 수집
- GitHub MCP (@modelcontextprotocol/server-github): 커밋 히스토리 심층 분석
- Datadog MCP: 성능 메트릭 + APM 추적
- Git MCP (@cyanheads/git-mcp): git bisect 자동화 강화
- Lanalyzer MCP: 정적 taint analysis (보안 전용)
```

---

## Phase 0: 트리아지 (Claude PM)

**목표:** 이슈를 이해하고 5개 에이전트의 조사 방향을 결정한다.

### 이슈 타입 자동 감지

```
키워드 → 타입 매핑:
"느려|slow|latency|timeout|memory|CPU|렌더|hang" → perf
"보안|security|취약|hack|XSS|SQL|auth|token|leak|injection" → security
"아키텍처|의존성|순환|경계|패턴|설계|결합도|coupling" → arch
그 외 → bug (기본값)
복합: 여러 키워드 감지 → 복수 타입 동시 활성화
```

### 트리아지 체크리스트

```
□ 이슈 타입 결정 (bug / perf / security / arch / 복합)
□ 이슈 핵심 키워드 추출 (함수명, 에러 메시지, 모듈명)
□ 관련 파일 후보 파악 (grep/glob으로 키워드 검색)
□ git log -20 으로 최근 변경 파악
□ 각 에이전트별 커스텀 프롬프트 작성
□ investigation-utils.sh report-init 으로 리포트 파일 초기화
```

### 이슈 타입별 에이전트 집중도 조정

| 타입 | web-researcher | code-analyst | security-auditor | perf-analyst | regression-hunter |
|------|:---:|:---:|:---:|:---:|:---:|
| bug | ● | ●●● | ○ | ○ | ●●● |
| perf | ●● | ●● | ○ | ●●● | ● |
| security | ●●● | ●●● | ●●● | ○ | ● |
| arch | ●● | ●●● | ● | ● | ○ |
| 복합 | ●● | ●● | ●● | ●● | ●● |

---

## Phase 1: 병렬 심층 조사

**5개 에이전트를 동시에 투입한다. 모두 `run_in_background: true`.**

```javascript
// 5개 동시 실행 — 단일 메시지에서 모두 발사
Agent({ subagent_type: "general-purpose", run_in_background: true,
  description: "web-researcher: 이슈 웹 리서치",
  prompt: `[web-researcher 에이전트 역할 로드]
  이슈: <이슈_설명>
  이슈 타입: <타입>
  집중 영역: <타입별_집중도>
  ...`
})

Agent({ subagent_type: "Explore", run_in_background: true,
  description: "code-analyst: 코드 심볼 분석",
  prompt: `[code-analyst 에이전트 역할 로드]
  이슈: <이슈_설명>
  핵심 키워드: <추출된_키워드>
  의심 파일 범위: <파일_목록>
  ...`
})

Agent({ subagent_type: "general-purpose", run_in_background: true,
  description: "security-auditor: OWASP 보안 감사",
  prompt: `[security-auditor 에이전트 역할 로드]
  이슈: <이슈_설명>
  ...`
})

Agent({ subagent_type: "Explore", run_in_background: true,
  description: "perf-analyst: 성능 병목 분석",
  prompt: `[perf-analyst 에이전트 역할 로드]
  이슈: <이슈_설명>
  ...`
})

Agent({ subagent_type: "general-purpose", run_in_background: true,
  description: "regression-hunter: git 회귀 추적",
  prompt: `[regression-hunter 에이전트 역할 로드]
  이슈: <이슈_설명>
  investigation-utils.sh 경로: <경로>
  ...`
})
```

**각 에이전트 프롬프트 필수 포함 내용:**
1. 에이전트 역할 정의 (해당 agents/*.md 내용)
2. 이슈 설명 (사용자 원문)
3. 트리아지에서 파악한 관련 파일/키워드
4. 이슈 타입별 집중 방향
5. "코드 수정 금지 — 보고만 할 것"

---

## Phase 2: 수렴 + 근본 원인 도출

**Sequential Thinking MCP로 다단계 추론을 강제한다.**

5개 에이전트 결과를 수집한 후:

```javascript
mcp__sequential-thinking__sequentialthinking({
  thought: "5개 에이전트 발견 사항을 종합하여 근본 원인을 도출한다",
  nextThoughtNeeded: true,
  thoughtNumber: 1,
  totalThoughts: 7  // 복잡도에 따라 증가 가능
})
```

**7단계 추론 구조:**

| 단계 | 내용 |
|------|------|
| 1 | 증상 정리 (web-researcher + perf-analyst 결과) |
| 2 | 코드 경로 분석 (code-analyst + Serena 결과) |
| 3 | 시간대 분석 (regression-hunter 결과) |
| 4 | 가설 A 생성 + 5개 에이전트 근거 대조 |
| 5 | 가설 B 생성 + 5개 에이전트 근거 대조 |
| 6 | 가설 C 생성 + 5개 에이전트 근거 대조 |
| 7 | 최종 순위 결정 (A/B/C 신뢰도 점수 + 수정 전략) |

**근본 원인 후보 선정 기준:**

```
신뢰도 = (지지하는 에이전트 수 / 5) × (증거 강도)
증거 강도: 코드 라인 특정 = HIGH, 패턴 일치 = MEDIUM, 추론 = LOW
```

**수정 규모 결정 (devrule 기준):**

```
S (1-3 파일): Claude 직접 구현
M (4-10 파일): 전문 에이전트 1개 위임 + QA
L (10+ 파일): 팀 에이전트 병렬 위임 (isolation: "worktree")
```

---

## Phase 3: 수정 구현

devrule 스킬의 S/M/L 전략을 그대로 따른다.

### S 규모 (1-3 파일)

Claude가 직접 수정한다. code-analyst가 특정한 정확한 라인만 수정한다.

### M 규모 (4-10 파일)

```javascript
Agent({
  subagent_type: "wj:<domain>-dev",  // 이슈 도메인에 맞는 에이전트
  description: "근본 원인 수정 구현",
  prompt: `
    근본 원인: <Phase 2 결론>
    수정 대상 파일: <목록>
    수정 방향: <Phase 2 권장 접근>
    
    수정 완료 후 Agent(qa-reviewer)로 검수 요청할 것.
    L1/L2 게이트 통과 필수.
  `
})
```

### L 규모 (10+ 파일)

```javascript
// 파일 소유권 분리 후 병렬 투입
Agent({ isolation: "worktree", run_in_background: true, ... })  // engine-dev
Agent({ isolation: "worktree", run_in_background: true, ... })  // backend-dev
Agent({ isolation: "worktree", run_in_background: true, ... })  // frontend-dev
// 전체 완료 후 QA + 머지
```

---

## Phase 4: 검증

```
□ 관련 테스트 통과 확인
□ 빌드 에러 없음
□ L1 게이트 통과 (파일 크기, any 금지, !. 금지)
□ L2 게이트 통과 (타입 체크) — 해당하는 경우
□ 수정이 이슈 증상을 실제로 해결하는지 확인
```

**3회 이상 수정 시도 후 실패 시:** 수정을 멈추고 아키텍처 의문을 제기한다.
패턴이 잘못 설계된 것일 수 있다 — 근본적인 재설계가 필요하다.

---

## Phase 5: 리포트 + 학습

### investigation-report.md 완성

```bash
# Phase 0에서 초기화된 리포트를 완성한다
# investigation-utils.sh report-init 으로 생성된 파일에 결과를 채운다
```

### Memory MCP에 조사 결과 저장

```javascript
// 유사 이슈 재발 시 자동 참조되도록 저장
mcp__memory__search_nodes("<이슈 키워드>")  // 먼저 유사 과거 이슈 확인

mcp__memory__create_entities([{
  name: "Investigation: <이슈 요약>",
  entityType: "bug-investigation",
  observations: [
    "date: <날짜>",
    "issue_type: <타입>",
    "root_cause: <확정된 원인>",
    "fix_approach: <S|M|L>",
    "key_finding: <핵심 발견>"
  ]
}])
```

### /wj:learn으로 LESSONS.md 업데이트

조사에서 발견한 패턴이나 교훈을 `/wj:learn`으로 기록한다.

```
예시 교훈:
- "루프 안 DB 호출 패턴은 이 프로젝트에서 3번째 등장 — 공통 유틸 추출 필요"
- "JWT 만료 처리 누락 패턴 — 모든 토큰 갱신 로직 리뷰 필요"
```

---

## 위험 신호 (즉시 중단)

이 생각이 들면 멈춰라:

| 위험 신호 | 현실 |
|---------|------|
| "일단 빠르게 고치고 조사하자" | Phase 1 없이 수정하면 증상만 숨긴다 |
| "이 에러면 X가 원인이겠지" | 추측이다. code-analyst + Sequential Thinking으로 증명하라 |
| "한 번만 더 수정 시도" (3회 이상 후) | 설계 문제다. 아키텍처 재검토가 필요하다 |
| "5개 에이전트 필요 없어 보임" | 복잡해 보이지 않은 이슈에서 가장 많이 놀란다 |
| "보안 이슈는 아니겠지" | security-auditor는 항상 투입한다 |

---

## 기존 /wj:debug와의 관계

이 스킬은 `/wj:debug`를 완전히 대체한다.
- `/wj:debug` 호출 시 → 이 스킬로 리다이렉트된다
- 1인 조사 방식 → 5개 전문 에이전트 팀
- 4단계 → 5단계 + Sequential Thinking + Memory 저장

---

## 기술 스택별 참고

### TypeScript/JavaScript
- code-analyst: `any`, `!.` 패턴 특히 주의
- perf-analyst: React 재렌더링, bundle size, async/await 패턴
- web-researcher: npm advisory, GitHub Advisory Database

### Python
- security-auditor: SQLi, Command Injection (subprocess, eval)
- perf-analyst: GIL 관련 병목, sync I/O in async context
- regression-hunter: `requirements.txt` 변경 이력

### Go
- code-analyst: goroutine leak, channel deadlock 패턴
- perf-analyst: escape analysis, unnecessary allocation
- security-auditor: integer overflow, buffer handling
