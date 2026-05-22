---
name: qa-frontend
description: >
  프론트엔드 결함을 자동·시각 병행으로 잡아내는 게이트 스킬.
  Playwright 4 viewport 풀페이지 캡처(사람 눈 검수) + Chrome DevTools MCP 모바일 Lighthouse
  (Accessibility/Best Practices/SEO/Agentic Browsing) + Performance Trace(LCP/CLS/TTFB)를
  병행 측정하고, 결함을 우선순위로 정렬해 토큰·메타·접근성 단순 수정은 자동 적용한 뒤
  재측정 루프로 점수를 끌어올린다.
  UI 작업 후 배포 직전, "프론트 검수해줘", "라이트하우스 돌려줘", "반응형 확인",
  "QA 프론트", "qa-frontend", "성능 측정", "접근성 점검", "비주얼 회귀", "viewport 캡처",
  "LCP 측정", "Mobile Lighthouse" 요청에 트리거.
  단순 코드 리뷰는 qa-reviewer, 시각 디자인 진단은 design-reviewer 또는 polish 스킬을 사용한다.
---

**품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)

# /wj-magic:qa-frontend — 프론트엔드 실측 QA 게이트

UI를 "잘 만들었다" 주장하기 전, 실제 브라우저에서 측정한 **숫자와 캡처**로 결함을 잡는다.
정성적 리뷰(design-reviewer)만으로는 잡히지 않는 모바일 회귀·성능 회귀·접근성 위반을 실측으로 닫는다.

<HARD-GATE>
검증 증거(스크린샷·Lighthouse JSON·Performance trace) 없이 "프론트 QA 통과" 주장 금지.
"코드는 깨끗하니까 괜찮을 거야" 는 검증이 아니다.
</HARD-GATE>

## ⛔ MCP 필수 사용 (HARD RULE)

이 스킬은 **MCP 도구 없이는 실행 불가**다. 사용자에게 MCP 미설치/미연결을 즉시 보고하고 중단한다.

### Playwright (필수) — Visual Responsive
- `mcp__playwright__browser_navigate` — 핵심 페이지 진입
- `mcp__playwright__browser_resize` — 4 viewport 전환 (375 / 768 / 1024 / 1440)
- `mcp__playwright__browser_take_screenshot` — `fullPage: true` 풀페이지 캡처
- `mcp__playwright__browser_snapshot` — DOM/ARIA 스냅샷 (접근성 보조 검증)
- `mcp__playwright__browser_console_messages` — 콘솔 에러·경고 수집

### Chrome DevTools (필수) — Lighthouse + Performance
- `mcp__chrome-devtools__lighthouse_audit` — 모바일 navigation audit
  (categories: `accessibility`, `best-practices`, `seo`, `agentic-browsing`)
- `mcp__chrome-devtools__performance_start_trace` — LCP / CLS / TTFB / INP 트레이스 시작
- `mcp__chrome-devtools__performance_stop_trace` — 트레이스 종료 + 인사이트 수집
- `mcp__chrome-devtools__performance_analyze_insight` — 병목 인사이트 상세 분석
- `mcp__chrome-devtools__list_console_messages` — 런타임 에러 수집

> 실제 등록명: `mcp__playwright__browser_*`, `mcp__plugin_wj-magic_chrome-devtools__*`
> (사용자 표기 `mcp__chrome-devtools__*` 는 wj-magic 플러그인 내 chrome-devtools 서버를 가리킨다)

### Serena (코드 자동 수정 시) — Step 4 진입 전 필수
- `find_symbol` / `find_referencing_symbols` — 토큰·메타 수정 대상 심볼 추적
- 추측으로 파일·심볼 지목 금지

## 품질 기준 (PASS 조건)

| 영역 | 목표 | FAIL 임계치 |
|------|------|-------------|
| Mobile Lighthouse — Accessibility | 100 | < 95 |
| Mobile Lighthouse — Best Practices | 100 | < 95 |
| Mobile Lighthouse — SEO | 100 | < 95 |
| Mobile Lighthouse — Agentic Browsing | 100 | < 90 |
| LCP (Largest Contentful Paint) | < 2.5s | ≥ 4.0s |
| CLS (Cumulative Layout Shift) | < 0.1 | ≥ 0.25 |
| TTFB (Time to First Byte) | < 200ms | ≥ 800ms |
| INP (Interaction to Next Paint) | < 200ms | ≥ 500ms |
| Color-contrast 위반 | 0건 | ≥ 1건 |
| Console error / warning | 0건 | ≥ 1건 (error) |
| 4 viewport 풀페이지 캡처 누락 | 0건 | ≥ 1건 |

