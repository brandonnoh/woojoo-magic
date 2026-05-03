# /wj:audit — 대규모 보안 감사 스킬 설계서

> 날짜: 2026-05-04
> 상태: Draft

## 개요

웹/앱 서비스의 보안 취약점을 100% 발굴하기 위해 **8개 보안 전문가 에이전트**를 1차 감사로 병렬 투입하고, **3개 검증 에이전트**로 2차 크로스 리뷰를 수행한 뒤, 최종 리포트와 `/wj:loop plan` 호환 작업 리스트를 생성하는 스킬.

감사 결과에 따라 Wave 전략으로 자동 수정 에이전트까지 투입한다.

## 근거

- OWASP Top 10:2025 (A01~A10, 신규 A03 Supply Chain + A10 Exceptional Conditions)
- CWE/SANS Top 25 (2025)
- 실제 감사회사 팀 구성: NCC Group (도메인별 Practice), Trail of Bits (Design Review → Code Review 순차), Cure53 (3-5명 시니어 병렬)
- 자동화 도구: Semgrep(SAST), Trivy(SCA), Gitleaks(Secrets), OWASP ZAP(DAST)

## 전제 조건

- 기존 `agents/security-auditor.md`는 유지 (범용 보안 에이전트, investigate 등에서 계속 사용)
- 새 전문 에이전트 8개는 audit 스킬 전용으로 추가
- `/wj:loop plan` 호환 = `.dev/tasks.json` + `docs/prd.md` 형식 출력

---

## 아키텍처

```
/wj:audit (커맨드)
    ↓
skills/audit/skill.md (스킬)
    ↓
Phase 0: 자산 식별 & 위협 모델링 (PM)
    ↓
Phase 1: 1차 감사 — 8개 전문가 병렬 (run_in_background)
    ↓
Phase 2: 1차 리포트 통합 & 저장
    → .dev/audit/round-1-report.md
    ↓
Phase 3: 2차 감사 — 3개 검증 에이전트 병렬
    ↓
Phase 4: 최종 리포트 & 작업 리스트 생성
    → .dev/audit/final-report.md
    → .dev/tasks.json (loop plan 호환)
    ↓
Phase 5: 자동 수정 (사용자 승인 후)
    → Wave 전략 수정 에이전트 투입
    ↓
Phase 6: 수정 검증 & 정리
```

---

## 생성할 파일 목록

### 1. 커맨드: `commands/audit.md`

```yaml
---
description: 대규모 보안 감사 — 8+3 전문가 에이전트 2-pass 감사 + 자동 수정
---
```

슬래시 커맨드 진입점. `skills/audit/skill.md`로 위임.

### 2. 스킬: `skills/audit/skill.md`

메인 워크플로우 (Phase 0~6).

### 3. 스킬 레퍼런스: `skills/audit/references/`

- `owasp-2025-checklist.md` — OWASP Top 10:2025 + CWE/SANS Top 25 통합 체크리스트
- `audit-agent-roster.md` — 11개 에이전트 역할·투입 조건·산출물 형식 정의

### 4. 새 에이전트 8개: `agents/`

| 파일명 | 역할 | OWASP 매핑 |
|--------|------|-----------|
| `auth-auditor.md` | 인증·인가·세션·RBAC | A01, A07 |
| `injection-hunter.md` | SQL/XSS/Command/Template Injection | A05 |
| `crypto-auditor.md` | 암호화·시크릿·TLS·키관리 | A04 |
| `api-security-auditor.md` | API 보안·SSRF·Rate Limit·CORS | A01, A02 |
| `supply-chain-auditor.md` | 의존성·CVE·빌드체인·lock 무결성 | A03 |
| `config-auditor.md` | 설정·인프라·CSP/HSTS·debug 모드 | A02 |
| `data-integrity-auditor.md` | 데이터 무결성·로깅·결제검증·직렬화 | A08, A09 |
| `client-security-auditor.md` | DOM XSS·Prototype Pollution·postMessage·CSP bypass | A05, A10 |

### 5. 2차 감사 에이전트 3개 (스킬 내 인라인 정의)

에이전트 파일 없이 스킬 프롬프트에서 역할을 직접 정의:

