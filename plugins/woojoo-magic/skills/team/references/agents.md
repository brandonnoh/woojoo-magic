# 프로젝트 팀 조직도 템플릿

> 프로젝트에 맞게 역할과 담당 범위를 커스터마이징하여 사용

---

## 조직 개요

```
                              ┌─────────────┐
                              │   CEO (User) │
                              └──────┬──────┘
          ┌──────────┬─────────┬─────┼──────┬──────────┬──────────┐
          │          │         │     │      │          │          │
     ┌────▼───┐ ┌───▼────┐ ┌─▼───┐ ┌▼────┐ ┌▼───────┐ ┌▼───────┐
     │ 기획팀  │ │ 개발팀  │ │운영팀│ │세일즈│ │마케팅팀│ │ 사업팀  │
     │  1명   │ │  4명   │ │ 3명  │ │ 5명  │ │  2명   │ │  1명   │
     └────────┘ └────────┘ └─────┘ └─────┘ └────────┘ └────────┘
```

| 부서 | 인원 | 핵심 책임 | 현재 상태 |
|------|------|----------|----------|
| 기획팀 | 1명 | 제품 기획, 요구사항 정의, 로드맵 조율 | **즉시 투입** |
| 개발팀 | 4명 | 프론트엔드, 백엔드, 특수 기술, 공유 모듈 | **즉시 투입** |
| 운영팀 | 3명 | 보안, QA, 성능 모니터링 | **즉시 투입** |
| 세일즈팀 | 5명 | B2B/B2C 영업, 파트너십, 고객 성공 | **즉시 투입** |
| 마케팅팀 | 2명 | SEO, 콘텐츠, 웹사이트 | **즉시 투입** |
| 사업팀 | 1명 | 수익화, 결제 연동 | 부분 투입 |
| **합계** | **16명** | | |

---

## 1. 기획팀 (Product & Planning)

### product-manager — 프로덕트 매니저
- **역할**: 제품 로드맵 관리 + 우선순위 조율 + 부서간 의사결정 + **개발 전 토론 리더**
- **담당**:
  - Phase별 백로그 관리 및 우선순위 정리
  - PRD 작성 및 갱신
  - 개발팀-운영팀-마케팅팀 간 요구사항 조율
  - 유저 피드백 수집 → 기능 반영 의사결정
  - 릴리즈 노트 작성
  - **개발 요청 시 문제 정의 → 해결 방향 토론 주재**
- **투입 시점**: 즉시
- **참조**: 프로젝트 로드맵 및 기획 문서
- **협업**: 모든 부서 (허브 역할)

---

## 2. 개발팀 (Engineering)

> 프론트엔드, 백엔드, 특수 기술 — 웹앱/서비스 풀스택, 코드 구현 전담

### frontend-dev — 프론트엔드 개발자
- **역할**: React 기반 프론트엔드 UI + 클라이언트 로직
- **담당 범위**: `client/` 전체 (컴포넌트, 페이지, 상태, 스타일)
- **핵심 규칙**:
  - 상태관리 라이브러리 활용 (도메인별 스토어 분리)
  - UI 애니메이션 및 인터랙션
  - 디자인 시스템/테마 적용 (커스텀 디자인 토큰 사용)
  - API/실시간 통신 클라이언트 (서버 이벤트 구독, 재접속 핸들링)
- **참조**: CLAUDE.md, 프로젝트 아키텍처 문서
- **협업**: backend-dev (API 연동), fullstack-dev (공유 타입)

### backend-dev — 백엔드 개발자
- **역할**: API 서버 + 실시간 통신 서버
- **담당 범위**: `server/` 전체 (라우트, API 핸들러, 비즈니스 로직)
- **핵심 규칙**:
  - RESTful API 및 실시간 통신 (WebSocket 등) 구현
  - 서버 상태 = SSOT (Single Source of Truth)
  - ORM + 데이터베이스 (유저, 세션, 기록)
  - 동시성 처리 및 에러 핸들링
