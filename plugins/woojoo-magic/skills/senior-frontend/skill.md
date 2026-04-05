---
name: senior-frontend
description: 시니어 프론트엔드 개발 스킬. 프로젝트의 기술 스택을 파악하여 복잡한 인터랙티브 UI, 실시간 통신, 상태 관리, 애니메이션, 성능 최적화를 담당한다. UI 구현, 컴포넌트 개발, 성능 최적화, 프론트엔드 코드 리뷰 시 사용한다.
---

## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../shared-references/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (PlayerId, ChipAmount 등) — `../../shared-references/BRANDED_TYPES_PATTERN.md`
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

# Senior Frontend

프론트엔드 개발 가이드. 프로젝트의 기술 스택과 아키텍처를 파악하여 적용한다.

## Tech Stack

프로젝트의 기술 스택을 파악하여 적용한다. 아래는 일반적인 모던 프론트엔드 기술 스택 예시이며, 실제 프로젝트에 맞게 조정한다.

**언어:** TypeScript
**UI 프레임워크:** React / Vue / Svelte 등 프로젝트에 따라
**빌드 도구:** Vite / Webpack / Next.js 등 프로젝트에 따라
**상태 관리:** Zustand / Redux / Pinia 등 프로젝트에 따라
**애니메이션:** Framer Motion / GSAP / CSS Animations 등 프로젝트에 따라
**스타일링:** TailwindCSS / CSS Modules / Styled Components 등 프로젝트에 따라
**실시간 통신:** WebSocket / SSE / Socket.IO 등 필요 시
**테스트:** Vitest / Jest / Cypress 등 프로젝트에 따라
**패키지 매니저:** npm / pnpm / yarn 등 프로젝트에 따라
**린트/포맷:** ESLint + Prettier

## 프로젝트 구조

프로젝트의 실제 폴더 구조를 파악하여 따른다. 아래는 일반적인 프론트엔드 프로젝트 구조 예시:

```
src/
├── components/
│   ├── common/         — 공통 컴포넌트 (Button, Modal, Input 등)
│   ├── layout/         — 레이아웃 컴포넌트 (Header, Footer, Sidebar)
│   └── features/       — 기능별 컴포넌트
├── hooks/              — 커스텀 훅
├── stores/             — 상태 관리 스토어
├── utils/              — 유틸리티 함수
├── types/              — 타입 정의
├── styles/             — 글로벌 스타일, 테마
├── constants/          — 상수 정의
├── services/           — API 클라이언트, 외부 서비스 연동
└── assets/             — 정적 에셋 (이미지, 폰트 등)
```

## Core Capabilities

### 1. 복잡한 인터랙티브 UI 개발

사용자 인터랙션이 많은 핵심 인터페이스를 구현한다.

**핵심 고려사항:**
- 복잡한 레이아웃 설계 및 컴포넌트 분리
- 사용자 입력 처리 및 피드백
- 조건부 렌더링 및 동적 UI 상태 관리
- 접근성(a11y) 준수

**반응형 대응:**
```
데스크톱: >= 1024px — 풀 레이아웃
태블릿:  768~1023px — 축소된 레이아웃, 일부 요소 재배치
모바일:  < 768px    — 세로 레이아웃, 터치 최적화
```

### 2. 애니메이션

몰입감과 사용성을 높이는 애니메이션을 구현한다.

**주요 고려사항:**
- 진입/퇴장 애니메이션 (mount/unmount 처리)
- 레이아웃 전환 애니메이션
- 마이크로 인터랙션 (hover, press, feedback)
- 로딩/스켈레톤 애니메이션
- 스크롤 기반 애니메이션
- 성능에 영향을 주지 않는 적절한 duration과 easing 선택

### 3. 실시간 통신

WebSocket 등을 통해 서버와 실시간 양방향 통신을 관리한다.

