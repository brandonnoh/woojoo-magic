# CTO 전수 점검 체크리스트

## 공통 체크리스트 (모든 도메인)

### 파인 코드 (Code Quality)
- [ ] 함수 길이: 30줄 이상 → 서브 함수 분리 검토
- [ ] 파일 길이: 200줄 이상 → 모듈 분리 검토
- [ ] 순환 복잡도: if/for 중첩 3단계 이상 → 단순화
- [ ] 매직 넘버/스트링 → 명명된 상수로 추출
- [ ] 중복 코드 → DRY 원칙 적용 (공통 모듈 추출)
- [ ] 미사용 코드/변수/import → 삭제
- [ ] 네이밍 컨벤션 일관성 (camelCase, PascalCase, UPPER_SNAKE)
- [ ] 에러 핸들링: try-catch, 예외 전파, 사용자 에러 메시지
- [ ] 주석: 핵심 로직에만, 코드로 설명 가능한 부분은 주석 불필요

### 타입 안전성 (TypeScript)
- [ ] `any` 사용 여부 → 구체적 타입으로 교체
- [ ] `as` 타입 단언 남용 → 타입 가드 사용
- [ ] `!` non-null assertion → null 체크 또는 옵셔널 체이닝
- [ ] strict mode 준수 (noImplicitAny, strictNullChecks)
- [ ] 함수 시그니처에 반환 타입 명시 여부

### 확장성
- [ ] 새 기능 추가 시 수정해야 할 파일 수 (적을수록 좋음)
- [ ] Open-Closed 원칙: 확장에 열리고 수정에 닫힌 구조인가
- [ ] 플러그인/전략 패턴으로 분리 가능한 로직
- [ ] 하드코딩된 비즈니스 규칙 → 설정 파일 또는 인터페이스로 추상화

### 모듈화
- [ ] 순환 의존 여부 (모듈 A → B → A)
- [ ] 단일 책임 원칙 (SRP) 준수
- [ ] 모듈 간 결합도 (낮을수록 좋음)
- [ ] 모듈 내 응집도 (높을수록 좋음)
- [ ] barrel export (index.ts) 적절한 사용

---

## 도메인별 체크리스트

### 1. Core / Engine / Shared

**비즈니스 로직:**
- [ ] 순수 함수 여부 (입력 → 출력, side effect 없음)
- [ ] 상태 불변성 (spread operator로 복사 후 수정)
- [ ] 테스트 가능성 (mocking 없이 테스트 가능한 구조)
- [ ] 브라우저/Node.js 양쪽에서 동작하는지

**타입 정의:**
- [ ] 미사용 타입/인터페이스 → 삭제
- [ ] JSON 직렬화 가능 여부 (Set, Map, Date → Array, Object, string)
- [ ] 타입 정의와 실제 사용의 일치

**테스트 품질:**
- [ ] 커버리지: 핵심 함수별 최소 3개 테스트
- [ ] 엣지 케이스: 빈 배열, null, 경계값, 오버플로우
- [ ] 테스트 중복: 공통 헬퍼 추출 가능성
- [ ] 결정론적 테스트: 랜덤 의존성 있으면 시드 주입 구조
- [ ] 테스트 파일 자체의 품질 (가독성, 구조화)

**패키지 준비:**
- [ ] package.json exports 필드 설정
- [ ] engines 필드 (Node.js 버전 명시)
- [ ] npm publish 가능 구조 (private: true 의도적인지)

---

### 2. Frontend (React/Vue/Svelte 등)

**컴포넌트 품질:**
- [ ] 컴포넌트 길이: 150줄 이상 → 서브 컴포넌트 분리
- [ ] 인라인 스타일 vs CSS 클래스 일관성
- [ ] 이벤트 핸들러 인라인 정의 vs 추출
- [ ] 조건부 렌더링 복잡도 (3단 이상 중첩 → 컴포넌트 분리)
- [ ] key prop 적절한 사용 (인덱스 vs 고유 ID)

**React Hooks:**
- [ ] useEffect 의존성 배열 정확성
- [ ] useEffect 정리 함수 (cleanup) 존재
- [ ] useState vs useEffect 오용 (side effect는 useEffect)
- [ ] useMemo/useCallback 필요한 곳 (비용 높은 계산, 참조 안정성)
- [ ] 커스텀 훅 추출 가능성