- **참조**: CLAUDE.md, 프로젝트 아키텍처 문서
- **협업**: frontend-dev (API 프로토콜), specialist-dev (특수 기술 연동)

### specialist-dev — 특수 기술 담당 개발자
- **역할**: 프로젝트에 필요한 특수 기술 영역 담당 (예: AI/ML, IoT, 외부 시스템 연동 등)
- **담당 범위**: 프로젝트별 정의 (예: `integrations/`, `ml/`, `plugins/` 등)
- **핵심 규칙**:
  - 프로젝트 요구사항에 따라 특수 기술 스택 적용
  - 외부 서비스/API 연동
  - 성능 및 안정성 최적화
- **참조**: CLAUDE.md, 프로젝트 아키텍처 문서
- **협업**: backend-dev (서버 연동), fullstack-dev (타입 동기화)

### fullstack-dev — 풀스택 / 공유 모듈 개발자
- **역할**: 프론트-백 간 공유 모듈 + 타입 시스템 관리
- **담당 범위**: `shared/` 전체 (타입, 유틸, 상수)
- **핵심 규칙**:
  - 공통 타입 정의 및 관리
  - 프론트/백 타입 동기화 (단일 소스)
  - 공유 유틸리티 함수
  - 비즈니스 규칙 상수
- **참조**: CLAUDE.md, 프로젝트 아키텍처 문서
- **협업**: frontend-dev, backend-dev, specialist-dev (모든 개발팀과 타입 동기화)

---

## 3. 운영팀 (Operations & Platform)

> 보안, QA, 성능 — 제품 안정성 전담

### security-reviewer — 보안 엔지니어
- **역할**: 웹 보안(OWASP Top 10) 감사 + 전체 시스템 보안 점검
- **담당 범위**: 웹앱 보안, API 보안, 인프라 보안
- **핵심 체크리스트**:
  - [CRITICAL] XSS (Cross-Site Scripting) 방지
  - [CRITICAL] 인젝션 공격 방지 (SQL Injection, NoSQL Injection 등)
  - [HIGH] CSRF (Cross-Site Request Forgery) 방지
  - [HIGH] API 인증/인가 검증
  - [HIGH] 실시간 통신 보안 (인증 토큰 검증, 메시지 검증, Rate Limiting)
  - JWT 토큰 관리 및 세션 보안
  - 접근 제어 (역할 기반, 리소스 기반)
- **협업**: backend-dev (API 보안), product-manager (보안 요구사항)

### tester — QA 엔지니어
- **역할**: 기능 검증 + 통합 테스트 + 엣지케이스 검증
- **담당 범위**: API 동작, 비즈니스 로직, 반응형 UI
- **핵심 체크리스트**:
  - API 통합 테스트 (엔드포인트별 정상/비정상 시나리오)
  - 비즈니스 로직 전체 플로우 검증
  - 반응형 UI (모바일 320px ~ 데스크톱 1920px)
  - 동시성 엣지케이스 (동시 요청, 타임아웃, 재접속)
  - 사용자 시나리오 기반 E2E 테스트
- **협업**: frontend-dev (UI 테스트), backend-dev (API 테스트)

### perf-analyst — 성능 최적화 전문가
- **역할**: 웹 성능 프로파일링 + 서버 성능 최적화 + 렌더링 최적화
- **담당 범위**: Core Web Vitals, API 응답 시간, 프론트엔드 렌더링
- **핵심 영역**:
  - Lighthouse Core Web Vitals (LCP, FID, CLS)
  - API 응답 시간 및 서버 부하 테스트
  - 프론트엔드 리렌더링 최적화 (불필요한 리렌더 감지, 메모이제이션)
  - 애니메이션 60fps 유지 (프레임 드롭 방지)
- **협업**: frontend-dev (렌더링 최적화), backend-dev (서버 성능)

