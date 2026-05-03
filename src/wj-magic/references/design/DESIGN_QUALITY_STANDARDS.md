# Design Quality Standards — 디자인 품질 공통 원칙

코드에 `HIGH_QUALITY_CODE_STANDARDS.md`가 있듯, 디자인에도 이 문서가 기준이다.
모든 디자인 관련 에이전트(design-dev, design-reviewer)와 스킬이 이 문서를 준거로 삼는다.

---

## 핵심 원칙

### 1. Design System First

프로젝트 루트의 `DESIGN.md` 또는 디자인 토큰 파일이 단일 진실 공급원.
- 색상, 타이포, 스페이싱은 반드시 토큰으로 정의하고 참조
- 하드코딩된 `#hex`, `rgb()`, `px` 매직넘버 금지
- Tailwind arbitrary value (`bg-[#ff0000]`, `p-[13px]`) 최소화

### 2. Anti-Slop (AI 제네릭 방지)

LLM이 생성하는 "동질적 디자인"을 의식적으로 회피한다:
- 상세: `design/ANTI_SLOP_PATTERNS.md` 참조

### 3. Visual Hierarchy (시각적 위계)

모든 화면에 명확한 정보 우선순위가 있어야 한다:
- 하나의 Hero 요소 (가장 눈에 띄는 것)
- 2~3단계의 시각적 계층 (헤딩 → 본문 → 보조)
- 크기, 굵기, 색상, 여백으로 계층 표현

### 4. Intentional Design (의도 있는 설계)

모든 디자인 결정에 이유가 있어야 한다:
- "예쁘니까"가 아니라 "사용자가 X를 먼저 봐야 하니까"
- 장식 요소도 목적이 있어야 함 (분위기, 브랜딩, 구분선 등)

### 5. Accessibility First (접근성 우선)

- WCAG AA 최소 충족 (색상 대비 4.5:1)
- 키보드 탐색 가능
- 시맨틱 HTML (`<button>`, `<nav>`, `<main>`)
- aria 속성 필수 (인터랙티브 요소)
- 상세: `design/COLOR_SYSTEM.md` 접근성 섹션 참조

---

## Hard Limits

| 항목 | 기준 | 근거 |
|------|------|------|
| 색상 대비 | ≥ 4.5:1 (일반 텍스트), ≥ 3:1 (대형 텍스트) | WCAG AA |
| 동시 사용 색상 | ≤ 5개 (배경 제외) | 인지 과부하 방지 |
| 타이포 스케일 | 최대 6단계 | Miller's Law |
| 스페이싱 토큰 | 4px 또는 8px 배수 기반 | 시각적 리듬 |
| 클릭 영역 | ≥ 44x44px (모바일), ≥ 32x32px (데스크톱) | WCAG, Apple HIG |
| 애니메이션 지속 | 150~500ms (UI 전환), ≤ 300ms (마이크로인터랙션) | UX 연구 |
| 폰트 수 | ≤ 2개 패밀리 | 일관성, 로딩 성능 |

---

## 검증 체크리스트 (design-reviewer 기준)

### CRITICAL (FAIL)
- [ ] 색상 대비 WCAG AA 미충족
- [ ] 클릭 영역 44px 미만 (모바일)
- [ ] 시맨틱 HTML 미사용 (`<div>` 버튼, `<div>` 링크)
- [ ] AI Slop 패턴 3개 이상 동시 발견

### HIGH (WARN)
- [ ] 디자인 토큰 미사용 (하드코딩 색상/간격)
- [ ] 시각적 위계 불명확 (모든 요소가 같은 크기/굵기)
- [ ] 반응형 미대응 (320px에서 깨짐)
- [ ] 일관성 없는 스페이싱 (같은 역할에 다른 간격)

### MEDIUM (INFO)
- [ ] 폰트 3개 이상 사용
- [ ] 애니메이션 없음 (정적 전환)
- [ ] 다크모드 미지원 (해당 시)

---

## 하위 레퍼런스

| 문서 | 내용 | 로드 시점 |
|------|------|----------|
| `design/ANTI_SLOP_PATTERNS.md` | AI 제네릭 패턴 목록 + 대안 | **필수** |
| `design/TYPOGRAPHY_SYSTEM.md` | 타이포 스케일, 위계, 가독성 | 텍스트/레이아웃 작업 시 |
| `design/COLOR_SYSTEM.md` | 컬러 이론, 팔레트, 접근성 | 색상/테마 작업 시 |
| `design/SPACING_RHYTHM.md` | 8px 그리드, 시각적 리듬, 여백 | 레이아웃 작업 시 |
| `design/LAYOUT_PATTERNS.md` | 레이아웃 패턴, 반응형 전략 | 페이지/컴포넌트 설계 시 |
| `design/MOTION_PRINCIPLES.md` | 애니메이션 원칙, easing, 지속 시간 | 인터랙션/전환 작업 시 |
