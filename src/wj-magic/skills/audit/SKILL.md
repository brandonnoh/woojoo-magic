---
description: >
  웹/앱 서비스의 보안 취약점을 8개 전문가 에이전트 1차 감사 + 3개 검증 에이전트 2차 크로스 리뷰로
  100% 발굴하고, /wj:loop plan 호환 작업 리스트를 생성하며, Wave 전략으로 자동 수정까지 완료하는 스킬.
  "보안 감사", "보안 점검", "취약점 찾아줘", "security audit", "보안 전수 점검",
  "해킹 테스트", "펜테스트", "OWASP 점검" 요청에 트리거.
---

**품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)

# /wj:audit — 보안 전수 감사 & 자동 수정

8개 전문 감사 에이전트 → 3개 검증 에이전트 크로스 리뷰 → Wave 전략 자동 수정.
**대규모 토큰 사용은 의도된 설계다. 보안은 절약의 대상이 아니다.**

<HARD-GATE>
Phase 1 (8개 에이전트 병렬 감사) 완료 전 코드 수정 금지.
"빠르게 패치하고 나중에 점검"은 금지. 반드시 전수 감사 후 수정한다.
</HARD-GATE>

<HARD-GATE>
## 시크릿 마스킹 (절대 규칙 — 위반 시 보안 사고)