| 역할 | 목적 |
|------|------|
| `false-positive-reviewer` | 1차 결과 오탐 제거, 실제 악용 가능성 재검증 |
| `attack-chain-analyst` | 개별 취약점을 연쇄 공격 시나리오로 엮기 |
| `compliance-checker` | OWASP ASVS L2 기준 누락 항목 보완 |

---

## Phase별 상세 설계

### Phase 0: 자산 식별 & 위협 모델링 (PM)

```
□ 프로젝트 기술 스택 감지 (package.json, requirements.txt 등)
□ 디렉토리 구조 스캔 → 공격 표면 식별
  - API 엔드포인트 (routes/, controllers/, api/)
  - 인증 모듈 (auth/, session/, middleware/)
  - DB 접근 (models/, migrations/, queries/)
  - 클라이언트 입력 처리 (forms/, validators/)
  - 환경 설정 (.env*, config/)
□ git log -20 최근 변경 파악
□ Serena get_symbols_overview → 전체 심볼 맵
□ 각 에이전트별 커스텀 프롬프트 작성 (소유 파일 범위 할당)
□ .dev/audit/ 디렉토리 초기화
```

**공격 표면 분류:**

| 표면 | 매핑 에이전트 |
|------|-------------|
| 인증/인가 흐름 | auth-auditor |
| 사용자 입력 → 출력 | injection-hunter |
| 시크릿/암호화 | crypto-auditor |
| API 엔드포인트 | api-security-auditor |
| 패키지/빌드 | supply-chain-auditor |
| 서버/배포 설정 | config-auditor |
| 데이터 흐름/로깅 | data-integrity-auditor |
| 클라이언트 JS/HTML | client-security-auditor |

### Phase 1: 1차 감사 — 8개 에이전트 병렬

```javascript
// 8개 동시 실행 — 단일 메시지에서 모두 발사
Agent({ subagent_type: "general-purpose", run_in_background: true,
  name: "auth-auditor",
  description: "auth-auditor: 인증·인가 감사",
  prompt: `[auth-auditor 에이전트 역할]
    프로젝트: <기술 스택>
    소유 파일: <auth 관련 파일 목록>
    체크리스트: <owasp-2025-checklist.md의 A01, A07 섹션>
    산출물: 표 형식 이슈 목록 (심각도/카테고리/파일:줄/설명/공격시나리오/수정제안)
    코드 수정 금지 — 보고만 할 것`
})
// ... 나머지 7개 동일 패턴
```

**에이전트 프롬프트 필수 포함:**
1. 에이전트 역할 정의 (`agents/*.md` 내용)
2. 프로젝트 기술 스택
3. 소유 파일 범위 (파일 소유권 겹침 허용 — 분석 전용이므로)
4. OWASP 체크리스트 해당 섹션
5. 자동화 도구 실행 지시 (해당 시)
6. "코드 수정 금지 — 보고만 할 것"

**자동화 도구 연동 (설치되어 있을 때만):**

| 도구 | 담당 에이전트 | 실행 조건 |
|------|-------------|----------|
| `npx semgrep --config auto` | injection-hunter | semgrep 설치 시 |
| `npm audit --json` / `pip-audit` | supply-chain-auditor | package.json / requirements.txt 존재 시 |
| `gitleaks detect --source .` | crypto-auditor | gitleaks 설치 시 |
| `npx trivy fs .` | supply-chain-auditor | trivy 설치 시 |

### Phase 2: 1차 리포트 통합 & 저장

8개 에이전트 결과 수집 후:

1. **중복 제거** — 여러 에이전트가 같은 파일:줄을 다른 관점에서 보고할 수 있음
2. **심각도 정렬** — CRITICAL > HIGH > MEDIUM > LOW > INFO
3. **CVSS 추정** — 각 이슈에 CVSS 3.1 벡터 추정 (에이전트가 제공하지 않은 경우 PM이 추정)
4. **`.dev/audit/round-1-report.md`에 저장**

```markdown
# Security Audit Round 1 — {프로젝트명}
## 날짜: YYYY-MM-DD
## 감사 범위
- 파일 수: N개
- 코드 라인 수: N줄
- 기술 스택: {스택}

## 도메인별 요약
| 도메인 | CRITICAL | HIGH | MEDIUM | LOW | INFO |
|--------|----------|------|--------|-----|------|

## CRITICAL 취약점
| # | ID | 카테고리 | 파일:줄 | 설명 | 공격 시나리오 | CVSS | 수정 제안 |
...

## HIGH 취약점
...

## MEDIUM / LOW / INFO
...

## 자동화 도구 결과
- semgrep: {실행 여부, 발견 수}
- npm audit: {실행 여부, 취약 패키지 수}
- gitleaks: {실행 여부, 시크릿 수}
```