**검증 사례 (solarmoa, 2026-05):** Mobile Lighthouse 4종 100·LCP 1.25s·CLS 0·TTFB 15ms.
color-contrast 28건 → `globals.css` 토큰 2개 darken 한 사이클로 해소.

## 토큰 예산

| Step | 예상 토큰 |
|------|---------|
| Step 0 (환경 점검) | ~1,000 |
| Step 1 (Visual Responsive 4 viewport) | ~4,000 |
| Step 2 (Lighthouse Audit) | ~3,000 |
| Step 3 (Performance Trace) | ~3,000 |
| Step 4 (결함 정렬 + 자동 수정) | ~5,000-15,000 |
| Step 5 (재측정 루프) | ~6,000-12,000 (1-2 사이클) |
| Step 6 (리포트) | ~2,000 |
| **전체** | **~24,000-40,000** |

---

## Step 0: 환경 점검 & 대상 식별

**목표:** 측정 가능한 환경을 확보하고, 어떤 페이지를 어떤 viewport로 검수할지 확정한다.

```
체크리스트:
□ Dev/preview 서버 기동 확인 (BASE_URL 확인 — 기본 http://localhost:5173 또는 :3000)
□ 핵심 페이지 목록 수집 (router 또는 사용자 입력)
□ 산출물 디렉토리 생성: mkdir -p .dev/qa-frontend/$(date +%Y%m%d-%H%M)
□ MCP 서버 연결 확인 (Playwright + Chrome DevTools 둘 다 응답해야 함)
□ 사용자에게 검수 대상 페이지 확정 받기
```

서버가 안 떠 있으면 사용자에게 띄워달라고 요청한 뒤 중단. **추측으로 진행 금지.**

대상 페이지 후보가 많으면 다음 우선순위로 자르기:
1. 랜딩 / 홈
2. 핵심 전환 페이지 (제품, 가입, 결제, 대시보드)
3. 사용자가 직전에 수정한 파일이 렌더링되는 페이지
4. 인증 직후 첫 화면

---

## Step 1: Visual Responsive — 4 viewport 풀페이지 캡처

**목표:** 모바일~데스크탑 4개 viewport에서 풀페이지를 캡처해 사람 눈으로 결함을 확인한다.

```
viewport 매트릭스 (모바일 우선):
  375  — iPhone SE / 작은 모바일 (가장 깨지기 쉬움)
  768  — 태블릿 세로 / iPad mini
  1024 — 태블릿 가로 / 작은 노트북
  1440 — 데스크탑 표준
```

각 페이지 × 4 viewport 매트릭스로 실행:

```
1. mcp__playwright__browser_navigate({ url: <page_url> })
2. mcp__playwright__browser_resize({ width: 375, height: 812 })
3. mcp__playwright__browser_take_screenshot({
     fullPage: true,
     filename: ".dev/qa-frontend/<timestamp>/<page>-375.png"
   })
4. width 768/1024/1440 반복
5. mcp__playwright__browser_console_messages — 콘솔 에러/경고 수집
```

캡처는 산출물 디렉토리에 저장한다. 사용자에게 캡처 경로를 보고해 **눈으로 확인**할 수 있게 한다 (자동 비전 진단은 보조, 사람 검수가 핵심).

자동 비전 진단 체크리스트 (캡처에서 감지):
- [ ] 375에서 가로 스크롤 발생 여부
- [ ] 텍스트 잘림 / overflow / 줄바꿈 깨짐
- [ ] 클릭 타깃 44px 미만 의심 영역
- [ ] 빈 영역 / 미로드 이미지
- [ ] 폰트 미적용(serif fallback) 의심

---

## Step 2: Lighthouse Mobile Navigation Audit

**목표:** Accessibility / Best Practices / SEO / Agentic Browsing 4종 점수 + 위반 항목 수집.

각 핵심 페이지에 대해:

```
mcp__chrome-devtools__lighthouse_audit({
  url: <page_url>,
  device: "mobile",
  mode: "navigation",
  categories: ["accessibility", "best-practices", "seo", "agentic-browsing"]
})
```

