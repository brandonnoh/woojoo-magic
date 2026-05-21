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
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.vue"
  - "**/*.svelte"
---

## Design Rules — 디자인 토큰 강제 룰

### ⛔ 디자인 토큰 3단계 강제 (HARD RULE — 예외 없음)

이 규칙이 자동 주입되는 모든 파일은 다음 3단계를 **반드시** 충족한다.

**상세 워크플로우**: `references/design/DESIGN_TOKEN_WORKFLOW.md` (반드시 Read로 로드)

| 단계 | 강제 사항 | 위반 시 |
|------|----------|---------|
| 정의 | 프로젝트에 `DESIGN.md` + 토큰 파일 (Tailwind `@theme` / CSS var) 존재 | design-dev가 작업 시작 전 생성 강제 |
| 사용 | hex 하드코딩 **0건**, Tailwind arbitrary `[#hex]`·`[Npx]` **0건** | quality-check 훅 경고 + design-reviewer FAIL |
| 검수 | grep 측정 사용률 ≥ 95% | < 80%이면 design-reviewer CRITICAL FAIL |

### 토큰 사용 — 권장 vs 금지

```tsx
// ✓ 권장
<div className="bg-bg text-ink border-rule" />
<div style={{ background: 'var(--color-navy)' }} />
<polygon fill="var(--color-navy)" stroke="var(--color-line)" />

// ❌ 금지 (CRITICAL — 발견 시 즉시 수정)
<div className="bg-[#f0f2f5] text-[#0e1424]" />     // arbitrary [#hex]
<div style={{ background: '#1b2440' }} />            // 인라인 hex
<polygon fill="#1b2440" />                           // SVG hex
<div className="p-[13px] mt-[7px]" />                // arbitrary [Npx]
```

### grep 검출 패턴 (CI에서 차단)

```bash
# 0건이어야 함
grep -rE "#[0-9a-fA-F]{3,8}\b" src/components/ src/app/    # hex
grep -rE "(bg|text|border|fill|stroke)-\[#" src/           # arbitrary [#hex]
grep -rE "\[(?:[0-9]+)px\]" src/                           # arbitrary [Npx]
grep -rE "rgba?\(\s*[0-9]" src/components/                 # rgba hardcoded (shadow 예외)
```

### MCP 필수 (디자인 작업 시)

- 컴포넌트 조회: **shadcn** MCP (커스터마이징 기반)
- 라이브러리 API: **Context7** 조회 필수 (Tailwind, Framer Motion, shadcn/ui)
- 토큰 위치 추적: **Serena** `find_symbol` + `find_referencing_symbols`

### Anti-Slop 체크 (상세는 ANTI_SLOP_PATTERNS.md)

- AI Purple (indigo/violet/purple) 그라디언트 사용 시 즉시 재검토
- 모든 카드 동일 shadow → elevation 차등 적용
- hover 전용 피드백 → hover + focus + active 3종 필수
- 모든 요소 rounded-xl → 컴포넌트별 의도적 radius 체계

### 접근성 필수 (WCAG AA)

- 색상 대비 ≥ 4.5:1 (일반), ≥ 3:1 (대형)
- 시맨틱 HTML (`<button>`, `<nav>`, `<main>`, `<section>`)
- aria 속성 (인터랙티브 요소: `aria-label`, `aria-live`)
- 키보드 포커스 상태 (`focus-visible:ring-2` 필수)
- SVG 인터랙티브 요소: `role="button"` + `tabIndex={0}` + `onKeyDown` (Enter/Space)

### QA 흐름

1. 구현 → 셀프 grep (`grep -rE "#[0-9a-fA-F]" src/`) → **0건 확인**
2. 사용률 측정 → ≥ 95% 확인
3. **design-reviewer** 에이전트로 디자인 리뷰 필수 (출력 프로토콜에 토큰 사용률 % 반드시 포함)