**핵심 기능:**
- 연결 관리 — 접속, 재접속, 연결 해제 처리
- 이벤트 기반 메시지 수신/발신
- 에러 핸들링 — 연결 끊김 감지, 자동 재연결 (exponential backoff)
- 서버-클라이언트 상태 동기화
- 하트비트(ping/pong)로 연결 상태 확인

**메시지 패턴:**
```typescript
// 서버 → 클라이언트: 상태 업데이트
type ServerEvent =
  | { type: 'STATE_UPDATE'; payload: AppState }
  | { type: 'NOTIFICATION'; payload: { message: string } }

// 클라이언트 → 서버: 사용자 액션
type ClientEvent =
  | { type: 'USER_ACTION'; payload: { action: string; data?: unknown } }
  | { type: 'SUBSCRIBE'; payload: { channel: string } }
```

### 4. 상태 관리

복잡한 애플리케이션 상태를 효율적으로 관리한다.

**스토어 설계 원칙:**
- 도메인별로 스토어를 분리
- 서버 상태와 클라이언트 상태를 구분
- 파생 상태(computed/derived)는 selector로 처리
- 불변성 유지

**패턴:**
```typescript
// 스토어 예시 (Zustand)
interface AppStore {
  data: Data | null;
  isLoading: boolean;
  error: Error | null;
  actions: {
    fetchData: () => Promise<void>;
    updateData: (data: Partial<Data>) => void;
    reset: () => void;
  };
}
```

### 5. 데이터 검증 및 무결성

클라이언트 사이드에서의 데이터 검증 로직을 담당한다.

**기능:**
- 폼 유효성 검사
- 서버 응답 데이터 검증
- 타입 가드를 활용한 런타임 타입 체크
- 검증 결과 시각화

## Reference Documentation

### React Patterns

프로젝트에 적용하는 React 패턴 가이드. `references/react_patterns.md` 참조:

- 컴포넌트 설계 패턴 (Compound, Render Props, HOC 등)
- 커스텀 훅 패턴
- 렌더링 최적화 (React.memo, useMemo, useCallback)
- 조건부 렌더링 패턴
- 에러 바운더리 활용

### 빌드 최적화 가이드

빌드 및 번들 최적화 전략. `references/nextjs_optimization_guide.md` 참조:

- 코드 스플리팅, 트리 쉐이킹
- 에셋 최적화 (이미지 로딩 전략)
- lazy loading (비핵심 화면)
- 번들 사이즈 관리
- HMR(Hot Module Replacement) 활용

### Frontend Best Practices

프론트엔드 품질 관리 가이드. `references/frontend_best_practices.md` 참조:

- TypeScript 엄격 모드 활용
- 디자인 토큰 관리
- 접근성 고려사항
- 에러 바운더리 설정
- 테스트 전략

## Design System

프로젝트의 디자인 시스템을 따른다. 프로젝트에 디자인 시스템 문서가 있다면 해당 문서를 참조하고, 없다면 아래 원칙을 적용한다.

### 일반 원칙
- 일관된 컬러 팔레트와 타이포그래피 사용
- 디자인 토큰(색상, 간격, 폰트 크기 등)을 중앙에서 관리
- 컴포넌트 단위로 스타일 캡슐화
- 반응형 브레이크포인트 통일
- 접근성 대비율(contrast ratio) 준수

## Development Workflow

### 1. 환경 설정

```bash
# 의존성 설치
npm install  # 또는 pnpm install, yarn install

# 환경 변수 설정
cp .env.example .env
```

### 2. 개발 서버 실행

```bash
# 개발 서버 실행
npm run dev  # 또는 프로젝트의 개발 서버 명령어
```

### 3. 개발 흐름

1. **컴포넌트 개발** — 컴포넌트 디렉토리에서 UI 작업, HMR로 즉시 반영
2. **상태 연동** — 스토어에 상태 정의, 컴포넌트에서 구독
3. **API/통신 연동** — 서비스 레이어를 통해 서버와 통신
4. **애니메이션 적용** — 프로젝트의 애니메이션 라이브러리 활용
5. **타입 공유** — 공유 타입 정의를 클라이언트/서버 양쪽에서 import (해당 시)

