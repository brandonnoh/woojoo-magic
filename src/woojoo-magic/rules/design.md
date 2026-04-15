---
globs:
  - "**/*.css"
  - "**/*.scss"
  - "**/*.module.css"
  - "**/*.module.scss"
  - "**/*.styled.ts"
  - "**/*.styled.tsx"
  - "**/*.styles.ts"
  - "**/*.styles.tsx"
---

## Design Rules

### 디자인 레퍼런스 필수
- 디자인 구현 시: `references/design/DESIGN_QUALITY_STANDARDS.md` 로드 필수
- AI Slop 방지: `references/design/ANTI_SLOP_PATTERNS.md` 참조
- 프로젝트 DESIGN.md가 있으면 토큰 우선 준수

### MCP 필수
- 컴포넌트 조회: **shadcn** MCP (커스터마이징 기반)
- 라이브러리 API: **Context7** 조회 필수 (Tailwind, Framer Motion 등)

### Anti-Slop 체크
- 하드코딩 색상 (`#hex`, `rgb()`) 대신 디자인 토큰/CSS 변수 사용
- Tailwind arbitrary value (`bg-[#ff0000]`) 최소화
- 매직넘버 간격 (`p-[13px]`) 대신 8px 배수 토큰
- 모든 인터랙티브 요소에 hover + focus + active 상태

### 접근성 필수
- 색상 대비 WCAG AA (4.5:1 이상)
- 시맨틱 HTML (`<button>`, `<nav>`, `<main>`, `<section>`)
- aria 속성 (인터랙티브 요소)
- 키보드 포커스 상태 (focus-visible)

### QA 필수
- 디자인 구현 완료 후: **design-reviewer** 에이전트로 디자인 리뷰 필수
