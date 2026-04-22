---
name: design
description: 새 UI 디자인 — 비주얼 방향 설정부터 컴포넌트 구현까지 디자인 전 과정 진행 (신규 제작)
---

**품질 기준**: `../../references/design/DESIGN_QUALITY_STANDARDS.md` 참조 (반드시 Read로 로드)

# Design — 디자인 기획 + 구현 스킬

## 목적

"그냥 만들어줘"가 아닌 **"방향 설정 → 구현 → 리뷰"** 3단계를 강제하여,
AI 제네릭(Slop)이 아닌 의도 있는 디자인을 만든다.

## Step 1: 디자인 레퍼런스 로드

반드시 Read 도구로 로드:
1. `references/design/DESIGN_QUALITY_STANDARDS.md` (필수)
2. `references/design/ANTI_SLOP_PATTERNS.md` (필수)
3. 프로젝트 루트 `DESIGN.md` (있으면)

## Step 2: DESIGN.md 확인

프로젝트 루트에 `DESIGN.md` 존재 여부 확인.
- **있으면**: 토큰(컬러, 타이포, 스페이싱) 로드
- **없으면**: 프로젝트 도메인을 분석하여 DESIGN.md 초안 생성 제안

## Step 3: 디자인 방향 설정

사용자에게 2~3개 미학적 방향을 제안하고 선택 받는다:

```
이 프로젝트에 어울리는 디자인 방향 3가지를 제안합니다:

1. [방향 이름] — [설명] (예: "editorial-minimalist — 여백 중심, 타이포 강조, 뉴트럴 톤")
2. [방향 이름] — [설명]
3. [방향 이름] — [설명]

어떤 방향이 좋으세요? (또는 다른 방향을 알려주세요)
```

방향 제안 시 참고:
- 프로젝트 도메인 (금융, 헬스, 이커머스, 생산성 등)
- 타겟 사용자 (B2B, B2C, 개발자, 일반 사용자)
- ANTI_SLOP_PATTERNS.md의 안티패턴을 피하는 방향

## Step 4: 규모 판정 + 에이전트 위임

| 규모 | 실행 전략 |
|------|----------|
| S (컴포넌트 1~3개) | Claude 직접 구현 (디자인 레퍼런스 기준) |
| M (페이지 1개 또는 컴포넌트 4~10개) | design-dev 에이전트 위임 |
| L (복수 페이지 또는 디자인 시스템 전체) | design-dev + frontend-dev 병렬 위임 |

에이전트 프롬프트에 반드시 포함:
- 선택된 디자인 방향
- DESIGN.md 토큰 (있으면)
- 대상 파일/컴포넌트 범위
- Anti-Slop 체크리스트

## Step 5: 디자인 리뷰

구현 완료 후 design-reviewer 에이전트 투입:
- PASS → 커밋
- WARN → 사용자에게 개선 포인트 보고, 커밋은 가능
- FAIL → design-dev에 수정 재위임 (최대 2회)

## ⚡ 즉시 실행