### Phase 3: 2차 감사 — 크로스 리뷰

```javascript
// 3개 검증 에이전트 동시 실행
Agent({ subagent_type: "general-purpose", run_in_background: true,
  name: "false-positive-reviewer",
  description: "2차 감사: 오탐 검증",
  prompt: `1차 감사 리포트를 읽고 각 이슈의 실제 악용 가능성을 재검증하라.
    리포트 경로: .dev/audit/round-1-report.md
    각 이슈별로:
    - CONFIRMED: 실제 악용 가능 (PoC 시나리오 작성)
    - LIKELY: 높은 확률로 악용 가능 (조건 명시)
    - FALSE_POSITIVE: 오탐 (이유 명시)
    - NEEDS_MORE_INFO: 추가 조사 필요`
})

Agent({ subagent_type: "general-purpose", run_in_background: true,
  name: "attack-chain-analyst",
  description: "2차 감사: 공격 체인 분석",
  prompt: `1차 감사의 개별 취약점을 연쇄 공격 시나리오로 엮어라.
    리포트 경로: .dev/audit/round-1-report.md
    예시: XSS(SEC-C-001) + CSRF 미비(SEC-H-003) → 계정 탈취
    각 체인에 공격 단계, 전제 조건, 영향도 명시`
})

Agent({ subagent_type: "general-purpose", run_in_background: true,
  name: "compliance-checker",
  description: "2차 감사: OWASP ASVS 컴플라이언스",
  prompt: `OWASP ASVS Level 2 기준으로 1차 감사에서 누락된 항목을 보완하라.
    리포트 경로: .dev/audit/round-1-report.md
    체크리스트: skills/audit/references/owasp-2025-checklist.md
    누락된 검사 항목, 추가 발견 사항을 별도 테이블로 보고`
})
```

### Phase 4: 최종 리포트 & 작업 리스트

**`.dev/audit/final-report.md` 생성:**

```markdown
# Security Audit Final Report — {프로젝트명}
## 감사 요약
- 1차 발견: N건
- 오탐 제거 후: M건 (CONFIRMED: X, LIKELY: Y)
- 공격 체인: K개 시나리오

## 위험도 매트릭스
| 심각도 | 확인됨 | 의심 | 오탐 |
|--------|--------|------|------|

## 공격 체인 시나리오
### Chain 1: {제목}
- 단계: SEC-C-001 → SEC-H-003 → 계정 탈취
- 전제 조건: ...
- 영향: ...

## ASVS 컴플라이언스 누락
| ASVS 항목 | 설명 | 현재 상태 |

## 작업 리스트 (/wj:loop plan 호환)
### Wave 1: CRITICAL (즉시 수정)
- [ ] SEC-C-001: {설명} — {파일:줄} — 예상 규모: S
- [ ] SEC-C-002: ...

### Wave 2: HIGH (1주 내)
- [ ] SEC-H-001: ...

### Wave 3: MEDIUM (백로그)
- [ ] SEC-M-001: ...
```

**`.dev/tasks.json` 변환 (loop plan 호환):**

CRITICAL과 HIGH 이슈를 tasks.json 형식으로 변환:

```json
{
  "tasks": [
    {
      "id": "SEC-C-001",
      "title": "[CRITICAL-SEC-001] XSS in render.ts:42",
      "status": "pending",
      "tags": ["security", "critical"],
      "files": ["src/api/render.ts"],
      "spec": "수정 방향: DOMPurify.sanitize() 적용",
      "blockedBy": []
    }
  ]
}
```

### Phase 5: 자동 수정 (사용자 승인 후)

**사용자에게 묻기:**
> "보안 감사 완료. CRITICAL {N}건, HIGH {M}건 발견.
> Wave 1 수정 에이전트를 투입할까요? (CRITICAL 먼저)"

승인 시 cto-review와 동일한 Wave 전략:

```
Wave 1: CRITICAL 이슈 수정
  - 파일 소유권 분리
  - 수정 에이전트: isolation: "worktree" + run_in_background: true
  - 각 에이전트에 수정 대상 이슈 ID + 파일 + 수정 방향 전달
  ↓ (머지 후)
Wave 2: HIGH 이슈 수정
  ↓ (머지 후)
Wave 3: MEDIUM 이슈 (선택)
```

**수정 에이전트 매핑:**

| 이슈 도메인 | 수정 에이전트 |
|------------|-------------|
| 인증/인가 | backend-dev |
| XSS/클라이언트 | frontend-dev |
| API/서버 설정 | backend-dev |
| 의존성 | PM 직접 (npm audit fix 등) |
| 암호화/시크릿 | backend-dev |

### Phase 6: 수정 검증 & 정리

```
□ 수정된 파일에 대해 해당 감사 에이전트 재실행 (해당 이슈만)
□ L1/L2 게이트 통과
□ 전체 테스트 통과
□ 워크트리 정리
□ 최종 커밋
```

---

## 토큰 예산

| Phase | 에이전트 수 | 예상 토큰 |
|-------|-----------|---------|
| Phase 0 (자산 식별) | PM 1명 | ~2,000 |
| Phase 1 (1차 감사) | 8명 × 5,000-8,000 | ~40,000-64,000 |
| Phase 2 (리포트 통합) | PM 1명 | ~3,000 |
| Phase 3 (2차 감사) | 3명 × 4,000-6,000 | ~12,000-18,000 |
| Phase 4 (최종 리포트) | PM 1명 | ~3,000 |
| Phase 5 (자동 수정) | Wave별 2-4명 | ~20,000-40,000 |
| Phase 6 (검증) | 재감사 에이전트 | ~5,000-10,000 |
| **전체** | **최대 16명** | **~85,000-140,000** |

---

## 이슈 분류 체계

### 심각도

| 레벨 | 의미 | 예시 |
|------|------|------|
| CRITICAL | 즉시 수정. 데이터 탈취/시스템 장악 가능 | SQLi, RCE, 인증 우회, 하드코딩 프로덕션 키 |
| HIGH | 빠른 수정. 제한적 데이터 노출/권한 상승 | CSRF, JWT 만료 미처리, IDOR, 에러 정보 노출 |
| MEDIUM | 기회 시 수정. 공격 난이도 높거나 영향 제한적 | CORS *, Rate Limit 부재, CSP 미비 |
| LOW | 선택적. 보안 모범 사례 미준수 | Prototype Pollution 가능성, 불필요한 헤더 |
| INFO | 참고. 취약점은 아니지만 개선 가능 | 미사용 의존성, 오래된 패키지 |

### 이슈 ID 형식

```
SEC-{심각도 약자}-{번호}
예: SEC-C-001, SEC-H-012, SEC-M-003
```

---

## 기존 컴포넌트와의 관계

| 기존 | 관계 |
|------|------|
| `agents/security-auditor.md` | 유지. investigate/team에서 범용 보안 에이전트로 계속 사용 |
| `/wj:investigate` | 독립. investigate는 버그 중심, audit은 보안 전수 점검 |
| `/wj:cto-review` | 참조. Wave 전략 + 워크트리 패턴을 재사용 |
| `/wj:loop plan` | 호환. 최종 작업 리스트를 tasks.json으로 변환 |
| `/wj:check` | 보완. check은 코드 품질, audit은 보안 품질 |

---

## 파일 트리 최종

```
src/wj-magic/
├── commands/
│   └── audit.md                    ← 신규
├── skills/
│   └── audit/
│       ├── skill.md                ← 신규 (메인 워크플로우)
│       └── references/
│           ├── owasp-2025-checklist.md  ← 신규
│           └── audit-agent-roster.md    ← 신규
├── agents/
│   ├── security-auditor.md         ← 기존 유지
│   ├── auth-auditor.md             ← 신규
│   ├── injection-hunter.md         ← 신규
│   ├── crypto-auditor.md           ← 신규
│   ├── api-security-auditor.md     ← 신규
│   ├── supply-chain-auditor.md     ← 신규
│   ├── config-auditor.md           ← 신규
│   ├── data-integrity-auditor.md   ← 신규
│   └── client-security-auditor.md  ← 신규
```

총 신규 파일: **12개**
- 커맨드 1개 + 스킬 1개 + 레퍼런스 2개 + 에이전트 8개