**상태 관리 (Zustand/Redux 등):**
- [ ] God Store: 한 스토어에 과도한 상태 → 분리
- [ ] 선택적 구독: 전체 스토어 구독 vs 개별 selector
- [ ] 비즈니스 로직이 스토어에 있지 않은지 → 별도 모듈로
- [ ] 스토어 간 결합도

**성능:**
- [ ] React.memo 적용 (자주 리렌더되는 컴포넌트)
- [ ] Code Splitting (React.lazy + Suspense)
- [ ] 이미지/에셋 최적화 (lazy loading, WebP)
- [ ] 번들 사이즈 (tree-shaking, 동적 import)
- [ ] setTimeout/setInterval 정리 (메모리 누수)
- [ ] Canvas/애니메이션 성능 (requestAnimationFrame, will-change)

**접근성 (a11y):**
- [ ] aria-label, aria-describedby, role 사용
- [ ] 키보드 내비게이션 (Tab, Enter, Escape)
- [ ] 포커스 관리 (모달 포커스 트랩)
- [ ] 색상 대비 (WCAG AA 4.5:1)
- [ ] 색상만으로 정보 전달하지 않기
- [ ] prefers-reduced-motion 존중
- [ ] 스크린 리더 호환 (시맨틱 HTML)
- [ ] 터치 타겟 최소 44x44px

**라우팅:**
- [ ] 라우트 경로 상수화 (하드코딩 금지)
- [ ] 404 라우트 존재
- [ ] ErrorBoundary 존재
- [ ] 라우트 기반 코드 스플리팅

**확장성:**
- [ ] i18n 대응 구조 (문자열 하드코딩 vs 상수/리소스)
- [ ] 테마 시스템 (CSS 변수, 테마 전환 가능성)
- [ ] 기능 플래그 시스템

---

### 3. Backend (Node.js/Express/WebSocket 등)

**아키텍처:**
- [ ] God Class/File: 한 파일에 과도한 책임 → 분리
- [ ] 관심사 분리: 라우팅, 핸들러, 비즈니스 로직, 데이터 접근
- [ ] 의존성 주입 (DI): 하드코딩된 `new` → 주입 가능 구조
- [ ] 미들웨어 패턴 적용 (인증, 검증, 로깅 공통화)

**보안:**
- [ ] 입력 검증: 모든 외부 입력을 zod/joi 등으로 스키마 검증
- [ ] `JSON.parse` 후 `as` 캐스팅 금지 → 런타임 검증 필수
- [ ] CORS 설정: `origin: '*'` 금지 → 화이트리스트
- [ ] Rate Limiting: IP/연결당 요청 제한
- [ ] 인증/인가: 토큰 검증, 권한 체크
- [ ] XSS/Injection 방어
- [ ] 환경 변수로 시크릿 관리 (하드코딩 금지)
- [ ] 프로토타입 오염 방어
- [ ] **관리자 페이지 인증 미들웨어**: `/admin` 등 관리자 경로에 URL 직접 접근만으로 진입 불가하도록 인증 미들웨어 필수 적용. 뻔한 경로명 노출 자제.
- [ ] **Supabase RLS 활성화**: 모든 테이블에 Row Level Security 활성화 여부 확인. RLS 미설정 시 타 사용자의 이메일·결제 내역 등 민감 데이터 API 직접 조회 가능.
- [ ] **환경 변수 프론트엔드 노출 방지**: API 키·시크릿이 `NEXT_PUBLIC_` 등 클라이언트 번들에 포함되는지 확인. 브라우저 개발자 도구 네트워크/콘솔 탭에서 키 노출 여부 점검.
- [ ] **결제 금액 서버 검증**: 클라이언트 전송 결제 금액을 그대로 신뢰하지 말 것. 서버에서 DB의 실제 상품 가격을 조회하여 금액 일치 여부를 반드시 검증.
- [ ] **에러 메시지 상세 정보 숨김**: 프로덕션 환경에서 Stack Trace, DB 테이블명, 파일 경로 등이 클라이언트에 노출되지 않도록 설정. 상세 에러는 서버 로그에만 기록.