결과 파싱:
- 점수 4종 → `.dev/qa-frontend/<timestamp>/lighthouse-<page>.json`
- 위반 audit 추출 (특히 `color-contrast`, `image-alt`, `meta-description`, `link-name`)
- 모바일 한정 회귀 (tap target, viewport meta) 별도 표시

---

## Step 3: Performance Trace — LCP / CLS / TTFB / INP

**목표:** Core Web Vitals + 병목 인사이트 수집.

```
1. mcp__chrome-devtools__performance_start_trace({
     url: <page_url>,
     reload: true,
     autoStop: true
   })
2. mcp__chrome-devtools__performance_stop_trace()
3. 인사이트 중 우선순위 항목 → mcp__chrome-devtools__performance_analyze_insight
```

추출 지표:
- LCP (element + ms)
- CLS (score + 가장 큰 layout shift 원인)
- TTFB (ms)
- INP (있으면)
- LongTask / 메인 스레드 블로킹 인사이트

산출물: `.dev/qa-frontend/<timestamp>/perf-<page>.json`

---

## Step 4: 결함 정렬 + 자동 수정 (단순건 한정)

**목표:** Step 1~3의 결함을 우선순위로 정렬하고, **안전한 단순 수정만** 자동 적용한다.

### 우선순위 정렬 (CRITICAL → HIGH → MEDIUM → LOW)

| 심각도 | 조건 |
|--------|------|
| CRITICAL | Lighthouse 카테고리 < 90 / LCP ≥ 4s / CLS ≥ 0.25 / 모바일에서 가로 스크롤 / 콘솔 error ≥ 1건 |
| HIGH | Lighthouse < 95 / LCP ≥ 2.5s / CLS ≥ 0.1 / color-contrast 위반 / 클릭 타깃 < 44px |
| MEDIUM | Lighthouse < 100 / TTFB ≥ 200ms / 이미지 alt 누락 / meta description 누락 |
| LOW | Best Practices 권고 / SEO 권고 / agentic-browsing 권고 |

### 자동 수정 허용 범위 (HARD RULE — 이것만 자동 수정)

**자동 OK:**
- 디자인 토큰 darken/lighten (color-contrast 해소) — `globals.css` / `tokens.css` / `tailwind.config`
- `<html lang="...">` / `<meta name="description">` / `<meta name="viewport">` 추가
- `<img alt="">` 누락 보완 (의미 있는 텍스트가 도출 가능한 경우만)
- `<a>` / `<button>` 의 accessible-name 추가 (aria-label)
- `prefers-reduced-motion` 미디어 쿼리 추가

**자동 금지 (Agent 위임 또는 사용자 확인):**
- 컴포넌트 구조 변경, prop 시그니처 변경
- 라우팅·번들·SSR 설정 변경
- 이미지 자체 교체·최적화 (LCP 자산 변경)
- 디자인 토큰 신규 정의 (DESIGN.md 변경)

### 수정 흐름

```
1. Serena find_symbol / find_referencing_symbols 로 수정 대상 심볼·토큰 확정
2. Edit/Write 로 단순 수정 적용 (자동 OK 범위만)
3. 자동 금지 항목은 design-dev / frontend-dev 에이전트에 위임 또는 사용자 확인
4. L1 게이트 자동 통과 확인 (Stop hook)
```

color-contrast 다건 해소 사례:
```
solarmoa: color-contrast 28건 → globals.css 토큰 2개 darken
  --color-text-muted: oklch(0.65 ...) → oklch(0.45 ...)
  --color-border-soft: oklch(0.85 ...) → oklch(0.72 ...)
한 사이클로 28건 동시 해소.
```

---

## Step 5: 재측정 루프

**목표:** 수정 후 Step 2~3을 다시 돌려 점수가 올랐는지 확인. **루프는 최대 3회**.

```
for cycle in 1..3:
  Step 2 (Lighthouse) 재실행
  Step 3 (Performance Trace) 재실행
  점수 비교 (Before → After)
  PASS 조건 충족 → 루프 종료
  CRITICAL/HIGH 잔존 + 자동 수정 가능 → Step 4 재진입
  CRITICAL/HIGH 잔존 + 자동 수정 불가 → 사용자 보고 + 중단
```

3회 루프 내에 PASS 미달 시 사용자에게 잔존 이슈 보고 + 후속 조치 제안 (에이전트 위임 / 자산 교체 / 코드 구조 변경).

---

## Step 6: 결과 리포트