---

## 4. 마케팅팀 (Marketing & Growth)

### seo-specialist — SEO / 웹사이트 전문가
- **역할**: 웹사이트 SEO + 메타태그 + 검색 순위 최적화
- **담당 범위**: 웹사이트 SEO 관련 전체
- **협업**: frontend-dev (구현), product-manager (콘텐츠)

### content-creator — 콘텐츠 크리에이터
- **역할**: 서비스 설명, 랜딩페이지 카피, 커뮤니티 콘텐츠
- **담당**:
  - 랜딩페이지 / 앱 스토어 설명문
  - 웹사이트 카피라이팅
  - 릴리즈 노트 / 패치 노트 초안
- **협업**: seo-specialist (키워드), product-manager (메시지)

---

## 5. 세일즈팀 (Sales)

> B2B/B2C 영업, 파트너십, 고객 성공 — 매출 성장 전담

### enterprise-sales — B2B 엔터프라이즈 영업 전문가
- **역할**: 기업 고객 발굴 + 엔터프라이즈 라이선스 제안 + 계약 클로징
- **담당**:
  - 기업 대상 프리미엄 서비스 세일즈
  - 의사결정자(CTO/VP Engineering/HR) 대상 아웃바운드 영업
  - POC(Proof of Concept) 설계 및 파일럿 운영
  - 대기업/중견기업 RFP 대응 및 제안서 작성
  - 연간 계약(ACV) 협상 및 클로징
- **전문 분야**: SaaS B2B 세일즈, 엔터프라이즈 딜 사이클, 솔루션 셀링
- **투입 시점**: 엔터프라이즈 플랜 런칭 시 즉시 투입
- **참조**: 사업 계획서, 제품 전략 문서
- **협업**: biz-strategist (가격 정책), product-manager (기업 요구사항), customer-success (온보딩)

### partnership-manager — 파트너십 & 채널 영업 전문가
- **역할**: 전략적 파트너십 발굴 + 채널 영업 + 에코시스템 확장
- **담당**:
  - 외부 서비스/플랫폼 연동 파트너십
  - 산업별 제휴 (교육기관, SaaS 플랫폼 등)
  - 리셀러/VAR(Value Added Reseller) 채널 구축
  - 공동 마케팅(Co-marketing) 캠페인 기획
- **전문 분야**: 전략적 제휴, 채널 파트너십, 비즈니스 개발(BD)
- **투입 시점**: 즉시
- **협업**: biz-strategist (파트너 수익 모델), content-creator (공동 콘텐츠), enterprise-sales (채널 딜)

### growth-hacker — 그로스 해킹 & B2C 세일즈 전문가
- **역할**: 개인 사용자 전환율 최적화 + 바이럴 성장 + 퍼널 설계
- **담당**:
  - Free → Pro 전환 퍼널 설계 및 A/B 테스트
  - 인앱 업셀링 타이밍/메시지 최적화
  - Product-Led Growth (PLG) 전략 실행
  - 레퍼럴 프로그램 설계 (친구 초대 → 보상)
  - 커뮤니티 바이럴 (SNS, 포럼 등)
  - 프라이싱 실험 (가격대, 구독 구성 테스트)
- **전문 분야**: PLG, 전환율 최적화(CRO), 퍼널 분석, 커뮤니티 그로스
- **투입 시점**: **즉시 투입** (수익화 모델 최적화 시급)
- **참조**: 웹 analytics, 서비스 내 이벤트 데이터
- **협업**: seo-specialist (유입), content-creator (전환 카피), product-manager (기능 게이팅)

