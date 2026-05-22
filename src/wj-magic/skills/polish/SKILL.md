---
name: polish
description: >
  이미 만들어진 UI의 시각적 완성도를 진단·처방·재구현으로 개선하는 스킬.
  기존 화면이 마음에 안 들거나 더 다듬고 싶을 때 반드시 이 스킬을 사용하라.
  "디자인 개선해줘", "더 예쁘게", "다듬어줘", "polish", "AI스러워", "제네릭해",
  "디자인이 별로야", "세련되게 바꿔줘", "UI 폴리시" 요청에 트리거.
  새로 만드는 경우는 design 스킬을 사용하라.
---

**품질 기준**: `../../references/design/DESIGN_QUALITY_STANDARDS.md` + `DESIGN_TOKEN_WORKFLOW.md` 참조 (반드시 Read로 로드)

# Polish — 디자인 개선 스킬

## 목적

이미 만들어진 UI를 **"진단 → 처방 → 검증"** 사이클로 체계적으로 개선한다.
한 번의 호출로 종합적인 디자인 개선을 수행한다.

## Step 1: 디자인 레퍼런스 로드

반드시 Read 도구로 로드:
1. `references/design/DESIGN_QUALITY_STANDARDS.md` (필수)
2. `references/design/DESIGN_TOKEN_WORKFLOW.md` (**필수 — 토큰 측정 강제**)
3. `references/design/ANTI_SLOP_PATTERNS.md` (필수)
4. 프로젝트 루트 `DESIGN.md` (있으면)

## Step 2: 대상 식별

사용자가 특정 파일/컴포넌트를 지정했으면 그것만, 아니면:
- Glob으로 UI 파일 스캔 (`*.tsx`, `*.jsx`, `*.vue`, `*.svelte`)
- 최근 변경된 UI 파일 우선

## Step 3: 진단

`Agent(subagent_type: "wj-magic:design-reviewer")` 투입 — 현재 상태 진단 요청:
- **토큰 사용률 측정 (grep 정량값, 필수)** — 정의 vs 실제 사용
- **hex 하드코딩·arbitrary value 카운트 (필수)**
- Anti-Slop 패턴 탐지
- 시각적 위계 분석
- 타이포/컬러/스페이싱 일관성
- 접근성 체크 (키보드, focus-visible, aria, WCAG AA)

진단 결과를 우선순위별로 정리 (토큰 측정값 명시):
```
진단 결과:

토큰 사용률: 0% (토큰 0건 / hex 67건 / arbitrary 40건)
DESIGN.md 존재: ✓
정의된 토큰 사용률: 0% — 정의는 했으나 사용 0% (전형적 함정)

1. [CRITICAL] 토큰 사용률 < 80%: 67건 hex 하드코딩
2. [CRITICAL] 색상 대비 미충족: header.tsx:12 (대비 2.3:1)
3. [HIGH] AI Purple 패턴: 3곳에서 indigo-500 그라디언트
4. [HIGH] 시각적 위계 부재: 모든 텍스트 같은 크기
5. [MEDIUM] 모션 없음: 버튼 hover 상태만 있음
```

## Step 4: 처방

진단 결과의 CRITICAL → HIGH → MEDIUM 순서로 `Agent(subagent_type: "wj-magic:design-dev")` 수정 위임:

에이전트 프롬프트에 포함:
- 진단 결과 전문
- 수정 우선순위 (CRITICAL 먼저)
- 관련 디자인 레퍼런스 경로
- 프로젝트 DESIGN.md 토큰

## Step 5: 검증 (정성 + 실측 2단)

### 5-1. 정성 리뷰
수정 완료 후 `Agent(subagent_type: "wj-magic:design-reviewer")` 재투입:
- 진단 이슈가 해결되었는지 확인
- 새로운 이슈가 생기지 않았는지 확인

### 5-2. 실측 QA (필수 — design-reviewer PASS/WARN 직후)
정성 리뷰만으로는 모바일 회귀·Lighthouse 점수·LCP/CLS 회귀가 잡히지 않는다.
dev/preview 서버가 떠 있으면 **반드시** `Skill({ skill: "wj-magic:qa-frontend" })` 호출:
- Playwright 4 viewport(375/768/1024/1440) 풀페이지 캡처
- Chrome DevTools MCP mobile Lighthouse 4종 + LCP/CLS/TTFB
- color-contrast 잔존이 있으면 토큰 darken 자동 재수정 루프
- 서버 미기동 시 사용자에게 요청 후 호출 (추측 진행 금지)
- design-reviewer FAIL 상태에서는 호출하지 않는다 (디자인 수정 우선)

## Step 6: 결과 리포트

```
디자인 폴리시 완료:

Before → After:
- 토큰 사용률: 0% → 98% (hex 67건 → 0건)
- 색상 대비: 2.3:1 → 5.1:1 (WCAG AA 충족)
- AI Slop: indigo-500 → 브랜드 프라이머리 컬러
- 시각적 위계: 3단계 타이포 스케일 적용
- 모션: 버튼/카드/모달 전환 애니메이션 추가
- 접근성: SVG 인터랙티브 role/tabIndex/onKeyDown 추가, focus-visible:ring 7개 버튼
- 모션 접근성: prefers-reduced-motion + MotionConfig reducedMotion="user"

수정 파일: {N}개
정성 검수: design-reviewer 재투입 PASS (토큰 사용률 ≥ 95%)
실측 검수: qa-frontend PASS (Mobile Lighthouse 4종 100·LCP <2.5s·CLS <0.1·color-contrast 0건)
```

## ⚡ 즉시 실행
