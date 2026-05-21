# Design Token Workflow — 토큰 정의·사용·검수 3단계 강제

> "토큰을 정의했는데 컴포넌트에서 안 쓰면 토큰이 없는 것과 같다."
> 이 문서는 토큰 시스템이 **실제로 작동**하도록 만드는 강제 메커니즘이다.

---

## 핵심 원칙

디자인 토큰은 3단계가 **모두** 완료돼야 시스템으로 작동한다.

| 단계 | 산출물 | 검증 |
|------|-------|------|
| 1. **정의** | `DESIGN.md` + 토큰 파일 (CSS / @theme / JSON) | 시맨틱 이름, 카테고리 분류 |
| 2. **사용** | 컴포넌트 코드 | hex 하드코딩 0건, arbitrary value 0건 |
| 3. **검수** | grep 측정 + design-reviewer | 사용률 ≥ 95%, CRITICAL 차단 |

**한 단계라도 빠지면 자동 FAIL.** 단계 1만 하고 단계 2가 0%인 경우가 가장 흔한 함정.

---

## 단계 1 — 토큰 정의

### Tailwind 4 (`@theme`) — 권장

```css
/* src/styles/index.css */
@import "tailwindcss";

@theme {
  /* 시맨틱 이름 — '회색 400'이 아니라 '본문 텍스트' */
  --color-bg: #f0f2f5;
  --color-ink: #0e1424;
  --color-ink-dim: #5b6379;
  --color-navy: #1b2440;
  --color-line: #2e5dda;
  --color-rule: #c8cdd4;

  --font-display: "Rajdhani", system-ui, sans-serif;
  --font-sans: "Inter", system-ui, sans-serif;
}
```

→ Tailwind가 `bg-bg`, `text-ink`, `bg-navy`, `border-rule`, `font-display` 유틸리티를 **자동 생성**.

### CSS Variables (프레임워크 무관)

```css
:root {
  --color-bg: #f0f2f5;
  --color-ink: #0e1424;
}

.card { background: var(--color-bg); color: var(--color-ink); }
```

### Token JSON (디자인-개발 동기화용)

```json
{
  "color": {
    "bg":  { "value": "#f0f2f5" },
    "ink": { "value": "#0e1424" }
  }
}
```

### 시맨틱 이름 컨벤션 (HARD RULE)

| ❌ 금지 | ✓ 권장 | 이유 |
|---|---|---|
| `--color-blue-500` | `--color-line` | 색이 바뀌어도 의미 유지 |
| `--gray-100` | `--color-bg-soft` | 역할로 부르기 |
| `--color-primary-1` `-2` `-3` | `--color-ink` `--color-ink-dim` `--color-ink-fog` | 의미가 드러나는 이름 |
| `--space-4` (숫자만) | `--space-md` 또는 `--gap-card` | 용도 명시 |

### 최소 필수 토큰 카테고리

`COLOR_SYSTEM.md`의 9개 컬러 역할 + `SPACING_RHYTHM.md`의 7단계 간격 + `TYPOGRAPHY_SYSTEM.md`의 폰트 패밀리 2개. **이 셋이 없으면 다음 단계로 넘어가지 않는다.**

---

## 단계 2 — 토큰 사용

### 권장 사용 패턴

```tsx
// Tailwind 유틸리티 (가장 깔끔)
<div className="bg-bg text-ink border-rule rounded-sm">

// 인라인 style — Tailwind로 표현 안 되는 경우
<div style={{ background: 'var(--color-navy)' }}>

// SVG 속성 — Tailwind 미지원
<polygon fill="var(--color-navy)" stroke="var(--color-line)" />

// 헬퍼 함수 — 카테고리별 색상 분기
function fillFor(cat: NodeCategory): string {
  if (cat === "skill") return "var(--color-navy)";
  if (cat === "agent") return "var(--color-navy-soft)";
  return "var(--color-ink)";
}
```

### ⛔ 금지 패턴

```tsx
// ❌ hex 하드코딩
<div className="bg-[#f0f2f5] text-[#0e1424]">
<div style={{ background: '#1b2440' }}>
<polygon fill="#1b2440" />

// ❌ Tailwind arbitrary value
<div className="p-[13px] mt-[7px]">  // → p-3 mt-2

// ❌ rgb/rgba 하드코딩
<div style={{ background: 'rgba(14,20,36,0.18)' }}>
//   shadow는 예외적으로 허용하되, 가능하면 토큰 기반 shadow로 정의
```

### 예외 허용 범위

| 케이스 | 허용 여부 | 조건 |
|---|---|---|
| `text-white`, `bg-white` | ✓ | Tailwind 내장 시맨틱 |
| 1회성 shadow `rgba(...)` | △ | 가능하면 `--shadow-card` 같은 토큰화 권장 |
| 3rd-party 라이브러리 내부 색 | ✓ | 우리가 통제 못 함 |
| 임시 디버깅 색 | ✗ | 작업 종료 전 제거 |

---

## 단계 3 — 토큰 검수

### grep 기반 사용률 측정

다음 명령으로 **언제든 사용률을 측정**할 수 있다. CI에서도 실행 가능.