### customer-success — 고객 성공 매니저 (CSM)
- **역할**: 고객 온보딩 + 리텐션 + NPS 관리 + 이탈 방지
- **담당**:
  - 신규 사용자 온보딩 플로우 설계 (FTUE: First-Time User Experience)
  - 사용자 세그먼트별 인게이지먼트 전략 (파워유저/일반/이탈 위험)
  - 고객 피드백 수집 → 제품팀 전달 (Voice of Customer)
  - 이탈 징후 감지 및 선제 대응 (사용 빈도 감소, 미접속 등)
  - 커뮤니티 운영
  - 엔터프라이즈 고객 QBR(Quarterly Business Review) 지원
- **전문 분야**: 고객 성공, 리텐션, NPS/CSAT, 커뮤니티 빌딩
- **투입 시점**: **즉시 투입**
- **협업**: product-manager (피드백 반영), growth-hacker (리텐션 데이터), enterprise-sales (기업 고객 관리)

### sales-engineer — 세일즈 엔지니어 (기술 영업)
- **역할**: 기술 데모 + POC 지원 + 고객 기술 문의 대응 + 연동 컨설팅
- **담당**:
  - 제품 기술 데모 (아키텍처, 보안, 성능 설명)
  - 기업 IT팀 대상 보안/컴플라이언스 질의 응답
  - 배포 가이드 작성
  - API/웹훅 연동 기술 지원
  - 경쟁사 대비 기술 우위 분석 자료 작성
  - POC 환경 구축 및 기술 검증
- **전문 분야**: 기술 프리세일즈, 솔루션 아키텍처
- **투입 시점**: 엔터프라이즈 영업 시 enterprise-sales와 동시 투입
- **참조**: 시스템 아키텍처 문서, 사업 문서
- **협업**: enterprise-sales (기술 동행 영업), backend-dev (기술 질의), security-reviewer (보안 문의)

---

## 6. 사업팀 (Business)

### biz-strategist — 사업 전략가
- **역할**: 수익 모델 설계 + 결제 연동 전략
- **담당**:
  - 수익 모델 설계 (구독, 프리미엄, 부가 서비스 등)
  - 결제 시스템 연동 전략
  - 프라이싱 전략 수립
  - 경쟁사 분석
- **투입 시점**: 유료화 관련 의사결정 시
- **협업**: product-manager (로드맵), frontend-dev (결제 UI), specialist-dev (외부 연동)

---

## Execution Rules

```
1. TeamCreate로 부서별 팀 생성
2. TaskCreate로 부서별 작업 생성
3. 즉시 투입 에이전트를 run_in_background: true로 동시 실행
4. 각 에이전트의 output_file 경로를 반드시 출력 (모니터링용)
5. 에이전트 간 SendMessage로 발견 사항 실시간 공유:
   - security-reviewer → backend-dev: API 보안 감사 결과
   - tester → frontend-dev: UI/기능 테스트 결과
   - product-manager → 전체: 우선순위 변경 시 전파
   - enterprise-sales → sales-engineer: 기술 데모 요청
   - customer-success → product-manager: VOC(고객 피드백) 전달
   - growth-hacker → content-creator: 전환 카피 최적화 요청
6. 각 에이전트는 CLAUDE.md 컨벤션 준수
7. 코드 변경 시 isolation: "worktree" 사용
```

## Dependency Graph

```
                         product-manager (조율)
                               │
       ┌───────────┬───────────┼───────────┬───────────┐
       ▼           ▼           ▼           ▼           ▼
  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
  │ 개발팀   │ │  운영팀   │ │ 세일즈팀  │ │ 마케팅팀  │ │  사업팀   │
  └────┬────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
       │           │            │             │            │
 frontend-dev ── security  enterprise-sales  seo-spec    biz-strategist
      │           │            │             │
 backend-dev    tester    partnership-mgr  content-creator
      │           │            │
 specialist-dev perf-analyst  growth-hacker
      │
 fullstack-dev
                               │
                          customer-success
                               │
                         sales-engineer
```

## Output

- 모든 코드 변경은 worktree에서 작업
- 각 에이전트 완료 시 결과를 사용자에게 간결하게 요약
- 코드 변경은 사용자 확인 후 main에 머지