감사 리포트(.dev/audit/*.md)에 **실제 시크릿 값을 절대 기록하지 않는다.**
이 규칙은 모든 Phase, 모든 에이전트, 모든 산출물에 예외 없이 적용된다.

### 금지
- ❌ 실제 API 키, 토큰, 비밀번호, 암호화 키 값을 리포트에 기록
- ❌ gitleaks/trufflehog 출력의 시크릿 값을 그대로 복사
- ❌ 환경 변수의 실제 값을 리포트에 포함

### 의무
- ✅ 시크릿은 반드시 마스킹: `AIzaSy...***` (앞 6자 + `***`)
- ✅ 파일명:줄번호 + 시크릿 유형만 기록 (예: `src/config.ts:8 — Google API Key (하드코딩)`)
- ✅ gitleaks/trufflehog 실행 시 `--no-color` 사용, 출력에서 값 부분 제거 후 기록

### 마스킹 형식
```
# 올바른 예
| 1 | CRITICAL | 하드코딩 시크릿 | src/config.ts:8 | Google API Key 하드코딩 | AIzaSy...*** |

# 금지 예 (실제 값 노출)
| 1 | CRITICAL | 하드코딩 시크릿 | src/config.ts:8 | Google API Key | AIzaSyAcMkwKZt9Bxe-yU4zLP9zOa-KW6xsRRPw |
```

**위반 시:** GitHub Secret Scanning이 감지 → 키 제공업체에 자동 신고 → 키 즉시 차단.
감사 리포트가 보안 사고의 원인이 되는 역설적 상황이 발생한다.
</HARD-GATE>

## References

- [owasp-2025-checklist.md](references/owasp-2025-checklist.md) — OWASP Top 10 2025 + ASVS L2
- [audit-agent-roster.md](references/audit-agent-roster.md) — 8개 감사 에이전트 역할 정의

## 토큰 예산

| Phase | 예상 토큰 |
|-------|---------|
| Phase 0 (자산 식별) | ~2,000 |
| Phase 1 (8명 x 5K-8K) | ~40,000-64,000 |
| Phase 2 (통합) | ~3,000 |
| Phase 3 (3명 x 4K-6K) | ~12,000-18,000 |
| Phase 4 (리포트) | ~3,000 |
| Phase 5 (수정) | ~20,000-40,000 |
| Phase 6 (검증) | ~5,000-10,000 |
| **전체** | **~85,000-140,000** |

## 선택적 MCP

```
- Sentry MCP: 프로덕션 보안 이벤트 수집
- Lanalyzer MCP: 정적 taint analysis
- Snyk MCP: 의존성 취약점 DB 조회
```

---

## Phase 0: 자산 식별 & 위협 모델링 (Claude PM)

**목표:** 공격 표면을 식별하고 8개 에이전트의 감사 범위를 할당한다.

```
PM 필수 호출:
1. mcp__plugin_serena_serena__get_symbols_overview  ← 전체 심볼 맵
2. mcp__plugin_serena_serena__find_symbol           ← 인증/암호화/API 심볼 추적
3. mkdir -p .dev/audit                              ← 산출물 디렉토리 초기화

트리아지 체크리스트:
□ 기술 스택 감지 (언어, 프레임워크, DB, 인증 방식)
□ 디렉토리 구조 스캔 → 공격 표면 식별
□ Serena get_symbols_overview → 전체 심볼 맵
□ 의존성 파악 (package.json / requirements.txt / go.mod)
□ .env.example, 설정 파일 → 시크릿 관리 방식 확인
□ 에이전트별 소유 파일 범위 할당
```

### 공격 표면 → 에이전트 매핑

| 공격 표면 | 에이전트 | 집중 영역 |
|----------|---------|----------|
| 인증/인가 흐름 | auth-auditor | 세션, JWT, RBAC, OAuth |
| 사용자 입력→출력 | injection-hunter | SQLi, XSS, SSRF, Command Injection |
| 시크릿/암호화 | crypto-auditor | 키 관리, 해싱, TLS, 하드코딩 시크릿 |
| API 엔드포인트 | api-security-auditor | Rate limit, CORS, 입력 검증, 에러 노출 |
| 패키지/빌드 | supply-chain-auditor | 의존성 취약점, lockfile, 빌드 스크립트 |
| 서버/배포 설정 | config-auditor | 헤더, CSP, HTTPS, 디버그 모드 |
| 데이터 흐름/로깅 | data-integrity-auditor | PII 노출, 로그 인젝션, 민감 데이터 |
| 클라이언트 JS/HTML | client-security-auditor | DOM XSS, postMessage, localStorage |

---

## Phase 1: 1차 감사 — 8개 에이전트 병렬

**8개 Agent를 단일 메시지에서 모두 `run_in_background: true`로 발사한다.**

```javascript
// 8개 동시 실행 — 단일 메시지에서 모두 발사
// 아래 패턴을 8개 에이전트 각각에 적용
Agent({ subagent_type: "general-purpose", run_in_background: true,
  name: "auth-auditor",
  description: "auth-auditor: 인증/인가 보안 감사",
  prompt: `[역할: agents/security-auditor.md Read]
  기술 스택: <스택>
  소유 파일 범위: <인증 관련 파일>
  OWASP: skills/audit/references/owasp-2025-checklist.md Read
  코드 수정 금지 — 보고만.
  자동화: semgrep --config=p/jwt (설치 시)
  산출물: .dev/audit/agent-auth-auditor.md`
})
// injection-hunter, crypto-auditor, api-security-auditor,
// supply-chain-auditor, config-auditor, data-integrity-auditor,
// client-security-auditor — 동일 패턴, name/description/prompt만 변경
// 자동화: semgrep, npm audit, gitleaks, trivy (설치 시만)
// 각 산출물: .dev/audit/agent-{에이전트명}.md
```

**각 에이전트 프롬프트 필수 포함:**
1. 역할 정의 (`agents/security-auditor.md` 또는 스킬 내 정의 Read)
2. 기술 스택 + 소유 파일 범위 (Phase 0 할당)
3. OWASP 체크리스트 Read 지시
4. "코드 수정 금지 — 보고만 할 것"
5. 자동화 도구 지시 (설치되어 있을 때만)

---

## Phase 2: 1차 리포트 통합

8개 `.dev/audit/agent-*.md` 수집 → 중복 제거 → 심각도 정렬 → `.dev/audit/round-1-report.md` 저장.

**이슈 ID:** `SEC-{C/H/M/L/I}-{번호}` (예: SEC-C-001)

```markdown
# Round 1 보안 감사 리포트
## 감사 범위
- 기술 스택: ... | 스캔 파일 수: N | 에이전트: 8개
## 도메인별 요약
| 도메인 | CRITICAL | HIGH | MEDIUM | LOW | INFO |
## CRITICAL 이슈
### SEC-C-001: 파일명:라인 — 문제 설명
- 에이전트: auth-auditor | OWASP: A01 | 증거: ... | 영향: ...
## HIGH / MEDIUM / LOW / INFO (동일 형식)
```

---

## Phase 3: 2차 감사 — 3개 검증 에이전트 병렬

**Round 1 리포트 기반, 3개 동시 `run_in_background: true`.**

```javascript
Agent({ subagent_type: "general-purpose", run_in_background: true,
  name: "false-positive-reviewer",
  description: "오탐 검증: CONFIRMED/LIKELY/FALSE_POSITIVE/NEEDS_MORE_INFO 판정",
  prompt: `.dev/audit/round-1-report.md Read. 각 이슈 실제 코드 확인.
  코드 수정 금지. 산출물: .dev/audit/review-false-positive.md`
})

Agent({ subagent_type: "general-purpose", run_in_background: true,
  name: "attack-chain-analyst",
  description: "개별 취약점 연쇄 공격 시나리오 도출",
  prompt: `.dev/audit/round-1-report.md Read. 취약점 조합 → 체인 공격 시나리오.
  코드 수정 금지. 산출물: .dev/audit/review-attack-chains.md`
})

Agent({ subagent_type: "general-purpose", run_in_background: true,
  name: "compliance-checker",
  description: "OWASP ASVS L2 기준 누락 항목 보완",
  prompt: `round-1-report.md + owasp-2025-checklist.md Read. 누락 ASVS L2 항목 보완.
  코드 수정 금지. 산출물: .dev/audit/review-compliance.md`
})
```

---

## Phase 4: 최종 리포트 & 작업 리스트

3개 검증 통합 → `.dev/audit/final-report.md` 생성.

```markdown
# 보안 감사 최종 리포트
## 요약
- 총 이슈 N → 오탐 제거 → 확인된 이슈 M건
- 공격 체인 시나리오: K건
## 확인된 이슈 (CONFIRMED + LIKELY만, SEC-ID 형식)
## 공격 체인 시나리오
### Chain-001: SEC-H-003 → SEC-M-007 → 관리자 권한 탈취
- 수정 우선순위: 체인 내 가장 쉬운 링크 차단
## ASVS 컴플라이언스 누락
## 수정 작업 리스트 (/wj:loop plan 호환)
### Wave 1 — CRITICAL | Wave 2 — HIGH | Wave 3 — MEDIUM
```

```javascript
// tasks.json 변환 (선택)
const tasks = { waves: [
  { name: "Wave 1 — CRITICAL", tasks: [
    { id: "SEC-C-001", file: "src/auth/login.ts", agent: "backend-dev" },
  ]},
]};
```

**사용자에게 묻기:** "CRITICAL N건, HIGH M건 발견. Wave 1 수정 에이전트를 투입할까요?"

---

## Phase 5: 자동 수정 (사용자 승인 후)

cto-review Wave 전략 재사용. **파일 소유권 엄격 분리.**

| 이슈 도메인 | 수정 에이전트 |
|------------|-------------|
| 인증/인가, API, 암호화, 설정, 데이터 | backend-dev |
| XSS, CSRF, 클라이언트 보안 | frontend-dev |
| 의존성, 빌드 설정 | infra-dev (또는 Claude 직접) |

```javascript
// Wave 1 (CRITICAL) — isolation: "worktree" + run_in_background: true
Agent({ isolation: "worktree", run_in_background: true,
  name: "security-fix-backend",
  description: "Wave 1 백엔드 보안 수정",
  prompt: `소유 파일: {목록} | 수정 태스크: {CRITICAL 이슈}
  수정 전 Serena find_referencing_symbols 필수. L1/L2 게이트 통과 필수.`
})
Agent({ isolation: "worktree", run_in_background: true,
  name: "security-fix-frontend",
  description: "Wave 1 프론트엔드 보안 수정",
  prompt: `소유 파일: {목록} | 수정 태스크: {CRITICAL 이슈}`
})
// Wave 1 머지 확인 → Wave 2 투입 → Wave 3 투입
```

---

## Phase 6: 수정 검증 & 정리

```
□ 수정 파일 → 해당 감사 에이전트 재실행 (취약점 해소 확인)
□ L1/L2 게이트 통과 + 전체 테스트 통과
□ 자동화 도구 재실행 (semgrep, npm audit 등)
□ 워크트리 정리 + 최종 커밋
```

```bash
for wt in .claude/worktrees/agent-*; do git worktree remove "$wt" --force; done
for br in $(git branch | grep worktree-agent); do git branch -D "$br"; done
```

---

## 이슈 분류 체계

| 심각도 | 의미 | 예시 |
|--------|------|------|
| **CRITICAL** | 즉시 수정, RCE/데이터 유출 | SQLi, 인증 우회, 하드코딩 시크릿 |
| **HIGH** | 빠른 수정, 권한 상승/정보 노출 | XSS, CSRF, IDOR, 약한 암호화 |
| **MEDIUM** | 방어 심화 부족 | Rate limit 미설정, 에러 노출 |
| **LOW** | 보안 강화, 선택적 | 헤더 누락, 불필요 정보 노출 |
| **INFO** | 모범 사례 권장 | CSP 세분화, SRI 적용 |

**ID 형식:** `SEC-{C/H/M/L/I}-{번호}: 파일명:라인 — 설명 (OWASP: A0X, 영향, 수정 방향)`

---

## 위험 신호 (즉시 중단)

| 위험 신호 | 현실 |
|---------|------|
| "빠르게 패치하고 나중에 전수 점검" | Phase 1 없이 수정하면 구멍을 남긴다 |
| "내부용이라 보안 안 중요" | 내부 서비스도 lateral movement 경로가 된다 |
| "8개 에이전트는 과하다" | 보안은 전문 분야 분리가 핵심이다 |
| "오탐 검증은 건너뛰자" | Phase 3 없이 수정하면 노이즈에 시간 낭비 |
| "MEDIUM은 나중에" | 체인 공격에서 MEDIUM이 CRITICAL 진입점이 된다 |

---

## 기존 컴포넌트 관계

- `agents/security-auditor.md`: Phase 1 에이전트 기반 역할 정의로 유지
- `/wj:investigate`: 독립 (버그/성능/보안 복합 조사 vs 보안 전수 감사)
- `/wj:cto-review`: Wave 전략 패턴 재사용 (Phase 5)
- `/wj:loop plan`: Phase 4 작업 리스트 호환 형식 출력