```bash
# 컴포넌트 디렉토리에서 hex 잔존 카운트
HEX=$(grep -roE "#[0-9a-fA-F]{3,8}\b" src/components/ src/app/ 2>/dev/null \
  | grep -v "^\\s*//\\|^\\s*\\*" | wc -l)

# 토큰 사용 카운트 (Tailwind 유틸리티 + CSS var)
TOKEN=$(grep -roE "var\\(--color-|var\\(--font-|var\\(--space-|bg-(bg|ink|navy|line|rule|locked)|text-(ink|navy|line)|border-(rule|line|navy)" src/components/ src/app/ 2>/dev/null \
  | wc -l)

TOTAL=$((HEX + TOKEN))
PCT=$((TOKEN * 100 / TOTAL))
echo "토큰 사용률: ${PCT}% (토큰 ${TOKEN} / hex ${HEX})"
```

### 검출 grep 패턴 (CRITICAL 패턴)

| 위반 | regex | 허용치 |
|---|---|---|
| hex 하드코딩 | `#[0-9a-fA-F]{3,8}\b` | **0** |
| Tailwind arbitrary `[#hex]` | `(bg\|text\|border\|fill\|stroke)-\[#[0-9a-fA-F]+\]` | **0** |
| Tailwind arbitrary `[숫자px]` | `\[(\d+)px\]` | **0** (간격은 토큰만) |
| `rgb(...)`, `rgba(...)` 하드코딩 | `rgba?\(\s*\d` | shadow 외 **0** |
| 폰트 하드코딩 | `font-family:\s*["']?[A-Z]` (CSS 직접 작성) | 토큰 외 **0** |

### Pass/Fail 기준

| 토큰 사용률 | 판정 |
|---|---|
| **≥ 95%** | PASS |
| 80~94% | WARN (개선 권장) |
| **< 80%** | **CRITICAL FAIL** — design-reviewer 차단 |

### Pre-commit / CI 통합 (선택)

```bash
# .git/hooks/pre-commit 또는 GitHub Actions
HEX_COUNT=$(grep -roE "#[0-9a-fA-F]{3,8}\b" src/components/ | wc -l)
if [ "$HEX_COUNT" -gt 0 ]; then
  echo "❌ hex 하드코딩 ${HEX_COUNT}건 발견. 토큰으로 교체하세요."
  grep -rnE "#[0-9a-fA-F]{3,8}\b" src/components/
  exit 1
fi
```

---

## 자주 발생하는 함정

### 함정 1: "토큰 정의했으니 끝났다"
DESIGN.md에 20개 토큰을 정의했지만 컴포넌트에서는 모두 hex 하드코딩 — **단계 2가 0%면 정의가 무의미**.

### 함정 2: "토큰 이름이 색깔"
`--color-blue-primary`처럼 색을 이름에 박으면, 나중에 브랜드 컬러가 빨강으로 바뀔 때 모든 컴포넌트를 검색·교체해야 함. **시맨틱 이름** 필수.

### 함정 3: "한 번 토큰 도입 후 방치"
처음엔 잘 쓰다가 새 기능 만들 때 "이 색만 임시로 hex로…" 하다가 점점 늘어남. **검수 단계가 매 PR마다 작동**해야 함.

### 함정 4: "arbitrary value는 빠르니까"
`bg-[#1b2440]`이 한 번 통과되면 그 다음에도 통과됨. **0건 (예외 없음)** 룰이 깨지면 시스템 자체가 무너짐.

### 함정 5: "쉐도우/이펙트는 예외"
`rgba(0,0,0,0.18)` 같은 1회성 shadow는 일견 작아 보이지만, 같은 shadow가 4~5개 컴포넌트에 흩어지면 결국 토큰화가 필요해짐. 처음부터 `--shadow-card`, `--shadow-modal` 같은 토큰으로 잡는 게 유지비용이 더 적음.

---

## DESIGN.md 표준 템플릿 (요약)

`/wj-magic:design`이 새 프로젝트에 생성하는 DESIGN.md는 다음 섹션을 **반드시** 포함한다:

```markdown
# DESIGN.md

## 방향
[editorial-minimalist / dark-futurism / etc.] — 이 방향을 선택한 이유

## 컬러 토큰
| 토큰 | 값 | 용도 |
| --color-bg | #f0f2f5 | 페이지 배경 |
| ... |

## 타이포 토큰
| 토큰 | 값 | 용도 |
| --font-display | Rajdhani | 제목·라벨 |
| ... |

## 스페이싱 토큰
4px 그리드 기반 7단계 (`SPACING_RHYTHM.md` 참조)

## 사용 규칙
- 모든 색상은 토큰만 사용 (hex 0건)
- arbitrary value `[#hex]` 0건
- 검수: `grep -roE "#[0-9a-fA-F]{3,8}\b" src/components/` → 0 결과 유지
```

---

## 관련 문서

| 문서 | 역할 |
|------|------|
| `DESIGN_QUALITY_STANDARDS.md` | Hard Limits에 "토큰 사용률 ≥ 95%" 포함 |
| `COLOR_SYSTEM.md` | 9개 컬러 역할 정의 (이걸 토큰 이름으로 매핑) |
| `TYPOGRAPHY_SYSTEM.md` | 폰트 페어링, 스케일 (토큰 카테고리) |
| `SPACING_RHYTHM.md` | 8px 그리드 (스페이싱 토큰) |
| `ANTI_SLOP_PATTERNS.md` | "하드코딩 색상" 안티패턴 항목 |
| `agents/design-dev.md` | 구현 시 단계 2 강제 |
| `agents/design-reviewer.md` | 단계 3 검수 의무 |
| `rules/design.md` | 자동 주입 강제 톤 |
