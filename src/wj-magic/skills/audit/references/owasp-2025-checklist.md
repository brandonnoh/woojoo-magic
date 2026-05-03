# OWASP Top 10:2025 + CWE/SANS Top 25 통합 보안 감사 체크리스트

## OWASP Top 10:2025

### A01:2025 — Broken Access Control
- [ ] 모든 API 엔드포인트에 인증 미들웨어 적용 확인
- [ ] 수직 권한 상승 테스트 (일반 사용자 → 관리자 기능 접근)
- [ ] 수평 권한 상승 테스트 (사용자 A → 사용자 B 데이터 접근)
- [ ] IDOR (Insecure Direct Object Reference) 패턴 검색
- [ ] 디렉토리 트래버설 경로 차단 확인
- [ ] CORS 정책 적절성 확인
- [ ] JWT/세션 토큰 검증 로직 확인

### A02:2025 — Security Misconfiguration
- [ ] 프로덕션 디버그 모드 비활성화 확인
- [ ] 보안 헤더 설정 (CSP, HSTS, X-Frame-Options, X-Content-Type-Options)
- [ ] 디폴트 계정/비밀번호 제거 확인
- [ ] 불필요한 기능/포트/서비스 비활성화
- [ ] 에러 핸들러 프로덕션 모드 (스택트레이스 숨김)
- [ ] Directory listing 비활성화
- [ ] 서버 헤더 기술 스택 노출 제거

### A03:2025 — Software Supply Chain Failures (신규)
- [ ] lock 파일 존재 및 무결성 확인
- [ ] npm audit / pip-audit / cargo audit 실행
- [ ] CVSS >= 7.0 취약점 없음 확인
- [ ] typosquatting 의심 패키지 확인
- [ ] postinstall 스크립트 검토
- [ ] CI/CD 파이프라인 보안 (미검증 스크립트 실행 금지)
- [ ] 의존성 출처 검증 (공식 레지스트리만)

### A04:2025 — Cryptographic Failures
- [ ] 하드코딩된 시크릿 없음 확인 (API 키, 토큰, 비밀번호)
- [ ] 취약 해시 미사용 (MD5, SHA1 for passwords → bcrypt/argon2)
- [ ] 취약 암호 알고리즘 미사용 (DES, RC4, 3DES)
- [ ] TLS 1.2+ 강제
- [ ] 암호화 키 적절한 길이 (RSA >= 2048, AES >= 128)
- [ ] 환경 변수 프론트엔드 번들 미포함 확인
- [ ] 인증서 검증 활성화 확인

### A05:2025 — Injection
- [ ] SQL/NoSQL Injection: 파라미터 바인딩/ORM 사용 확인
- [ ] XSS: innerHTML/dangerouslySetInnerHTML 미사용 또는 sanitize 적용
- [ ] Command Injection: exec/spawn에 사용자 입력 미전달 확인
- [ ] Template Injection: 템플릿 엔진 auto-escape 활성화
- [ ] LDAP Injection: LDAP 쿼리 입력 이스케이프
- [ ] Header Injection: HTTP 헤더에 사용자 입력 미포함
- [ ] eval/Function 동적 코드 실행 미사용

### A06:2025 — Insecure Design
- [ ] 위협 모델링 수행 여부
- [ ] 비즈니스 로직 검증 (결제 금액 서버 검증 등)
- [ ] Rate Limiting 적용 (인증, 결제, 중요 API)
- [ ] 실패 안전 설계 (fail-secure, not fail-open)

### A07:2025 — Authentication Failures
- [ ] 비밀번호 정책 (최소 길이, 복잡도)
- [ ] 다중 인증(MFA) 지원
- [ ] 계정 잠금/지연 정책
- [ ] 세션 관리 (타임아웃, 로그아웃 시 토큰 폐기)
- [ ] OAuth 구현 보안 (state 파라미터, PKCE)

### A08:2025 — Software or Data Integrity Failures
- [ ] 안전하지 않은 역직렬화 패턴 없음 확인
- [ ] 서드파티 스크립트 SRI (Subresource Integrity) 적용
- [ ] CI/CD 파이프라인 무결성
- [ ] 자동 업데이트 서명 검증

### A09:2025 — Security Logging and Alerting Failures
- [ ] 보안 이벤트 로깅 (로그인 실패, 권한 거부, 비정상 접근)
- [ ] 로그에 민감 정보 미포함 (비밀번호, 토큰, PII)
- [ ] 감사 추적(audit trail) 구현
- [ ] 로그 변조 방지
- [ ] 이상 탐지 알림

### A10:2025 — Mishandling of Exceptional Conditions (신규)
- [ ] 예외 발생 시 보안 상태 유지 (fail-secure)
- [ ] 에러 메시지에 내부 정보 미노출
- [ ] 리소스 해제 보장 (try-finally, using)
- [ ] 타임아웃 설정 (네트워크, DB 커넥션)
- [ ] 예외 상황에서 인증/인가 우회 불가

## CWE/SANS Top 25 추가 체크

위 OWASP에서 다루지 않는 CWE:
- [ ] CWE-787: Out-of-bounds Write (C/C++/Rust unsafe 블록)
- [ ] CWE-416: Use After Free (메모리 안전성)
- [ ] CWE-125: Out-of-bounds Read
- [ ] CWE-476: NULL Pointer Dereference
- [ ] CWE-770: Allocation of Resources Without Limits (메모리/파일/커넥션 풀)