산출물: `.dev/qa-frontend/<timestamp>/REPORT.md`

```markdown
# QA Frontend 리포트 — <timestamp>

## 검수 범위
- 대상 페이지: <N>개
- viewport: 375 / 768 / 1024 / 1440 (풀페이지 캡처 <N×4>장)
- 측정 루프: <K>회

## Before → After

| 지표 | Before | After | 목표 | 판정 |
|------|--------|-------|------|------|
| Accessibility | 87 | 100 | 100 | PASS |
| Best Practices | 92 | 100 | 100 | PASS |
| SEO | 91 | 100 | 100 | PASS |
| Agentic Browsing | 88 | 100 | 100 | PASS |
| LCP | 2.8s | 1.25s | < 2.5s | PASS |
| CLS | 0.18 | 0 | < 0.1 | PASS |
| TTFB | 320ms | 15ms | < 200ms | PASS |
| color-contrast 위반 | 28건 | 0건 | 0건 | PASS |
| 콘솔 error | 2건 | 0건 | 0건 | PASS |

## 자동 적용한 수정
- globals.css: --color-text-muted darken (color-contrast 28건 해소)
- index.html: <meta name="description"> 추가
- Logo.tsx: aria-label 추가

## 잔존 이슈 (있으면)
| # | 심각도 | 항목 | 파일:줄 | 자동수정 가능? | 제안 |

## 산출물
- 스크린샷: .dev/qa-frontend/<timestamp>/<page>-{375,768,1024,1440}.png (<N×4>장)
- Lighthouse JSON: lighthouse-<page>.json
- Performance trace: perf-<page>.json
- 최종 판정: PASS / WARN / FAIL
```

사용자에게 캡처 경로를 명시해서 **눈으로 4 viewport 풀페이지를 확인**할 수 있게 한다.

---

## 판정 기준

- **PASS**: 위 모든 PASS 조건 충족 + 콘솔 error 0건 + 4 viewport 캡처 모두 확보
- **WARN**: HIGH 이하 잔존 (점수 95~99, LCP 2.5~4s 등) — 커밋 가능, 후속 개선 권장
- **FAIL**: CRITICAL 1건 이상 (Lighthouse < 90, LCP ≥ 4s, CLS ≥ 0.25, 모바일 가로 스크롤, 콘솔 error)

---

## 위험 신호 (즉시 중단)

| 위험 신호 | 현실 |
|---------|------|
| "캡처는 1280에서만 했어요" | 모바일 회귀의 90%는 375에서 발생한다 |
| "Lighthouse는 desktop으로 돌렸어요" | 모바일과 desktop 점수는 별개 — 반드시 mobile |
| "코드 보니까 괜찮을 것 같아요" | 측정값 없으면 통과 아님 (verify 스킬 정신) |
| "한 페이지만 측정" | 핵심 전환 페이지 최소 1개는 필수 |
| "스크린샷은 viewport-only" | `fullPage: true` 필수 — 스크롤 영역에서 결함 발생 |
| "프로덕션 빌드 없이 측정" | dev 서버 측정은 참고용, 가능하면 preview build 측정 |
| "MCP 안 떠 있어서 패스" | MCP 없으면 스킬 자체가 실행 불가 — 중단·보고 |

---

## 협업 / 호출 관계

- **design-reviewer** → 디자인 정성 리뷰 PASS/WARN 후 본 스킬을 **자동 호출**해 실측 검증
- **polish 스킬** → Step 6(검증) 단계에서 본 스킬을 자동 호출
- **design 스킬** → 신규 페이지 구현 완료 시 본 스킬로 실측 검증 후 commit
- **verify 스킬** → 본 스킬의 산출물(REPORT.md)을 "실행·통과 증거"로 인용
- **devrule 스킬** → 프론트엔드 affected_packages 변경 시 본 스킬 권장
- **frontend-dev / design-dev 에이전트** → 본 스킬 FAIL 시 수정 위임 대상

## ⚡ 즉시 실행

1. Step 0 환경 점검 → 사용자에게 BASE_URL · 대상 페이지 확정 요청
2. Step 1~3 측정 (Playwright + Chrome DevTools MCP)
3. Step 4 단순 수정 (토큰/메타/aria 한정 자동)
4. Step 5 재측정 루프 (최대 3회)
5. Step 6 리포트 + 캡처 경로 안내 (사람 눈 검수 유도)
