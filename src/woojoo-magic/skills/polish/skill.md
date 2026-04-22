---
name: polish
description: >
  (wj-magic) 기존 UI 디자인 개선 스킬. 이미 만들어진 UI의 시각적 품질을 진단하고 개선한다.
  트리거: "디자인 개선해줘", "UI 폴리시", "더 예쁘게", "세련되게", "polish",
  "AI스러워", "제네릭해", "디자인이 별로야", "다듬어줘"
---

**품질 기준**: `../../references/design/DESIGN_QUALITY_STANDARDS.md` 참조 (반드시 Read로 로드)

# Polish — 디자인 개선 스킬

## 목적

이미 만들어진 UI를 **"진단 → 처방 → 검증"** 사이클로 체계적으로 개선한다.
한 번의 호출로 종합적인 디자인 개선을 수행한다.

## Step 1: 디자인 레퍼런스 로드

반드시 Read 도구로 로드:
1. `references/design/DESIGN_QUALITY_STANDARDS.md` (필수)
2. `references/design/ANTI_SLOP_PATTERNS.md` (필수)
3. 프로젝트 루트 `DESIGN.md` (있으면)

## Step 2: 대상 식별

사용자가 특정 파일/컴포넌트를 지정했으면 그것만, 아니면:
- Glob으로 UI 파일 스캔 (`*.tsx`, `*.jsx`, `*.vue`, `*.svelte`)
- 최근 변경된 UI 파일 우선

## Step 3: 진단 (design-reviewer 투입)

design-reviewer 에이전트에게 현재 상태 진단 요청:
- Anti-Slop 패턴 탐지
- 시각적 위계 분석
- 타이포/컬러/스페이싱 일관성
- 접근성 체크

진단 결과를 우선순위별로 정리:
```
진단 결과:
1. [CRITICAL] 색상 대비 미충족: header.tsx:12 (대비 2.3:1)
2. [HIGH] AI Purple 패턴: 3곳에서 indigo-500 그라디언트
3. [HIGH] 시각적 위계 부재: 모든 텍스트 같은 크기
4. [MEDIUM] 모션 없음: 버튼 hover 상태만 있음
```

## Step 4: 처방 (design-dev 투입)

진단 결과의 CRITICAL → HIGH → MEDIUM 순서로 design-dev 에이전트에게 수정 위임:

에이전트 프롬프트에 포함:
- 진단 결과 전문
- 수정 우선순위 (CRITICAL 먼저)
- 관련 디자인 레퍼런스 경로
- 프로젝트 DESIGN.md 토큰

## Step 5: 검증 (design-reviewer 재투입)

수정 완료 후 design-reviewer로 재검증:
- 진단 이슈가 해결되었는지 확인
- 새로운 이슈가 생기지 않았는지 확인

## Step 6: 결과 리포트

```
디자인 폴리시 완료:

Before → After:
- 색상 대비: 2.3:1 → 5.1:1 (WCAG AA 충족)
- AI Slop: indigo-500 → 브랜드 프라이머리 컬러
- 시각적 위계: 3단계 타이포 스케일 적용
- 모션: 버튼/카드/모달 전환 애니메이션 추가

수정 파일: {N}개
```

## ⚡ 즉시 실행