**운영:**
- [ ] 구조화 로거 (pino/winston): console.log 금지
- [ ] 헬스체크 엔드포인트 (/health)
- [ ] Graceful Shutdown (SIGTERM/SIGINT 핸들러)
- [ ] 메트릭/모니터링 (Prometheus, Sentry)
- [ ] 환경 변수 스키마 검증 (zod)
- [ ] .env.example 파일 존재

**확장성:**
- [ ] 수평 확장 가능 여부 (인메모리 상태 → Redis 등 외부화)
- [ ] 동시 접속 제한 처리
- [ ] 타이머/인터벌 관리 (누수 방지, 정리 로직)
- [ ] Dead Code: 호출되지 않는 함수/핸들러
- [ ] 이벤트 기반 통신 (직접 메서드 호출 → EventEmitter/메시지 큐)

**테스트:**
- [ ] 서버 테스트 존재 여부
- [ ] 단위 테스트 (비즈니스 로직)
- [ ] 통합 테스트 (API 엔드포인트, WebSocket 시나리오)
- [ ] 입력 검증 스키마 테스트

---

### 4. DX / Infrastructure

**모노레포:**
- [ ] 패키지 간 의존성 그래프가 DAG (순환 없음)
- [ ] workspace 프로토콜 사용 (workspace:*)
- [ ] Turborepo/Nx 캐시 설정 최적화
- [ ] dev 스크립트 병렬 실행 가능
- [ ] 패키지별 tsconfig 상속 구조

**CI/CD:**
- [ ] GitHub Actions (또는 동등) 워크플로우 존재
- [ ] PR 체크: lint + test + build
- [ ] 배포 파이프라인 정의
- [ ] 환경별 설정 분리 (dev/staging/prod)

**코드 공유:**
- [ ] 패키지 간 중복 코드 식별 (같은 컴포넌트, 같은 설정)
- [ ] 공통 설정 패키지 가능성 (eslint-config, tsconfig, tailwind-config)
- [ ] 공통 UI 패키지 가능성

**설정 일관성:**
- [ ] ESLint 규칙이 모든 패키지에 적합한지 (프론트 vs 백엔드)
- [ ] TypeScript 설정 상속 구조
- [ ] CSS/Tailwind 테마 일관성 (패키지 간 색상/폰트 불일치)
- [ ] .gitignore 완전성

**문서:**
- [ ] .env.example 존재
- [ ] README 또는 DEV.md (개발 시작 가이드)
- [ ] 포트/URL 빠른 참조
- [ ] 아키텍처 다이어그램

---

## Wave 전략 템플릿

### 의존성 분석
```
패키지 A → (아무것도 의존 안 함)     → Wave 1 후보
패키지 B → A를 import               → Wave 2 후보
패키지 C → A를 import               → Wave 2 후보 (B와 병렬 가능)
패키지 D → B, C를 import            → Wave 3 후보
```

### Wave 배치 규칙
1. **Wave 1**: 다른 패키지가 의존하는 기반 패키지 (shared, types, utils)
2. **Wave 2**: Wave 1에 의존하지만 서로 독립적인 패키지들 (병렬 실행)
3. **Wave 3**: Wave 2에 의존하는 패키지 (필요시)
4. **각 Wave 내에서**: 파일 소유권 엄격 분리 → 충돌 0

### 머지 순서
```
Wave 1 에이전트 완료 → 커밋 → main 머지 → 테스트 확인
                                              ↓
Wave 2 에이전트들 완료 → 각각 커밋 → main에 순차 머지 → 테스트
                                              ↓
워크트리 + 브랜치 정리
```

---

## 산출물 형식

### 분석 보고서
```markdown
# CTO 전수 점검 보고서 — [도메인]

## 요약
| 심각도 | 건수 | 주요 카테고리 |
|--------|------|---------------|

## 이슈 목록
### CRITICAL
[CRITICAL-ARCH-001] 파일명:라인 — 문제 설명
  수정 방향: ...

### HIGH
...

## 리팩토링 우선순위 매트릭스
(영향도 x 복잡도 2x2 그리드)

## 구체적 리팩토링 플랜
### Phase 1: 즉시 개선 (Quick Wins)
### Phase 2: 구조 개선
### Phase 3: 확장성 기반
```

### 통합 결과 테이블
```markdown
| 도메인 | CRITICAL | HIGH | MEDIUM | LOW | 합계 |
|--------|----------|------|--------|-----|------|
```
