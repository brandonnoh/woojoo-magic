# 보안 감사 에이전트 로스터

## Phase 1: 1차 감사 에이전트 (8개 병렬)

| # | 에이전트 | 도메인 | OWASP | 자동화 도구 |
|---|---------|--------|-------|------------|
| 1 | auth-auditor | 인증·인가·세션·RBAC | A01, A07 | — |
| 2 | injection-hunter | SQL/XSS/Command/Template Injection | A05 | semgrep |
| 3 | crypto-auditor | 암호화·시크릿·TLS·키관리 | A04 | gitleaks |
| 4 | api-security-auditor | API 보안·SSRF·Rate Limit·CORS | A01, A02 | — |
| 5 | supply-chain-auditor | 의존성·CVE·빌드체인 | A03 | npm audit, trivy |
| 6 | config-auditor | 설정·인프라·보안헤더 | A02 | — |
| 7 | data-integrity-auditor | 데이터 무결성·로깅·결제검증 | A08, A09 | — |
| 8 | client-security-auditor | DOM XSS·Prototype Pollution·CSP | A05, A10 | — |

## Phase 3: 2차 검증 에이전트 (3개 병렬)

| # | 역할 | 목적 | 에이전트 파일 |
|---|------|------|-------------|
| 1 | false-positive-reviewer | 1차 결과 오탐 제거, 악용 가능성 재검증 | 스킬 내 인라인 |
| 2 | attack-chain-analyst | 개별 취약점 → 연쇄 공격 시나리오 도출 | 스킬 내 인라인 |
| 3 | compliance-checker | OWASP ASVS L2 기준 누락 항목 보완 | 스킬 내 인라인 |

## 공통 산출물 형식

### 1차 감사 에이전트 (Phase 1)

| # | 심각도 | 카테고리 | 파일:줄 | 설명 | 공격 시나리오 | 수정 제안 |
|---|--------|---------|---------|------|-------------|----------|
| 1 | CRITICAL | XSS | src/api/render.ts:42 | innerHTML에 미검증 입력 | 악성 스크립트 삽입 → 세션 탈취 | DOMPurify.sanitize() |

### 2차 검증 에이전트

#### false-positive-reviewer
| 이슈 ID | 원래 심각도 | 판정 | 근거 |
|---------|-----------|------|------|
| SEC-C-001 | CRITICAL | CONFIRMED | PoC: curl -X POST ... |
| SEC-H-003 | HIGH | FALSE_POSITIVE | sanitize 함수가 상위에서 적용됨 |

#### attack-chain-analyst
| 체인 # | 시작 취약점 | 연쇄 | 최종 영향 | 전제 조건 |
|--------|-----------|------|----------|----------|
| 1 | SEC-C-001 (XSS) | → SEC-H-005 (CSRF) | 계정 탈취 | 피해자가 링크 클릭 |

#### compliance-checker
| ASVS 항목 | 설명 | 현재 상태 | 권장 조치 |
|-----------|------|----------|----------|
| V2.1.1 | 비밀번호 최소 12자 | 미구현 | 비밀번호 정책 강화 |

## 이슈 ID 형식

SEC-{심각도}-{번호}
- SEC-C-001: CRITICAL #1
- SEC-H-012: HIGH #12
- SEC-M-003: MEDIUM #3
- SEC-L-001: LOW #1
- SEC-I-001: INFO #1

## 판정 기준

| 판정 | 조건 |
|------|------|
| PASS | 발견 사항 없음 또는 LOW/INFO만 |
| WARN | HIGH 이하만 (커밋 가능, 후속 수정 권장) |
| FAIL | CRITICAL 1건 이상 (수정 후 재감사 필수) |