### 4. 빌드 및 검증

```bash
# 프로덕션 빌드
npm run build

# 타입 체크
npm run typecheck  # 또는 tsc --noEmit

# 린트
npm run lint

# 테스트
npm run test

# 빌드 미리보기
npm run preview
```

## 코드 품질 기준

**상세 기준: `references/HIGH_QUALITY_CODE_STANDARDS.md` 참조**

### 핵심 요약
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄 — 초과 시 무조건 분할
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드
- God Component 금지 → 서브 컴포넌트 추출
- useEverything() 금지 → 훅 = 단일 책임
- CSS animation > JS animation (성능)
- 같은 패턴 2곳 이상 → 공통 유틸 추출

## Best Practices Summary

### UI
- 컴포넌트를 작고 재사용 가능하게 분리
- 반응형 대응: 데스크톱/태블릿/모바일 레이아웃 분리
- 정보를 명확하게 분리 표시
- 애니메이션은 UX를 방해하지 않도록 적절한 duration 유지

### 상태 관리
- 스토어는 도메인별 슬라이스로 분리
- 셀렉터로 구독 범위 제한 (전체 구독 금지)
- 대형 액션 → 별도 파일
- 서버 상태 신뢰, 중복 계산 금지

### 성능
- React.memo 등으로 빈번히 리렌더되는 컴포넌트 최적화
- CSS @keyframes > JS animation repeat: Infinity (GPU 합성)
- backdrop-blur 동시 3개 이하
- filter(brightness, blur) 애니메이션 금지 → transform/opacity만
- 비핵심 화면은 lazy loading + 코드 스플리팅

### 실시간 통신 안정성
- 연결 끊김 시 자동 재연결 (exponential backoff)
- 재연결 후 상태 동기화 요청
- 네트워크 상태 UI 표시 (연결됨/재연결 중/오프라인)
- 하트비트(ping/pong)로 연결 상태 확인

### 코드 품질
- 공유 타입을 활용하여 타입 일관성 유지
- 비즈니스 로직은 순수 함수로 작성하여 테스트 용이하게
- 커스텀 훅으로 로직을 컴포넌트에서 분리
- 디자인 토큰을 중앙에서 관리

## Troubleshooting

### Common Issues

| 증상 | 원인 | 해결 |
|------|------|------|
| 실시간 연결 실패 | 서버 미실행 또는 CORS 설정 | 서버 실행 확인, 프록시 설정 확인 |
| HMR 작동 안 함 | 빌드 도구 캐시 문제 | 캐시 디렉토리 삭제 후 재시작 |
| 타입 에러 (공유 패키지) | 공유 패키지 빌드 안 됨 | 공유 패키지 먼저 빌드 |
| 정적 에셋 안 보임 | 에셋 경로 문제 | 빌드 도구의 정적 에셋 경로 설정 확인 |
| 애니메이션 끊김 | 레이아웃 충돌 또는 리렌더 | layoutId 중복 확인, will-change CSS 적용 |
| 의존성 충돌 | 패키지 매니저 호이스팅 문제 | 의존성 재설치 또는 node_modules 삭제 후 재설치 |

### Getting Help

- React 패턴 참고: `references/react_patterns.md`
- 빌드 최적화 참고: `references/nextjs_optimization_guide.md`
- 프론트엔드 가이드 참고: `references/frontend_best_practices.md`
- 프로젝트 문서: 프로젝트의 `docs/` 디렉토리 참조

## Resources

- **Code Quality Standards: `references/HIGH_QUALITY_CODE_STANDARDS.md`** — 범용 코드 품질 기준 (필수)
- Pattern Reference: `references/react_patterns.md`
- Optimization Guide: `references/nextjs_optimization_guide.md`
- Technical Guide: `references/frontend_best_practices.md`
